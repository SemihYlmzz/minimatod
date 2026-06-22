import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/note_model.dart';
import '../data/notes_repository.dart';

/// Holds the note/task tree in memory and mediates all changes through the
/// [NotesRepository]. UI listens via [ChangeNotifier].
class NotesController extends ChangeNotifier {
  NotesController(this._repository, {Uuid? uuid, this.notifications})
    : _uuid = uuid ?? const Uuid() {
    // Update reminder badges live when permission changes (web).
    notifications?.watchPermissionChanges(refreshReminderPermission);
  }

  final NotesRepository _repository;
  final Uuid _uuid;

  /// Optional reminder scheduler. Null in tests / when notifications are off.
  final NotificationService? notifications;

  List<Item> _items = const [];
  bool _isLoading = false;

  /// Last-known notification permission: granted / denied / default /
  /// unsupported / unknown. Drives the "reminder won't fire" warnings.
  String _reminderPermission = 'unknown';

  /// Reminder set but hard-blocked — won't fire and can't be re-prompted (user
  /// must change OS/browser settings). Shows the red badge.
  bool get remindersBlocked =>
      notifications != null &&
      (_reminderPermission == 'denied' || _reminderPermission == 'unsupported');

  /// Reminder set but permission was never granted yet and can still be asked.
  /// Shows the amber "tap to allow" badge.
  bool get remindersAskable =>
      notifications != null && _reminderPermission == 'default';

  /// Refreshes the cached permission from the platform. Notifies on change.
  Future<void> refreshReminderPermission() async {
    final n = notifications;
    if (n == null) return;
    final status = await n.currentStatus();
    if (status != _reminderPermission) {
      _reminderPermission = status;
      notifyListeners();
    }
  }

  /// Prompts for notification permission (from a user gesture) and refreshes.
  Future<void> requestReminderPermission() async {
    final n = notifications;
    if (n == null) return;
    await n.requestPermission();
    await refreshReminderPermission();
  }

  /// Flat list of every item, unordered.
  List<Item> get items => List.unmodifiable(_items);

  /// Direct children of [parentId] (pass null for root level), ordered newest
  /// first by `sortOrder` then `createdAt`.
  List<Item> childrenOf(String? parentId) {
    return _items.where((i) => i.parentId == parentId).toList()..sort((a, b) {
      final byOrder = b.sortOrder.compareTo(a.sortOrder);
      return byOrder != 0 ? byOrder : b.createdAt.compareTo(a.createdAt);
    });
  }

  /// Completed / uncompleted counts of all descendant **tasks** of [parentId]
  /// (recursively, at any depth). Notes are never counted.
  ({int completed, int uncompleted}) descendantTaskCounts(String? parentId) {
    final byParent = <String?, List<Item>>{};
    for (final item in _items) {
      byParent.putIfAbsent(item.parentId, () => []).add(item);
    }

    var completed = 0;
    var uncompleted = 0;
    void visit(String? pid) {
      for (final child in byParent[pid] ?? const <Item>[]) {
        if (child.type == ItemType.task) {
          if (child.isDone) {
            completed++;
          } else {
            uncompleted++;
          }
        }
        visit(child.id);
      }
    }

    visit(parentId);
    return (completed: completed, uncompleted: uncompleted);
  }

  bool get isLoading => _isLoading;

