import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../attachments/presentation/audio_controller.dart';
import '../../reminders/presentation/reminder_controller.dart';
import '../data/note_model.dart';
import '../data/note_tree.dart';
import '../data/notes_repository.dart';

/// Holds the note/task tree in memory and mediates all changes through the
/// [NotesRepository]. UI listens via [ChangeNotifier].
///
/// In-memory model: [_byId] is the single source of truth for the active board
/// (archived/deleted rows live only in storage). Mutations update [_byId]
/// directly and persist the one changed row — they do **not** re-read the whole
/// table, so a tap costs O(1) IO instead of reloading and re-parsing everything.
///
/// Read-side tree algorithms (child ordering, descendant counts, ancestry,
/// cycle detection) live in the pure [NoteTree]. The controller memoizes one in
/// [_tree], rebuilt lazily only when [_generation] advances — so a list render
/// no longer rebuilds an index per row. Full reloads ([load]) are reserved for
/// startup, bringing rows back from the archive, and (later) applying a server
/// sync.
class NotesController extends ChangeNotifier {
  NotesController(this._repository, {Uuid? uuid, this.reminders, this.audio})
    : _uuid = uuid ?? const Uuid() {
    // Reflect reminder-permission badge changes in the notes UI by re-emitting
    // when the reminder controller notifies. (Permission changes are rare, so
    // the extra rebuild is negligible.)
    reminders?.addListener(notifyListeners);
  }

  final NotesRepository _repository;
  final Uuid _uuid;

  /// Reminder scheduling + notification-permission state, in its own controller.
  /// Null in tests / when notifications are off. Read by the badge UI and the
  /// composer via the notes controller they already hold.
  final ReminderController? reminders;

  /// Voice-note recording/playback, in its own controller. Null in tests. Held
  /// here so the note detail can reach it via the notes controller it has.
  final AudioController? audio;

  /// Active items by id — the in-memory source of truth.
  final Map<String, Item> _byId = {};
  bool _isLoading = false;

  /// Bumped on every change to [_byId]; the [_tree] snapshot rebuilds when it
  /// notices its generation is stale.
  int _generation = 0;
  int _cacheGeneration = -1;
  NoteTree _treeCache = NoteTree.empty();

  // --- in-memory store helpers ---------------------------------------------

  /// An indexed [NoteTree] snapshot of the active board, rebuilt once per
  /// [_generation] then reused for all read queries.
  NoteTree get _tree {
    if (_cacheGeneration != _generation) {
      _treeCache = NoteTree(_byId.values);
      _cacheGeneration = _generation;
    }
    return _treeCache;
  }

  /// Inserts/replaces one item in the in-memory store and invalidates caches.
  void _put(Item item) {
    _byId[item.id] = item;
    _generation++;
  }

  /// Removes a set of ids (an item + its subtree) and invalidates caches.
  void _removeAll(Iterable<String> ids) {
    for (final id in ids) {
      _byId.remove(id);
    }
    _generation++;
  }

  // --- queries --------------------------------------------------------------

  /// Flat list of every active item, unordered.
  List<Item> get items => List.unmodifiable(_byId.values);

  /// The active item with [id], or null. O(1) — reads the in-memory store
  /// directly, so detail panes can resolve their selection without scanning.
  Item? itemById(String id) => _byId[id];

  /// Direct children of [parentId] (pass null for root level), ordered newest
  /// first by `sortOrder` then `createdAt`.
  List<Item> childrenOf(String? parentId) =>
      List.unmodifiable(_tree.children(parentId));

  /// Completed / uncompleted counts of all descendant **tasks** of [parentId]
  /// (recursively, at any depth). Notes are never counted.
  ({int completed, int uncompleted}) descendantTaskCounts(String? parentId) =>
      _tree.descendantTaskCounts(parentId);

  bool get isLoading => _isLoading;

