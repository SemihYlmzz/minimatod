import 'note_model.dart';

/// An immutable, indexed snapshot of the active note/task tree.
///
/// Pure domain logic — no Flutter, no IO, no `DateTime.now()`. It holds every
/// read-side tree algorithm (child ordering, descendant counts, ancestry, cycle
/// detection, next sort order) so they can be unit-tested in isolation and, in
/// future, reused for server-side or smartwatch parity without dragging in the
/// app's storage or state layers.
///
/// Build one from the current set of active items; it indexes them once up
/// front, then answers queries cheaply. Rebuild (don't mutate) when the data
/// changes — that's how [NotesController] uses it, rebuilding only when its
/// in-memory store advances a generation.
class NoteTree {
  NoteTree(Iterable<Item> items)
    : _byId = {for (final item in items) item.id: item},
      _childrenSorted = _buildChildren(items);

  /// An empty tree (no items).
  factory NoteTree.empty() => NoteTree(const <Item>[]);

  final Map<String, Item> _byId;
  final Map<String?, List<Item>> _childrenSorted;

  static Map<String?, List<Item>> _buildChildren(Iterable<Item> items) {
    final map = <String?, List<Item>>{};
    for (final item in items) {
      (map[item.parentId] ??= <Item>[]).add(item);
    }
    for (final list in map.values) {
      list.sort(_compareSiblings);
    }
    return map;
  }

  /// Sibling order: newest first by `sortOrder`, breaking ties by `createdAt`
  /// (both descending). The top of a level holds the highest `sortOrder`.
  static int _compareSiblings(Item a, Item b) {
    final byOrder = b.sortOrder.compareTo(a.sortOrder);
    return byOrder != 0 ? byOrder : b.createdAt.compareTo(a.createdAt);
  }

  /// The item with [id], or null if it isn't in this snapshot.
  Item? operator [](String id) => _byId[id];

  /// Every item in the snapshot, unordered.
  Iterable<Item> get all => _byId.values;

  /// Number of items in the snapshot.
  int get length => _byId.length;

  /// Direct children of [parentId] (null = root level), in sibling order. The
  /// returned list is the internal one — treat it as read-only.
  List<Item> children(String? parentId) =>
      _childrenSorted[parentId] ?? const <Item>[];

  /// Completed / uncompleted counts of all descendant **tasks** of [parentId]
  /// (recursively, any depth). Notes are never counted.
  ({int completed, int uncompleted}) descendantTaskCounts(String? parentId) {
    var completed = 0;
    var uncompleted = 0;
    void visit(String? pid) {
      for (final child in children(pid)) {
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

  /// [id] plus all of its descendant ids (e.g. to cancel/remove a subtree).
  List<String> subtreeIds(String id) {
    final ids = <String>[id];
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final child in children(parent)) {
        ids.add(child.id);
        queue.add(child.id);
      }
    }
    return ids;
  }

  /// The ancestor chain from the root down to (and including) [id], ordered
  /// root → … → item. Empty when [id] is unknown.
  List<Item> pathTo(String id) {
    final chain = <Item>[];
    var current = _byId[id];
    while (current != null) {
      chain.add(current);
      current = current.parentId == null ? null : _byId[current.parentId];
    }
    return chain.reversed.toList();
  }

  /// Whether [candidateId] is [ofId] itself or any of its descendants. Used to
  /// reject re-parenting an item into its own subtree (which forms a cycle).
  bool isDescendant(String candidateId, String ofId) {
    if (candidateId == ofId) return true;
    final queue = <String>[ofId];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final child in children(parent)) {
        if (child.id == candidateId) return true;
        queue.add(child.id);
      }
    }
    return false;
  }

  /// The `sortOrder` a new child of [parentId] should take to land on top
  /// (highest among its siblings, or 0 when there are none).
  int nextSortOrder(String? parentId) {
    final siblings = _childrenSorted[parentId];
    if (siblings == null || siblings.isEmpty) return 0;
    return siblings.first.sortOrder + 1; // sorted by sortOrder DESC
  }
}
