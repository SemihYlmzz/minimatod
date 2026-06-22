// Non-web stub. Native platforms use `flutter_local_notifications` instead, so
// these are never called there.

Future<bool> requestWebNotificationPermission() async => false;

String webNotificationPermission() => 'unsupported';

void listenWebPermissionChanges(void Function() onChange) {}

Future<void> showWebNotification(String title, String? body) async {}
