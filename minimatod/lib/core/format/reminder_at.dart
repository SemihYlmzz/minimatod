import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Compact, locale-aware reminder label that **always** shows the time — a
/// reminder without a visible time is ambiguous ("9am or 9pm tomorrow?").
///
/// Mirrors [formatCreatedAt]'s minimalist, no-words-to-translate approach, but
/// keeps the clock: today shows just the time; another day this year adds the
/// short date; another year adds the year too.
String formatReminderAt(DateTime date, Locale locale) {
  final l = locale.toString();
  final now = DateTime.now();
  final sameDay =
      date.year == now.year && date.month == now.month && date.day == now.day;
  if (sameDay) return DateFormat.Hm(l).format(date);
  if (date.year == now.year) return DateFormat.MMMd(l).add_Hm().format(date);
  return DateFormat.yMMMd(l).add_Hm().format(date);
}
