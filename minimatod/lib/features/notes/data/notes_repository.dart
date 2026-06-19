// Named params can't be private, so initializing formals don't apply to the
// repository constructor; suppress that suggestion file-wide.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'note_model.dart';

/// Storage abstraction for note/task [Item]s (Repository pattern).
///
/// Business logic depends on this interface, not on sqflite, so the backing
/// store can be swapped or faked in tests.
abstract class NotesRepository {
  /// All items, unordered.
  Future<List<Item>> getAll();

  /// Direct children of [parentId] (pass null for root items), ordered.
  Future<List<Item>> getChildren(String? parentId);

  Future<Item?> getById(String id);

  Future<void> add(Item item);

  Future<void> update(Item item);

  /// Deletes [id] and, via the self-referencing foreign key, its whole subtree.
  Future<void> delete(String id);
}

/// sqflite-backed [NotesRepository] using an adjacency-list table.
class SqfliteNotesRepository implements NotesRepository {
  // Named params can't be private (`this._x`), so initializing formals don't
  // apply here — assign in the initializer list instead.
  SqfliteNotesRepository({
    Database? database,
    String databaseName = 'minimatod.db',
  })  : _database = database,
        _databaseName = databaseName;

  static const _table = 'items';

  final String _databaseName;
  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  /// Bump this and add a branch in [_migrate] whenever the schema changes.
  static const _schemaVersion = 2;

  Future<Database> _open() async {
    // On web the database lives in IndexedDB and is opened by name only —
    // getDatabasesPath() is not supported by the web factory. On native we
    // resolve the platform databases directory.
    final dbPath =
        kIsWeb ? _databaseName : p.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      dbPath,
      version: _schemaVersion,
      // FK cascade is only a native backup — delete() already tombstones the
      // whole subtree itself. The web worker can't run this PRAGMA, so skip it.
      onConfigure: kIsWeb
          ? null
          : (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _migrate,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        is_done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (parent_id) REFERENCES $_table(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_items_parent ON $_table(parent_id)');
    await db.execute('CREATE INDEX idx_items_deleted ON $_table(deleted_at)');
  }

  /// Applies incremental migrations from [oldVersion] up to [newVersion].
  /// Each version's change is its own `if` block — additive, never destructive.
  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: soft-delete tombstone column + supporting index.
      await db.execute('ALTER TABLE $_table ADD COLUMN deleted_at TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_deleted ON $_table(deleted_at)',
      );
    }
  }

  @override
  Future<List<Item>> getAll() async {
    final db = await _db;
    final rows = await db.query(_table, where: 'deleted_at IS NULL');
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<List<Item>> getChildren(String? parentId) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: parentId == null
          ? 'parent_id IS NULL AND deleted_at IS NULL'
          : 'parent_id = ? AND deleted_at IS NULL',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sort_order ASC, created_at ASC',
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
}
