import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'reminder_controller.dart';

/// Delivery state of a reminder badge, derived from notification permission.
enum ReminderBadgeState {
  /// Notifications allowed (or unknown) — the reminder will fire.
  ok,

  /// Permission not granted yet but can still be requested — amber, tap allows.
  askable,

  /// Hard-blocked — red, tap shows how to re-enable.
  blocked,
}

ReminderBadgeState reminderBadgeState(ReminderController? reminders) {
  if (reminders == null) return ReminderBadgeState.ok;
  if (reminders.blocked) return ReminderBadgeState.blocked;
  if (reminders.askable) return ReminderBadgeState.askable;
  return ReminderBadgeState.ok;
}

/// Handles a tap on a row's reminder warning: askable → prompt for permission;
/// blocked → show platform-appropriate instructions to re-enable.
Future<void> handleReminderWarningTap(
  BuildContext context,
  ReminderController? reminders,
) async {
  if (reminders != null && reminders.askable) {
    await reminders.requestPermission();
    return;
  }
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.enableReminders),
      content: Text(
        kIsWeb ? l.enableInstructionsWeb : l.enableInstructionsNative,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.done),
        ),
      ],
    ),
  );
}
