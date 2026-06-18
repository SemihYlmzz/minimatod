import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/note_model.dart';
import '../data/notes_repository.dart';
import '../data/tree_builder.dart';
import '../data/tree_node.dart';

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

  /// The items assembled into a nested forest, ordered for display.
  List<TreeNode> get tree => buildTree(_items);

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

  int _nextSortOrder(String? parentId) {
    final siblings = _items.where((i) => i.parentId == parentId);
    if (siblings.isEmpty) return 0;
    return siblings.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }
}
