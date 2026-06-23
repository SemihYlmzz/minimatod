import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:minimatod/core/format/reminder_at.dart';

/// Guards the fix for reminders rendering with the "created at" formatter, which
/// dropped the time for any non-today date — so a reminder for tomorrow 9am read
/// as just "25 Jun", hiding *when* it fires.
void main() {
  const en = Locale('en');

  // Production initializes this in main(); the test isolate must do it too.
  setUpAll(initializeDateFormatting);

  test('today shows the time only (no date words)', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 18, 30);
    expect(formatReminderAt(today, en), matches(RegExp(r'^\d{1,2}:\d{2}$')));
  });

  test('a future day keeps BOTH the date and the time', () {
    final now = DateTime.now();
    final future = DateTime(now.year, now.month, now.day + 1, 9, 5);
    final label = formatReminderAt(future, en);
    expect(
      label,
      contains(':'),
    ); // the time — the part the old formatter dropped
    expect(label, matches(RegExp('[A-Za-z]'))); // the date (month name)
  });
}
