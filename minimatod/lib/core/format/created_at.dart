import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Compact, locale-aware "created at" label — minimalist (no words to
/// translate): today shows the time, this year a short date, otherwise a full
/// short date. Month names localise via [locale] (init in main).
String formatCreatedAt(DateTime date, Locale locale) {
  final l = locale.toString();
  final now = DateTime.now();
  final sameDay =
      date.year == now.year && date.month == now.month && date.day == now.day;
  if (sameDay) return DateFormat.Hm(l).format(date);
  if (date.year == now.year) return DateFormat.MMMd(l).format(date);
  return DateFormat.yMMMd(l).format(date);
}
