import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';

/// An in-memory [NotesRepository] that mirrors the real one's visibility rules
/// (archived / deleted rows are hidden) and its subtree-cascading archive and
/// delete — enough to drive [NotesController] without sqflite.
class FakeNotesRepository implements NotesRepository {
  final Map<String, Item> _store = {};

  bool _active(Item i) => !i.isDeleted && !i.isArchived;

  List<String> _subtree(String id, {required bool Function(Item) include}) {
    final ids = <String>[id];
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final i in _store.values) {
        if (i.parentId == parent && i.id != parent && include(i)) {
          ids.add(i.id);
          queue.add(i.id);
        }
      }
    }
    return ids;
  }

  @override
  Future<void> add(Item item) async => _store[item.id] = item;

  @override
  Future<void> update(Item item) async => _store[item.id] = item;

  @override
  Future<void> updateMany(Iterable<Item> items) async {
    for (final item in items) {
      _store[item.id] = item;
    }
  }

  @override
  Future<Item?> getById(String id) async {
    final i = _store[id];
    return (i != null && _active(i)) ? i : null;
  }

  @override
  Future<List<Item>> getAll() async => _store.values.where(_active).toList();

  @override
  Future<List<Item>> getChildren(String? parentId) async =>
      _store.values.where((i) => i.parentId == parentId && _active(i)).toList();

  @override
  Future<List<Item>> getArchived() async =>
      _store.values.where((i) => i.isArchived && !i.isDeleted).toList();

  @override
  Future<void> archive(String id) async {
    final now = DateTime.now();
    for (final sub in _subtree(
      id,
      include: (i) => !i.isDeleted && !i.isArchived,
    )) {
      _store[sub] = _store[sub]!.copyWith(archivedAt: now);
    }
  }

  @override
  Future<void> unarchive(String id) async {
    for (final sub in _subtree(
      id,
      include: (i) => !i.isDeleted && i.isArchived,
    )) {
      _store[sub] = _store[sub]!.copyWith(archivedAt: null);
    }
  }

  @override
  Future<void> delete(String id) async {
    final now = DateTime.now();
    for (final sub in _subtree(id, include: (i) => !i.isDeleted)) {
      _store[sub] = _store[sub]!.copyWith(deletedAt: now);
    }
  }
}

void main() {
  late FakeNotesRepository repo;
  late NotesController controller;

  /// The first active item whose title is [content].
  Item byContent(String content) =>
      controller.items.firstWhere((i) => i.content == content);

  setUp(() async {
    repo = FakeNotesRepository();
    controller = NotesController(repo);
    await controller.load();
  });

  test('addItem inserts into the board without a reload', () async {
    await controller.addItem(content: 'A', type: ItemType.note);

    expect(controller.items, hasLength(1));
    expect(controller.childrenOf(null).single.content, 'A');
  });

  test('toggleDone flips completion in memory', () async {
    await controller.addItem(content: 'T', type: ItemType.task);
    final task = byContent('T');
    expect(task.isDone, isFalse);

    await controller.toggleDone(task);
    expect(byContent('T').isDone, isTrue);
  });

  test('editContent updates the title', () async {
    await controller.addItem(content: 'old', type: ItemType.note);
    await controller.editContent(byContent('old'), 'new');

    expect(controller.items.single.content, 'new');
  });

  test(
    'setBody saves the body without notifying (no autosave rebuild)',
    () async {
      await controller.addItem(content: 'note', type: ItemType.note);
      final id = byContent('note').id;
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setBody(id, 'hello world');

      expect(controller.itemById(id)?.body, 'hello world');
      // The note editor owns its text; autosave must not rebuild the 3-pane UI.
      expect(notified, 0);
    },
  );

  test('descendantTaskCounts reflects nested completion', () async {
    await controller.addItem(content: 'parent', type: ItemType.note);
    final parent = byContent('parent');
    await controller.addItem(
      content: 'child',
      type: ItemType.task,
      parentId: parent.id,
    );

    expect(controller.descendantTaskCounts(parent.id).uncompleted, 1);
    await controller.toggleDone(byContent('child'));
    expect(controller.descendantTaskCounts(parent.id).completed, 1);
  });

  test('reparent moves an item under a new parent', () async {
    await controller.addItem(content: 'p', type: ItemType.note);
    await controller.addItem(content: 'x', type: ItemType.note);
    final p = byContent('p');

    await controller.reparent(byContent('x'), p.id);

    expect(controller.childrenOf(null).map((i) => i.content), ['p']);
    expect(controller.childrenOf(p.id).single.content, 'x');
  });

  test('reparent into own subtree is rejected (no cycle)', () async {
    await controller.addItem(content: 'a', type: ItemType.note);
    final a = byContent('a');
    await controller.addItem(content: 'b', type: ItemType.note, parentId: a.id);
    final b = byContent('b');

    await controller.reparent(a, b.id); // would create a cycle
    expect(byContent('a').parentId, isNull); // unchanged
  });

  test('reorderGroup persists a new top-to-bottom order', () async {
    for (final c in ['a', 'b', 'c']) {
      await controller.addItem(content: c, type: ItemType.note);
    }
    final ids = ['c', 'a', 'b'].map((c) => byContent(c).id).toList();

    await controller.reorderGroup(ids);

    expect(controller.childrenOf(null).map((i) => i.content), ['c', 'a', 'b']);
  });

  test('archive hides a subtree; unarchive restores it', () async {
    await controller.addItem(content: 'p', type: ItemType.note);
    final p = byContent('p');
    await controller.addItem(content: 'c', type: ItemType.note, parentId: p.id);

    await controller.archiveItem(p.id);
    expect(controller.items, isEmpty);
    expect(await controller.loadArchived(), hasLength(2));

    await controller.unarchiveItem(p.id);
    expect(controller.items.map((i) => i.content).toSet(), {'p', 'c'});
    expect(await controller.loadArchived(), isEmpty);
  });

  test('delete removes an item and its descendants', () async {
    await controller.addItem(content: 'p', type: ItemType.note);
    final p = byContent('p');
    await controller.addItem(content: 'c', type: ItemType.note, parentId: p.id);

    await controller.deleteItem(p.id);

    expect(controller.items, isEmpty);
    expect(await controller.loadArchived(), isEmpty);
  });
}