  /// Loads (or reloads) the whole active board from storage. Used at startup,
  /// after restoring from the archive, and — in the future — to apply a sync.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final all = await _repository.getAll();
    _byId
      ..clear()
      ..addEntries(all.map((i) => MapEntry(i.id, i)));
    _generation++;
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
    PendingRecording? recording,
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
    _put(item);
    notifyListeners();
    await _syncReminder(item);
    if (recording != null) await audio?.attach(item.id, recording);
  }

  /// Flips the completion state of a task. Completing a task cancels its
  /// reminder; un-completing re-arms it (if still in the future).
  Future<void> toggleDone(Item item) async {
    final updated = item.copyWith(
      isDone: !item.isDone,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    _put(updated);
    notifyListeners();
    // _syncReminder cancels when the task is now done, schedules when undone.
    await _syncReminder(updated);
  }

  /// Saves the long-form note [body] for the item with [id]. Looks up the live
  /// item so a stale snapshot can't clobber other fields. No-op if unchanged or
  /// the item is gone.
  ///
  /// Deliberately does **not** notify listeners: the body isn't shown in any
  /// list, and the open editor owns its own text (and re-reads via [itemById]
  /// on its next rebuild). Notifying here would rebuild the whole 3-pane wide
  /// layout — re-running the list's task counts — on every ~600ms autosave
  /// while typing. The body isn't tree-indexed, so there's no generation bump.
  Future<void> setBody(String id, String body) async {
    final item = _byId[id];
    if (item == null) return;
    if ((item.body ?? '') == body) return;
    final updated = item.copyWith(body: body, updatedAt: DateTime.now());
    await _repository.update(updated);
    _byId[id] = updated;
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
    _put(updated);
    notifyListeners();
    await _syncReminder(updated);
  }

  /// Switches an item between note and task. Resets completion (a fresh task
  /// starts not-done; notes have no completion).
  Future<void> convertType(Item item) async {
    final newType = item.type == ItemType.note ? ItemType.task : ItemType.note;
    final updated = item.copyWith(
      type: newType,
      isDone: false,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    _put(updated);
    notifyListeners();
  }

  /// Edits the text content of an existing item.
  Future<void> editContent(Item item, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed == item.content) return;
    final updated = item.copyWith(content: trimmed, updatedAt: DateTime.now());
    await _repository.update(updated);
    _put(updated);
    notifyListeners();
  }

  /// Archives an item and its entire subtree, hiding it from the active board
  /// (restorable later from the Archive screen). Cancels any reminders so an
  /// archived item never pings.
  Future<void> archiveItem(String id) async {
    final ids = _subtreeIds(id);
    for (final subId in ids) {
      reminders?.cancel(subId);
    }
    await _repository.archive(id);
    _removeAll(ids);
    notifyListeners();
  }

  /// Restores an archived item (and its archived subtree) back onto the board,
  /// re-arming any future reminders it carried. The restored rows live outside
  /// [_byId], so this reloads to bring them back in.
  Future<void> unarchiveItem(String id) async {
    await _repository.unarchive(id);
    await load();
    await rescheduleReminders();
    await reminders?.refresh();
  }

  /// The archived items (newest first), loaded straight from storage. Archived
  /// rows live outside the in-memory [items] board, so the Archive screen reads
  /// them on demand.
  Future<List<Item>> loadArchived() => _repository.getArchived();

  /// Deletes an item and its entire subtree.
  Future<void> deleteItem(String id) async {
    final ids = _subtreeIds(id);
    for (final subId in ids) {
      reminders?.cancel(subId);
    }
    await _repository.delete(id);
    _removeAll(ids);
    notifyListeners();
  }

  /// [id] plus all of its descendant ids (for cancelling/removing a subtree).
  List<String> _subtreeIds(String id) => _tree.subtreeIds(id);

  /// Arms or cancels [item]'s reminder to match its current state — a future
  /// time on an active item schedules; a completed task or cleared time cancels.
  /// The Item→reminder rule lives here (a notes concern); [reminders] just runs
  /// the scheduling, knowing nothing about items.
  Future<void> _syncReminder(Item item) async {
    final r = reminders;
    if (r == null) return;
    final when = item.reminderAt;
    final active = item.type != ItemType.task || !item.isDone;
    if (when != null && active) {
      await r.schedule(id: item.id, title: item.content, when: when);
    } else {
      r.cancel(item.id);
      await r.refresh();
    }
  }

  /// Re-arms reminders for every future, still-active item. Called at startup so
  /// web timers (which don't survive a reload) come back, and after an archive
  /// restore.
  Future<void> rescheduleReminders() async {
    final r = reminders;
    if (r == null) return;
    final now = DateTime.now();
    for (final item in _byId.values) {
      final when = item.reminderAt;
      final active = item.type != ItemType.task || !item.isDone;
      if (when != null && active && when.isAfter(now)) {
        await r.schedule(id: item.id, title: item.content, when: when);
      }
    }
  }

  /// The ancestor chain from the root down to (and including) [id], ordered
  /// root → … → item. Returns an empty list if [id] is unknown.
  List<Item> pathTo(String id) => _tree.pathTo(id);

  /// Whether [candidateId] is [ofId] itself or any of its descendants. Used to
  /// reject re-parenting an item into its own subtree (which would form a cycle).
  bool isDescendant(String candidateId, String ofId) =>
      _tree.isDescendant(candidateId, ofId);

  /// Moves [item] (and its subtree) under [newParentId], placing it at the top
  /// of the new level. No-op if it would create a cycle or is already there.
  Future<void> reparent(Item item, String? newParentId) async {
    if (newParentId == item.id) return;
    if (newParentId == item.parentId) return;
    if (newParentId != null && isDescendant(newParentId, item.id)) return;
    final updated = item.copyWith(
      parentId: newParentId,
      sortOrder: _nextSortOrder(newParentId),
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    _put(updated);
    notifyListeners();
  }

  /// Persists a new sibling order. [orderedIdsTopToBottom] is the desired
  /// top→bottom order of one group; the top gets the highest `sortOrder` so it
  /// surfaces first under the `sortOrder` DESC sort in [childrenOf].
  Future<void> reorderGroup(List<String> orderedIdsTopToBottom) async {
    final n = orderedIdsTopToBottom.length;
    final now = DateTime.now();
    final changed = <Item>[];
    for (var i = 0; i < n; i++) {
      final item = _byId[orderedIdsTopToBottom[i]];
      if (item == null) continue;
      final newSort = n - 1 - i;
      if (item.sortOrder != newSort) {
        changed.add(item.copyWith(sortOrder: newSort, updatedAt: now));
      }
    }
    if (changed.isEmpty) return;
    // One transaction instead of N awaited writes — atomic, far fewer fsyncs,
    // and a single rebuild.
    await _repository.updateMany(changed);
    for (final item in changed) {
      _byId[item.id] = item;
    }
    _generation++;
    notifyListeners();
  }

  int _nextSortOrder(String? parentId) => _tree.nextSortOrder(parentId);

  @override
  void dispose() {
    reminders?.removeListener(notifyListeners);
    super.dispose();
  }
}
