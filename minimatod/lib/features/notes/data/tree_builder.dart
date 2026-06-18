import 'note_model.dart';
import 'tree_node.dart';

/// Turns a flat adjacency list of [items] into a nested [TreeNode] forest.
///
/// Items are grouped by their `parentId`; each level is sorted by `sortOrder`
/// (ties broken by `createdAt`) and resolved recursively. Roots are items whose
/// `parentId` is null or points to an id not present in [items] (orphans are
/// promoted to roots so nothing is silently dropped).
List<TreeNode> buildTree(List<Item> items) {
  final childrenByParent = <String?, List<Item>>{};
  final ids = {for (final item in items) item.id};

  for (final item in items) {
    final key = (item.parentId != null && ids.contains(item.parentId))
        ? item.parentId
        : null;
    childrenByParent.putIfAbsent(key, () => []).add(item);
  }

  List<TreeNode> nodesFor(String? parentId) {
    final children = childrenByParent[parentId] ?? const [];
    final sorted = [...children]..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
      });
    return [
      for (final item in sorted)
        TreeNode(item: item, children: nodesFor(item.id)),
    ];
  }

  return nodesFor(null);
}
