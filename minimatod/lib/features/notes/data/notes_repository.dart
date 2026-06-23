import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'note_model.dart';
import 'sync/sync_store.dart';

/// Storage abstraction for note/task [Item]s (Repository pattern).
///
/// Business logic depends on this interface, not on sqflite, so the backing
/// store can be swapped or faked in tests.
abstract class NotesRepository {
  /// All active items, unordered. Excludes archived and deleted items.
  Future<List<Item>> getAll();

  /// Direct children of [parentId] (pass null for root items), ordered.
  Future<List<Item>> getChildren(String? parentId);

  Future<Item?> getById(String id);

  /// All archived (not deleted) items, newest archive first. Used by the
  /// Archive screen.
  Future<List<Item>> getArchived();

  Future<void> add(Item item);

  Future<void> update(Item item);

  /// Persists several changed items in one transaction (e.g. a sibling
  /// reorder). Atomic — either all land or none.
  Future<void> updateMany(Iterable<Item> items);

  /// Archives [id] and its whole subtree (reversible — see [unarchive]).
  Future<void> archive(String id);

  /// Restores [id] and its archived subtree back onto the active board.
  Future<void> unarchive(String id);

  /// Deletes [id] and, via the self-referencing foreign key, its whole subtree.
  Future<void> delete(String id);
}

/// sqflite-backed [NotesRepository] using an adjacency-list table. Also serves
/// as the local side of sync ([SyncLocalStore]) — the same table carries the
/// per-row `synced_at` watermark.
class SqfliteNotesRepository implements NotesRepository, SyncLocalStore {
  SqfliteNotesRepository(this._appDb);

  final AppDatabase _appDb;

  static const _table = 'items';

  Future<Database> get _db => _appDb.db;

  @override
  Future<List<Item>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'deleted_at IS NULL AND archived_at IS NULL',
    );
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<List<Item>> getChildren(String? parentId) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: parentId == null
          ? 'parent_id IS NULL AND deleted_at IS NULL AND archived_at IS NULL'
          : 'parent_id = ? AND deleted_at IS NULL AND archived_at IS NULL',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<List<Item>> getArchived() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'archived_at IS NOT NULL AND deleted_at IS NULL',
      orderBy: 'archived_at DESC',
    );
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<Item?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  @override
  Future<void> add(Item item) async {
    final db = await _db;
    await db.insert(
      _table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Item item) async {
    final db = await _db;
    await db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> updateMany(Iterable<Item> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        batch.update(
          _table,
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> archive(String id) => _setArchived(id, archived: true);

  @override
  Future<void> unarchive(String id) => _setArchived(id, archived: false);

  /// Flips the archive state of [id] and its subtree in one transaction.
  ///
  /// When [archived] is true we walk the *active* subtree (children still on the
  /// board) and stamp `archived_at`; when false we walk the *archived* subtree
  /// and clear it. Bounding the walk to the matching state means re-archiving or
  /// restoring never reaches into items the user already moved the other way.
  Future<void> _setArchived(String id, {required bool archived}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    // Children eligible to follow the parent: not deleted, and currently in the
    // opposite archive state from where we're moving them.
    final childFilter =
        'parent_id = ? AND deleted_at IS NULL AND '
        '${archived ? 'archived_at IS NULL' : 'archived_at IS NOT NULL'}';

    await db.transaction((txn) async {
      final toMark = <String>[id];
      final queue = <String>[id];
      while (queue.isNotEmpty) {
        final parent = queue.removeAt(0);
        final children = await txn.query(
          _table,
          columns: ['id'],
          where: childFilter,
          whereArgs: [parent],
        );
        for (final row in children) {
          final childId = row['id']! as String;
          toMark.add(childId);
          queue.add(childId);
        }
      }

      for (final markId in toMark) {
        await txn.update(
          _table,
          {'archived_at': archived ? now : null, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [markId],
        );
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    // Soft-delete: mark the item and its whole subtree with a tombstone instead
    // of removing rows, so a future sync can propagate the deletion. (FK cascade
    // only fires on physical deletes, so we walk the subtree ourselves.)
    await db.transaction((txn) async {
      final toMark = <String>[id];
      final queue = <String>[id];
      while (queue.isNotEmpty) {
        final parent = queue.removeAt(0);
        final children = await txn.query(
          _table,
          columns: ['id'],
          where: 'parent_id = ? AND deleted_at IS NULL',
          whereArgs: [parent],
        );
        for (final row in children) {
          final childId = row['id']! as String;
          toMark.add(childId);
          queue.add(childId);
        }
      }

      for (final markId in toMark) {
        await txn.update(
          _table,
          {'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [markId],
        );
      }
    });
  }

  // --- SyncLocalStore -------------------------------------------------------

  @override
  Future<List<Item>> getPendingPush() async {
    final db = await _db;
    // ISO-8601 strings compare lexicographically in the same order as the
    // instants, so `synced_at < updated_at` is a valid "edited since push".
    final rows = await db.query(
      _table,
      where: 'synced_at IS NULL OR synced_at < updated_at',
    );
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<void> markPushed(Iterable<Item> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final item in items) {
        // Stamp the exact updatedAt we pushed — if the row changed again since,
        // its newer updatedAt keeps it dirty so the later edit isn't dropped.
        await txn.update(
          _table,
          {'synced_at': item.updatedAt.toIso8601String()},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
    });
  }

  @override
  Future<bool> applyRemote(Item incoming) async {
    final db = await _db;
    final existing = await db.query(
      _table,
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [incoming.id],
      limit: 1,
    );

    // Last-write-wins: skip when our copy is strictly newer. Ties favour the
    // incoming row (idempotent re-apply).
    if (existing.isNotEmpty) {
      final localUpdated = DateTime.parse(
        existing.first['updated_at']! as String,
      );
      if (localUpdated.isAfter(incoming.updatedAt)) return false;
    }

    // The applied row is in sync by definition, so stamp synced_at = updatedAt.
    await db.insert(
      _table,
      incoming.copyWith(syncedAt: incoming.updatedAt).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }
}
