import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/sync/remote_data_source.dart';
import 'package:minimatod/features/notes/data/sync/sync_engine.dart';
import 'package:minimatod/features/notes/data/sync/sync_store.dart';

DateTime _t(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

/// An [Item] with explicit sync timing; everything else defaulted.
Item mk(
  String id, {
  required int updated,
  int? synced,
  bool deleted = false,
  String content = 'x',
}) {
  return Item(
    id: id,
    type: ItemType.note,
    content: content,
    createdAt: _t(0),
    updatedAt: _t(updated),
    syncedAt: synced == null ? null : _t(synced),
    deletedAt: deleted ? _t(updated) : null,
  );
}

/// In-memory [SyncLocalStore] mirroring the sqflite implementation's rules.
class FakeSyncStore implements SyncLocalStore {
  FakeSyncStore([Iterable<Item> seed = const []]) {
    for (final i in seed) {
      store[i.id] = i;
    }
  }

  final Map<String, Item> store = {};

  @override
  Future<List<Item>> getPendingPush() async =>
      store.values.where((i) => i.isDirty).toList();

  @override
  Future<void> markPushed(Iterable<Item> items) async {
    for (final item in items) {
      final row = store[item.id];
      if (row != null) store[item.id] = row.copyWith(syncedAt: item.updatedAt);
    }
  }

  @override
  Future<bool> applyRemote(Item incoming) async {
    final existing = store[incoming.id];
    if (existing != null && existing.updatedAt.isAfter(incoming.updatedAt)) {
      return false;
    }
    store[incoming.id] = incoming.copyWith(syncedAt: incoming.updatedAt);
    return true;
  }
}

/// Captures pushes and replays a scripted pull.
class FakeRemote implements RemoteDataSource {
  FakeRemote({this.toPull = const []});

  List<Item> toPull;
  final List<Item> pushed = [];

  @override
  Future<void> push(List<Item> changes) async => pushed.addAll(changes);

  @override
  Future<List<Item>> pull(DateTime? since) async => toPull;
}

void main() {
  test('pushes dirty rows and marks them synced', () async {
    final store = FakeSyncStore([
      mk('a', updated: 10),
    ]); // syncedAt null -> dirty
    final remote = FakeRemote();
    final result = await SyncEngine(store, remote).sync();

    expect(result.pushed, 1);
    expect(remote.pushed.single.id, 'a');
    expect(store.store['a']!.isDirty, isFalse);
  });

  test('does not push a clean row', () async {
    final store = FakeSyncStore([mk('a', updated: 10, synced: 10)]);
    final remote = FakeRemote();
    final result = await SyncEngine(store, remote).sync();

    expect(result.pushed, 0);
    expect(remote.pushed, isEmpty);
  });

  test('pull applies a strictly newer remote row (LWW)', () async {
    final store = FakeSyncStore([mk('a', updated: 10, synced: 10)]);
    final remote = FakeRemote(
      toPull: [mk('a', updated: 20, content: 'remote')],
    );

    final result = await SyncEngine(store, remote).sync();

    expect(result.pulled, 1);
    expect(store.store['a']!.content, 'remote');
    expect(store.store['a']!.isDirty, isFalse);
  });

  test('pull ignores an older remote row (LWW)', () async {
    final store = FakeSyncStore([
      mk('a', updated: 20, synced: 20, content: 'mine'),
    ]);
    final remote = FakeRemote(toPull: [mk('a', updated: 10, content: 'stale')]);

    final result = await SyncEngine(store, remote).sync();

    expect(result.pulled, 0);
    expect(store.store['a']!.content, 'mine');
  });

  test('pull applies a newer delete tombstone', () async {
    final store = FakeSyncStore([mk('a', updated: 10, synced: 10)]);
    final remote = FakeRemote(toPull: [mk('a', updated: 20, deleted: true)]);

    await SyncEngine(store, remote).sync();

    expect(store.store['a']!.isDeleted, isTrue);
  });

  test('pull inserts an unseen remote row', () async {
    final store = FakeSyncStore();
    final remote = FakeRemote(toPull: [mk('z', updated: 5)]);

    final result = await SyncEngine(store, remote).sync();

    expect(result.pulled, 1);
    expect(store.store.containsKey('z'), isTrue);
  });

  test('noop remote leaves a clean store unchanged', () async {
    final store = FakeSyncStore([mk('a', updated: 10, synced: 10)]);
    final result = await SyncEngine(store, const NoopRemoteDataSource()).sync();

    expect(result.changedAnything, isFalse);
  });
}
