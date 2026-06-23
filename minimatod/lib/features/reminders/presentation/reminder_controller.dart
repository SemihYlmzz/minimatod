import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';

/// Owns reminder scheduling and the OS notification-permission state.
///
/// A standalone concern — it knows nothing about notes or tasks; callers pass
/// plain `(id, title, time)`, so it can serve any feature. It's also the
/// template for the app's per-feature controllers: each new concern (canvas,
/// audio, sync, auth) gets its own small [ChangeNotifier] like this one, rather
/// than piling into one god-object.
///
/// A null [notifications] (tests, or notifications disabled) makes every method
/// a safe no-op and leaves the badges inert.
class ReminderController extends ChangeNotifier {
  ReminderController({this.notifications}) {
    // Update the badge live when permission changes outside the app (web).
    notifications?.watchPermissionChanges(refresh);
  }

  final NotificationService? notifications;

  /// Last-known permission: granted / denied / default / unsupported / unknown.
  String _permission = 'unknown';

  /// Reminder set but hard-blocked — won't fire and can't be re-prompted (the
  /// user must change OS/browser settings). Drives the red badge.
  bool get blocked =>
      notifications != null &&
      (_permission == 'denied' || _permission == 'unsupported');

  /// Permission not granted yet but still requestable. Drives the amber badge.
  bool get askable => notifications != null && _permission == 'default';

  /// Refreshes the cached permission from the platform; notifies on change.
  Future<void> refresh() async {
    final n = notifications;
    if (n == null) return;
    final status = await n.currentStatus();
    if (status != _permission) {
      _permission = status;
      notifyListeners();
    }
  }

  /// Prompts for notification permission (from a user gesture), then refreshes.
  Future<void> requestPermission() async {
    final n = notifications;
    if (n == null) return;
    await n.requestPermission();
    await refresh();
  }

  /// Schedules (or replaces) a reminder for [id] at [when], then refreshes the
  /// permission badge. The caller decides *whether* a reminder applies; this
  /// just arms it.
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime when,
  }) async {
    final n = notifications;
    if (n == null) return;
    await n.schedule(itemId: id, title: title, when: when);
    await refresh();
  }

  /// Cancels [id]'s reminder (e.g. when its owner is completed, archived, or
  /// deleted, or its time is cleared).
  void cancel(String id) => notifications?.cancel(id);
}
