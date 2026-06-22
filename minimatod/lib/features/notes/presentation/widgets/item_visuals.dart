import 'package:flutter/material.dart';

/// Visual catalog for per-item customisation: the selectable icon set and the
/// accent colour palette shown in the create sheet, plus lookups to render a
/// stored choice. Keys/values are stable so they survive future sync.

/// One pickable icon: a stable [key] (persisted on the item) and its glyph.
class ItemIconOption {
  const ItemIconOption(this.key, this.icon);
  final String key;
  final IconData icon;
}

/// The ordered icon grid. The first entry is the default note glyph.
const List<ItemIconOption> kItemIcons = [
  ItemIconOption('note', Icons.sticky_note_2_outlined),
  ItemIconOption('check', Icons.check_rounded),
  ItemIconOption('star', Icons.star_outline_rounded),
  ItemIconOption('bulb', Icons.lightbulb_outline_rounded),
  ItemIconOption('work', Icons.work_outline_rounded),
  ItemIconOption('home', Icons.home_outlined),
  ItemIconOption('heart', Icons.favorite_outline_rounded),
  ItemIconOption('flag', Icons.flag_outlined),
  ItemIconOption('book', Icons.menu_book_outlined),
  ItemIconOption('calendar', Icons.calendar_today_outlined),
  ItemIconOption('music', Icons.music_note_outlined),
  ItemIconOption('trash', Icons.delete_outline_rounded),
];

/// Resolves a stored icon [key] to its glyph, or null when unset/unknown.
IconData? itemIconData(String? key) {
  if (key == null) return null;
  for (final option in kItemIcons) {
    if (option.key == key) return option.icon;
  }
  return null;
}

/// The accent colour palette, matching the mockup (purple → grey).
const List<Color> kItemColors = [
  Color(0xFFB39DDB), // purple
  Color(0xFF64B5F6), // blue
  Color(0xFF4DB6AC), // teal
  Color(0xFF81C784), // green
  Color(0xFFE5C04B), // amber
  Color(0xFFFF8A65), // orange
  Color(0xFFE57697), // pink
  Color(0xFFB0BEC5), // grey
];
