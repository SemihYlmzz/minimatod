import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/core/database/app_database.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real [SqfliteNotesRepository] against an in-memory SQLite
/// database via the FFI factory (already a runtime dependency, so no new dev
/// dependency). This is the first coverage of the SQL layer itself — schema,
/// visibility filters, subtree cascade, batch writes, and the sync local store
/// (LWW). Each test gets its own fresh in-memory database.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // A fresh, isolated repository per test. Closing it in teardown drops the
  // in-memory database from sqflite's single-instance cache, so the next test
  // opens a brand-new empty one (':memory:' is otherwise shared by path within
  // the test process).
  SqfliteNotesRepository newRepo() {
    final db = AppDatabase(databaseName: inMemoryDatabasePath);
    addTearDown(db.close);
    return SqfliteNotesRepository(db);
  }

  final epoch = DateTime.utc(2026, 1, 1);

  Item note(
    String id, {
    String? parentId,
    int sortOrder = 0,
    String? body,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) => Item(
    id: id,
    parentId: parentId,
    type: ItemType.note,
    content: 'c-$id',
    body: body,
    sortOrder: sortOrder,
    createdAt: epoch,
    updatedAt: updatedAt ?? epoch,
    syncedAt: syncedAt,
  );

  test('add + getById round-trips every field, including body', () async {
    final repo = newRepo();
    final item = note('a', body: 'long body').copyWith(
      color: 0xFF112233,
      icon: 'star',
      reminderAt: DateTime.utc(2030, 5, 5),
    );
    await repo.add(item);

    final got = await repo.getById('a');
    expect(got, isNotNull);
    expect(got!.body, 'long body');
    expect(got.icon, 'star');
    expect(got.color, 0xFF112233);
    expect(got.reminderAt, DateTime.utc(2030, 5, 5));
  });

  test('getAll excludes archived and deleted rows', () async {
    final repo = newRepo();
    await repo.add(note('a'));
    await repo.add(note('b'));
    await repo.add(note('c'));
    await repo.archive('b');
    await repo.delete('c');

    expect((await repo.getAll()).map((i) => i.id), ['a']);
  });

  test('getChildren returns active children in sibling order', () async {
    final repo = newRepo();
    await repo.add(note('p'));
    await repo.add(note('c1', parentId: 'p', sortOrder: 0));
    await repo.add(note('c2', parentId: 'p', sortOrder: 1));
    await repo.add(note('orphan'));

    final children = await repo.getChildren('p');
    expect(children.map((i) => i.id), ['c1', 'c2']);
  });

  test('delete tombstones the whole subtree', () async {
    final repo = newRepo();
    await repo.add(note('p'));
    await repo.add(note('c', parentId: 'p'));
    await repo.add(note('g', parentId: 'c'));

    await repo.delete('p');

    expect(await repo.getAll(), isEmpty);
    expect(await repo.getArchived(), isEmpty);
  });

  test('archive then unarchive restores the subtree', () async {
    final repo = newRepo();
    await repo.add(note('p'));
    await repo.add(note('c', parentId: 'p'));

    await repo.archive('p');
    expect(await repo.getAll(), isEmpty);
    expect((await repo.getArchived()).map((i) => i.id).toSet(), {'p', 'c'});

    await repo.unarchive('p');
    expect((await repo.getAll()).map((i) => i.id).toSet(), {'p', 'c'});
    expect(await repo.getArchived(), isEmpty);
  });

  test('updateMany batches sort-order changes atomically', () async {
    final repo = newRepo();
    await repo.add(note('a', sortOrder: 0));
    await repo.add(note('b', sortOrder: 1));

    await repo.updateMany([
      (await repo.getById('a'))!.copyWith(sortOrder: 10),
      (await repo.getById('b'))!.copyWith(sortOrder: 20),
    ]);

    expect((await repo.getById('a'))!.sortOrder, 10);
    expect((await repo.getById('b'))!.sortOrder, 20);
  });

  group('SyncLocalStore', () {
    test('getPendingPush returns dirty rows; markPushed clears them', () async {
      final repo = newRepo();
      await repo.add(note('dirty')); // synced_at null => dirty
      await repo.add(note('clean', updatedAt: epoch, syncedAt: epoch));

      final pending = await repo.getPendingPush();
      expect(pending.map((i) => i.id), contains('dirty'));
      expect(pending.map((i) => i.id), isNot(contains('clean')));

      await repo.markPushed(pending);
      expect(await repo.getPendingPush(), isEmpty);
    });

    test('applyRemote applies a newer row and rejects an older one', () async {
      final repo = newRepo();
      await repo.add(
        note(
          'a',
          updatedAt: DateTime.utc(2026, 6, 1),
        ).copyWith(content: 'local'),
      );

      final older = note(
        'a',
        updatedAt: DateTime.utc(2026, 5, 1),
      ).copyWith(content: 'older');
      expect(await repo.applyRemote(older), isFalse);
      expect((await repo.getById('a'))!.content, 'local');

      final newer = note(
        'a',
        updatedAt: DateTime.utc(2026, 7, 1),
      ).copyWith(content: 'newer');
      expect(await repo.applyRemote(newer), isTrue);
      expect((await repo.getById('a'))!.content, 'newer');
      // An applied remote row is in sync, so it is no longer pending push.
      expect(
        (await repo.getPendingPush()).map((i) => i.id),
        isNot(contains('a')),
      );
    });
  });
}
