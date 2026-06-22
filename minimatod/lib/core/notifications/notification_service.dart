import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'web_notifier.dart';

/// Schedules and cancels per-item reminder notifications across every platform.
///
/// Native platforms (Android / iOS / macOS / Linux / Windows) use the OS
/// scheduler via `zonedSchedule`, so reminders fire even when the app is closed.
/// The web has no OS-level scheduler, so there a reminder fires only while a tab
/// is open (a [Timer] + the browser Notification API) and is re-armed on each
/// launch via [NotesController.rescheduleAll].
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription = 'Note and task reminders';

  bool _ready = false;
  bool? _permissionGranted;

  /// Web-only fire timers, keyed by notification id (no OS scheduler on web).
  final Map<int, Timer> _webTimers = {};

  /// Initializes the plugin and the local timezone database. Safe to call more
  /// than once; only the first call does work. Never throws.
  Future<void> init() async {
    if (_ready) return;

    // Web uses the browser Notification API directly (see [web_notifier.dart]),
    // not the plugin — so there's nothing to initialize here.
    if (kIsWeb) {
      _ready = true;
      return;
    }

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep the default location (UTC) if the lookup fails.
    }

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      // We request permission lazily (when the first reminder is set), not on
      // launch — see [_ensurePermission].
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const LinuxInitializationSettings linux = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const WindowsInitializationSettings windows = WindowsInitializationSettings(
      appName: 'Minimatod',
      appUserModelId: 'com.minimatod.app',
      guid: '2b1d7c84-3f6a-4e2b-9d5c-8a7e1f0c4b93',
    );

    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );

    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (e) {
      debugPrint('Minimatod: notifications init failed: $e');
    }
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
    if (when.isBefore(DateTime.now())) return;
    if (!await _ensurePermission()) return;

    final int id = _idFor(itemId);
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
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: safeTitle,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Minimatod: schedule failed: $e');
    }
  }

  /// Current permission without prompting: one of `granted`, `denied`,
  /// `default` (not asked yet), or `unsupported`.
  Future<String> currentStatus() async {
    if (_permissionGranted == true) return 'granted';
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
          return 'granted'; // macOS/Linux/Windows: assume usable.
      }
    } catch (_) {
      return 'default';
    }
  }

  /// Prompts for permission (from a user gesture) and returns whether granted.
  Future<bool> requestPermission() async {
    await init();
    return _ensurePermission();
  }

  /// Calls [onChange] when notification permission changes live (web only, via
  /// the Permissions API). On native, resume-rechecks cover this.
  void watchPermissionChanges(void Function() onChange) {
    listenWebPermissionChanges(onChange);
  }

  /// Cancels the reminder for [itemId] (and its web timer), if any.
  Future<void> cancel(String itemId) async {
    final int id = _idFor(itemId);
    _webTimers.remove(id)?.cancel();
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Minimatod: cancel failed: $e');
    }
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

  /// Requests permission once and caches the result. Idempotent: when already
  /// granted the OS returns immediately without re-prompting.
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

  /// Stable positive 31-bit id derived from the item's UUID.
  int _idFor(String itemId) => itemId.hashCode & 0x7fffffff;
}
