import 'note_model.dart';

/// An [Item] together with its resolved child subtree.
///
/// Produced by `buildTree` to turn a flat adjacency list into a nested
/// structure the UI can render recursively.
class TreeNode {
  const TreeNode({required this.item, required this.children});

  final Item item;
  final List<TreeNode> children;

  bool get hasChildren => children.isNotEmpty;
}
