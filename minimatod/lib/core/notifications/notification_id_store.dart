import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Maps each item's UUID to a stable, unique 32-bit notification id.
///
/// The platform notification plugins key everything on an `int`, so we need a
/// collision-free string→int mapping. The previous `itemId.hashCode` approach
/// collides as the item count grows (two items → one id → one reminder silently
/// overwrites the other). Here ids are handed out sequentially and **persisted**
/// (via [SharedPreferences]), so an item keeps the same id across launches —
/// essential for cancelling/replacing a reminder scheduled in an earlier
/// session.
///
/// Ids start at 1 and grow monotonically, comfortably inside the plugins' signed
/// 32-bit range for any realistic number of reminders. Mappings are never
/// reclaimed (keeping it simple and reuse-safe); pruning is a future
/// optimization if the map ever grows large.
class NotificationIdStore {
  NotificationIdStore(this._prefs);

  final SharedPreferences? _prefs;

  static const _kMap = 'notif.id_map';
  static const _kNext = 'notif.next_id';

  Map<String, int>? _map;
  int _next = 1;

  /// The stable id for [itemId], assigning (and persisting) a new one on first
  /// use. Without persistence ([SharedPreferences] unavailable) it still hands
  /// out collision-free ids, just only stable within the running session.
  Future<int> idFor(String itemId) async {
    final map = _ensureLoaded();
    final existing = map[itemId];
    if (existing != null) return existing;

    final id = _next++;
    map[itemId] = id;
    await _persist();
    return id;
  }

  Map<String, int> _ensureLoaded() {
    final cached = _map;
    if (cached != null) return cached;

    final map = <String, int>{};
    final prefs = _prefs;
    if (prefs != null) {
      final raw = prefs.getString(_kMap);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) => map[key] = value as int);
      }
      var maxExisting = 0;
      for (final v in map.values) {
        if (v > maxExisting) maxExisting = v;
      }
      // Resume the counter past the highest id ever handed out so we never
      // reissue one (which would alias two items to the same notification).
      final stored = prefs.getInt(_kNext);
      _next = (stored != null && stored > maxExisting)
          ? stored
          : maxExisting + 1;
    }

    _map = map;
    return map;
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kMap, jsonEncode(_map));
    await prefs.setInt(_kNext, _next);
  }
}
