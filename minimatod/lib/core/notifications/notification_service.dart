import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_id_store.dart';
import 'web_notifier.dart';

/// Schedules and cancels per-item reminder notifications across every platform.
///
/// Native (Android / iOS / macOS / Linux / Windows): **exact** OS-scheduled
/// alarms via `zonedSchedule`, so a reminder fires at the right minute even when
/// the app is closed. Web has no OS scheduler, so there a reminder fires only
/// while a tab is open (a [Timer] + the browser Notification API), re-armed on
/// each launch.
///
/// The native side needs matching platform config to actually deliver:
/// - Android: `USE_EXACT_ALARM` + the `ScheduledNotification(Boot)Receiver`s in
///   `AndroidManifest.xml`, and core-library desugaring in `build.gradle.kts`.
/// - iOS: the `UNUserNotificationCenter` delegate + plugin registrant callback
///   in `AppDelegate.swift`.
/// All of that is wired up; see those files if delivery ever breaks.
class NotificationService {
  /// [prefs] persists the item→notification-id mapping (see
  /// [NotificationIdStore]); pass the app's instance so ids survive restarts.
  NotificationService({SharedPreferences? prefs})
    : _idStore = NotificationIdStore(prefs);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final NotificationIdStore _idStore;

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription = 'Note and task reminders';

  bool _ready = false;

  /// Cached "permission granted" for the schedule fast-path so re-arming many
  /// reminders on launch doesn't re-request each time. [currentStatus] always
  /// re-queries the platform, so the badges stay accurate.
  bool? _permissionGranted;

  /// Web-only fire timers, keyed by notification id (no OS scheduler on web).
  final Map<int, Timer> _webTimers = {};

  /// Initializes the plugin, the local timezone, and (Android) the high-priority
  /// reminder channel. Safe to call repeatedly; only the first call does work.
  /// Never throws.
  Future<void> init() async {
    if (_ready) return;

    // Web uses the browser Notification API directly (see [web_notifier.dart]),
    // not the plugin — nothing to initialize here.
    if (kIsWeb) {
      _ready = true;
      return;
    }

    await _initTimeZone();

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission is requested lazily (when a reminder is first set), not on
      // launch — see [_ensurePermission].
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
        appName: 'Minimatod',
        appUserModelId: 'com.minimatod.app',
        guid: '2b1d7c84-3f6a-4e2b-9d5c-8a7e1f0c4b93',
      ),
    );

    try {
      await _plugin.initialize(settings: settings);
      await _createAndroidChannel();
      _ready = true;
    } catch (e) {
      debugPrint('Minimatod: notifications init failed: $e');
    }
  }

  /// Loads the timezone database and points `tz.local` at the device zone, so
  /// `TZDateTime.from(localWallClock, tz.local)` resolves to the correct instant.
  /// On failure it stays UTC — which would fire reminders at the wrong wall-clock
  /// time, so the fallback is logged loudly.
  Future<void> _initTimeZone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Minimatod: local timezone lookup failed ($e); using UTC');
    }
  }

  /// Android 8+ shows reminders as heads-up only on a high-importance channel.
  /// Created up front so the importance is set before the first notification.
  Future<void> _createAndroidChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// (Re)schedules a reminder for [itemId]. Replaces any existing one. No-op if
  /// [when] is in the past or notification permission is denied.
  Future<void> schedule({
    required String itemId,
    required String title,
    String? body,
    required DateTime when,
  }) async {
    await init();
    await cancel(itemId);
    if (!when.isAfter(DateTime.now())) return;
    if (!await _ensurePermission()) return;

    final int id = await _idStore.idFor(itemId);
    final String safeTitle = title.trim().isEmpty ? 'Reminder' : title.trim();

    if (kIsWeb) {
      _scheduleWeb(id, safeTitle, body, when);
      return;
    }

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      // Present in the foreground too, so a reminder isn't silently swallowed
      // while the app is open.
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(),
    );

    final tz.TZDateTime tzWhen = tz.TZDateTime.from(when, tz.local);
    final AndroidScheduleMode mode = await _androidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: safeTitle,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: details,
        androidScheduleMode: mode,
      );
    } on PlatformException catch (e) {
      // Some devices/policies refuse exact alarms even with the permission
      // declared. Fall back to an inexact alarm so the reminder still fires
      // (just not always to the exact minute) rather than failing outright.
      if (e.code == 'exact_alarms_not_permitted') {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: safeTitle,
            body: body,
            scheduledDate: tzWhen,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (e2) {
          debugPrint('Minimatod: inexact schedule failed: $e2');
        }
      } else {
        debugPrint('Minimatod: schedule failed: $e');
      }
    } catch (e) {
      debugPrint('Minimatod: schedule failed: $e');
    }
  }

  /// Exact delivery where the OS allows it (fires at the set minute), inexact
  /// otherwise (still fires, within an OS-chosen window). Needs
  /// `USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM` in the manifest for exact; this
  /// keeps working even when those aren't granted.
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final bool canExact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Cancels the reminder for [itemId] (and its web timer), if any.
  Future<void> cancel(String itemId) async {
    final int id = await _idStore.idFor(itemId);
    _webTimers.remove(id)?.cancel();
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Minimatod: cancel failed: $e');
    }
  }

  /// Current permission, queried live (no caching), as one of `granted`,
  /// `default` (not asked yet / re-askable), or `unsupported`.
  Future<String> currentStatus() async {
    if (kIsWeb) return webNotificationPermission();
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final enabled = await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled();
          return (enabled ?? false) ? 'granted' : 'default';
        case TargetPlatform.iOS:
          final opts = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
          return (opts?.isEnabled ?? false) ? 'granted' : 'default';
        default:
          return 'granted'; // macOS / Linux / Windows: assume usable.
      }
    } catch (_) {
      return 'default';
    }
  }

  /// Prompts for permission (from a user gesture) and returns whether granted.
  Future<bool> requestPermission() async {
    await init();
    _permissionGranted = null; // force a fresh request
    return _ensurePermission();
  }

  /// Calls [onChange] when notification permission changes live (web only, via
  /// the Permissions API). On native, resume-rechecks cover this.
  void watchPermissionChanges(void Function() onChange) {
    listenWebPermissionChanges(onChange);
  }

  /// Web fallback: fire via a timer while the tab is open, using the browser
  /// Notification API. Far-future reminders (beyond the JS timer limit) are left
  /// for a later launch to re-arm.
  void _scheduleWeb(int id, String title, String? body, DateTime when) {
    final Duration delay = when.difference(DateTime.now());
    if (delay.isNegative || delay.inMilliseconds > 0x7fffffff) return;
    _webTimers[id] = Timer(delay, () {
      _webTimers.remove(id);
      showWebNotification(title, body);
    });
  }

  /// Requests permission once and caches the granted result for the schedule
  /// fast-path. Idempotent: when already granted the OS returns immediately
  /// without re-prompting.
  Future<bool> _ensurePermission() async {
    if (_permissionGranted == true) return true;
    bool? granted;
    try {
      if (kIsWeb) {
        granted = await requestWebNotificationPermission();
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            granted = await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();
          case TargetPlatform.iOS:
            granted = await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true);
          case TargetPlatform.macOS:
            granted = await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true);
          default:
            granted = true; // Linux / Windows: no runtime prompt.
        }
      }
    } catch (e) {
      debugPrint('Minimatod: notification permission failed: $e');
    }
    _permissionGranted = granted ?? false;
    return _permissionGranted!;
  }
}
