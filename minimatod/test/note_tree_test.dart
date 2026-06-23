import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/note_tree.dart';

/// Builds an [Item] with terse defaults so the tests read as tree shapes.
Item item(
  String id, {
  String? parent,
  ItemType type = ItemType.note,
  bool done = false,
  int sort = 0,
  int createdMs = 0,
}) {
  final ts = DateTime.fromMillisecondsSinceEpoch(createdMs);
  return Item(
    id: id,
    parentId: parent,
    type: type,
    content: id,
    isDone: done,
    sortOrder: sort,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  group('NoteTree.children', () {
    test('orders siblings by sortOrder desc, then createdAt desc', () {
      final tree = NoteTree([
        item('a', sort: 1, createdMs: 100),
        item('b', sort: 3, createdMs: 100),
        item('c', sort: 1, createdMs: 200), // ties sortOrder with a, newer
      ]);

      expect(tree.children(null).map((i) => i.id), ['b', 'c', 'a']);
    });

    test('scopes to the given parent and returns const for unknown', () {
      final tree = NoteTree([item('root'), item('child', parent: 'root')]);

      expect(tree.children('root').map((i) => i.id), ['child']);
      expect(tree.children('nope'), isEmpty);
    });
  });

  group('NoteTree.descendantTaskCounts', () {
    test('counts tasks recursively, ignoring notes', () {
      // root
      //  ├ t1 (task, done)
      //  ├ n1 (note)
      //  │   └ t2 (task, open)
      //  └ t3 (task, open)
      final tree = NoteTree([
        item('root'),
        item('t1', parent: 'root', type: ItemType.task, done: true),
        item('n1', parent: 'root'),
        item('t2', parent: 'n1', type: ItemType.task),
        item('t3', parent: 'root', type: ItemType.task),
      ]);

      final counts = tree.descendantTaskCounts('root');
      expect(counts.completed, 1);
      expect(counts.uncompleted, 2);
    });

    test('is zero for a leaf', () {
      final tree = NoteTree([item('a')]);
      expect(tree.descendantTaskCounts('a'), (completed: 0, uncompleted: 0));
    });
  });

  group('NoteTree.subtreeIds', () {
    test('returns the id plus every descendant', () {
      final tree = NoteTree([
        item('a'),
        item('b', parent: 'a'),
        item('c', parent: 'b'),
        item('d', parent: 'a'),
        item('x'), // unrelated
      ]);

      expect(tree.subtreeIds('a').toSet(), {'a', 'b', 'c', 'd'});
      expect(tree.subtreeIds('b').toSet(), {'b', 'c'});
    });
  });

  group('NoteTree.pathTo', () {
    test('returns the root→item ancestor chain', () {
      final tree = NoteTree([
        item('a'),
        item('b', parent: 'a'),
        item('c', parent: 'b'),
      ]);

      expect(tree.pathTo('c').map((i) => i.id), ['a', 'b', 'c']);
      expect(tree.pathTo('a').map((i) => i.id), ['a']);
      expect(tree.pathTo('unknown'), isEmpty);
    });
  });

  group('NoteTree.isDescendant', () {
    final tree = NoteTree([
      item('a'),
      item('b', parent: 'a'),
      item('c', parent: 'b'),
    ]);

    test('an item is its own descendant (self-move guard)', () {
      expect(tree.isDescendant('a', 'a'), isTrue);
    });

    test('detects a descendant at any depth', () {
      expect(tree.isDescendant('c', 'a'), isTrue);
    });

    test('an ancestor is not a descendant', () {
      expect(tree.isDescendant('a', 'c'), isFalse);
    });
  });

  group('NoteTree.nextSortOrder', () {
    test('is one above the current max sibling', () {
      final tree = NoteTree([
        item('a', sort: 2),
        item('b', sort: 5),
        item('c', sort: 3),
      ]);
      expect(tree.nextSortOrder(null), 6);
    });

    test('is 0 when there are no siblings', () {
      expect(NoteTree.empty().nextSortOrder(null), 0);
      expect(NoteTree([item('a')]).nextSortOrder('a'), 0);
    });
  });
}
