import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/note_model.dart';
import '../data/notes_repository.dart';

/// Holds the note/task tree in memory and mediates all changes through the
/// [NotesRepository]. UI listens via [ChangeNotifier].
class NotesController extends ChangeNotifier {
  NotesController(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final NotesRepository _repository;
  final Uuid _uuid;

  List<Item> _items = const [];
  bool _isLoading = false;

  /// Flat list of every item, unordered.
  List<Item> get items => List.unmodifiable(_items);

  /// Direct children of [parentId] (pass null for root level), ordered newest
  /// first by `sortOrder` then `createdAt`.
  List<Item> childrenOf(String? parentId) {
    return _items.where((i) => i.parentId == parentId).toList()
      ..sort((a, b) {
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

  /// Creates a new note/task, optionally nested under [parentId].
  Future<void> addItem({
    required String content,
    required ItemType type,
    String? parentId,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final item = Item(
      id: _uuid.v4(),
      parentId: parentId,
      type: type,
      content: trimmed,
      sortOrder: _nextSortOrder(parentId),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.add(item);
    await load();
  }

  /// Flips the completion state of a task.
  Future<void> toggleDone(Item item) async {
    await _repository.update(
      item.copyWith(isDone: !item.isDone, updatedAt: DateTime.now()),
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
    await _repository.delete(id);
    await load();
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

  int _nextSortOrder(String? parentId) {
    final siblings = _items.where((i) => i.parentId == parentId);
    if (siblings.isEmpty) return 0;
    return siblings.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }
}