  /// Loads all items from storage.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _items = await _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  /// Creates a new note/task, optionally nested under [parentId]. Optional
  /// [body], [icon], [color] and [reminderAt] capture the create-sheet extras.
  Future<void> addItem({
    required String content,
    required ItemType type,
    String? parentId,
    String? body,
    String? icon,
    int? color,
    DateTime? reminderAt,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final trimmedBody = body?.trim();
    final item = Item(
      id: _uuid.v4(),
      parentId: parentId,
      type: type,
      content: trimmed,
      body: (trimmedBody == null || trimmedBody.isEmpty) ? null : trimmedBody,
      icon: icon,
      color: color,
      reminderAt: reminderAt,
      sortOrder: _nextSortOrder(parentId),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.add(item);
    _syncReminder(item);
    await load();
    await refreshReminderPermission();
  }

  /// Flips the completion state of a task. Completing a task cancels its
  /// reminder; un-completing re-arms it (if still in the future).
  Future<void> toggleDone(Item item) async {
    final updated = item.copyWith(
      isDone: !item.isDone,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    if (updated.isDone) {
      notifications?.cancel(updated.id);
    } else {
      _syncReminder(updated);
    }
    await load();
  }

  /// Saves the long-form note [body] for the item with [id]. Looks up the live
  /// item so a stale snapshot can't clobber other fields. No-op if unchanged or
  /// the item is gone.
  Future<void> setBody(String id, String body) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final item = _items[index];
    if ((item.body ?? '') == body) return;
    await _repository.update(
      item.copyWith(body: body, updatedAt: DateTime.now()),
    );
    await load();
  }

  /// Applies an edit from the composer sheet: title, type, and the icon / color
  /// / reminder extras (any of which may be cleared by passing null). Switching
  /// a task→note clears completion. No-op if the title is blank.
  Future<void> updateItemMeta(
    Item item, {
    required String content,
    required ItemType type,
    String? icon,
    int? color,
    DateTime? reminderAt,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final updated = item.copyWith(
      content: trimmed,
      type: type,
      icon: icon,
      color: color,
      reminderAt: reminderAt,
      isDone: type == ItemType.task ? item.isDone : false,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    _syncReminder(updated);
    await load();
    await refreshReminderPermission();
  }

  /// Switches an item between note and task. Resets completion (a fresh task
  /// starts not-done; notes have no completion).
  Future<void> convertType(Item item) async {
    final newType = item.type == ItemType.note ? ItemType.task : ItemType.note;
    await _repository.update(
      item.copyWith(type: newType, isDone: false, updatedAt: DateTime.now()),
    );
    await load();
  }

  /// Edits the text content of an existing item.
  Future<void> editContent(Item item, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed == item.content) return;
    await _repository.update(
      item.copyWith(content: trimmed, updatedAt: DateTime.now()),
    );
    await load();
  }

  /// Deletes an item and its entire subtree.
  Future<void> deleteItem(String id) async {
    final n = notifications;
    if (n != null) {
      for (final subId in _subtreeIds(id)) {
        n.cancel(subId);
      }
    }
    await _repository.delete(id);
    await load();
  }

  /// Schedules or cancels [item]'s reminder to match its current state.
  void _syncReminder(Item item) {
    final n = notifications;
    if (n == null) return;
    final reminder = item.reminderAt;
    final active = item.type != ItemType.task || !item.isDone;
    if (reminder != null && active) {
      n.schedule(itemId: item.id, title: item.content, when: reminder);
    } else {
      n.cancel(item.id);
    }
  }

  /// [id] plus all of its descendant ids (for cancelling a deleted subtree).
  List<String> _subtreeIds(String id) {
    final byParent = <String?, List<Item>>{};
    for (final item in _items) {
      byParent.putIfAbsent(item.parentId, () => []).add(item);
    }
    final ids = <String>[id];
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final child in byParent[parent] ?? const <Item>[]) {
        ids.add(child.id);
        queue.add(child.id);
      }
    }
    return ids;
  }

  /// Re-arms reminders for all future, still-active items. Called at startup so
  /// web timers (which don't survive a reload) come back, and as a safety net
  /// on native. No-op without a [notifications] service.
  Future<void> rescheduleAll() async {
    final n = notifications;
    if (n == null) return;
    final now = DateTime.now();
    for (final item in _items) {
      final reminder = item.reminderAt;
      final active = item.type != ItemType.task || !item.isDone;
      if (reminder != null && active && reminder.isAfter(now)) {
        await n.schedule(itemId: item.id, title: item.content, when: reminder);
      }
    }
  }

  /// The ancestor chain from the root down to (and including) [id], ordered
  /// root → … → item. Returns an empty list if [id] is unknown.
  List<Item> pathTo(String id) {
    final byId = {for (final item in _items) item.id: item};
    final chain = <Item>[];
    var current = byId[id];
    while (current != null) {
      chain.add(current);
      current = current.parentId == null ? null : byId[current.parentId];
    }
    return chain.reversed.toList();
  }

  /// Whether [candidateId] is [ofId] itself or any of its descendants. Used to
  /// reject re-parenting an item into its own subtree (which would form a cycle).
  bool isDescendant(String candidateId, String ofId) {
    if (candidateId == ofId) return true;
    final byParent = <String?, List<Item>>{};
    for (final item in _items) {
      byParent.putIfAbsent(item.parentId, () => []).add(item);
    }
    final queue = <String>[ofId];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final child in byParent[parent] ?? const <Item>[]) {
        if (child.id == candidateId) return true;
        queue.add(child.id);
      }
    }
    return false;
  }

  /// Moves [item] (and its subtree) under [newParentId], placing it at the top
  /// of the new level. No-op if it would create a cycle or is already there.
  Future<void> reparent(Item item, String? newParentId) async {
    if (newParentId == item.id) return;
    if (newParentId == item.parentId) return;
    if (newParentId != null && isDescendant(newParentId, item.id)) return;
    await _repository.update(
      item.copyWith(
        parentId: newParentId,
        sortOrder: _nextSortOrder(newParentId),
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  /// Persists a new sibling order. [orderedIdsTopToBottom] is the desired
  /// top→bottom order of one group; the top gets the highest `sortOrder` so it
  /// surfaces first under the `sortOrder` DESC sort in [childrenOf].
  Future<void> reorderGroup(List<String> orderedIdsTopToBottom) async {
    final byId = {for (final item in _items) item.id: item};
    final n = orderedIdsTopToBottom.length;
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < n; i++) {
      final item = byId[orderedIdsTopToBottom[i]];
      if (item == null) continue;
      final newSort = n - 1 - i;
      if (item.sortOrder != newSort) {
        await _repository.update(
          item.copyWith(sortOrder: newSort, updatedAt: now),
        );
        changed = true;
      }
    }
    if (changed) await load();
  }

  int _nextSortOrder(String? parentId) {
    final siblings = _items.where((i) => i.parentId == parentId);
    if (siblings.isEmpty) return 0;
    return siblings.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }
}
