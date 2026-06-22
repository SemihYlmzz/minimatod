import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Requests browser notification permission. Returns true if granted. Must be
/// called from a user gesture or the browser may auto-reject.
Future<bool> requestWebNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    // Notification API unsupported (old browser / insecure context).
    return false;
  }
}

/// Current permission string: 'granted' | 'denied' | 'default'. Returns
/// 'unsupported' when the API is unavailable.
String webNotificationPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// Subscribes to live notification-permission changes via the Permissions API,
/// calling [onChange] whenever the user flips it (no app resume needed). No-op
/// if the API is unavailable.
void listenWebPermissionChanges(void Function() onChange) {
  try {
    final desc = {'name': 'notifications'}.jsify() as JSObject;
    web.window.navigator.permissions.query(desc).toDart.then((status) {
      status.onchange = ((web.Event _) => onChange()).toJS;
    });
  } catch (_) {
    // Permissions API not supported — resume-recheck still covers it.
  }
}

/// Shows a foreground notification. Prefers the service worker registration
/// (the only path that works on mobile Chrome, where the `Notification`
/// constructor is illegal); falls back to the constructor on desktop browsers
/// without an active worker. No-op if permission isn't granted.
Future<void> showWebNotification(String title, String? body) async {
  if (webNotificationPermission() != 'granted') return;
  final options = web.NotificationOptions(
    body: body ?? '',
    icon: 'icons/Icon-192.png',
    // Persist as an alert (stays until dismissed) instead of a transient toast.
    requireInteraction: true,
  );

  try {
    final registration = await web.window.navigator.serviceWorker.ready.toDart
        .timeout(const Duration(seconds: 3));
    await registration.showNotification(title, options).toDart;
    return;
  } catch (_) {
    // No service worker available/ready — try the direct constructor.
  }

  try {
    web.Notification(title, options);
  } catch (_) {
    // Constructor not allowed (e.g. mobile) and no worker — give up quietly.
  }
}
