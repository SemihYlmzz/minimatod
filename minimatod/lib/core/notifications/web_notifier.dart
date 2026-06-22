/// Browser Notification API shim, chosen at compile time:
/// - web → `web_notifier_web.dart` (real `package:web` calls)
/// - everything else → `web_notifier_stub.dart` (no-ops)
///
/// On web we deliberately bypass `flutter_local_notifications` (its web support
/// registers its own service worker, which clashes with Flutter's PWA worker).
/// Our web reminders only need to fire while a tab is open, so a foreground
/// `Notification` is simpler and more reliable.
library;

export 'web_notifier_stub.dart' if (dart.library.html) 'web_notifier_web.dart';
