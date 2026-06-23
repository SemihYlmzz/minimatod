import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'blob_store.dart';
import 'content_hash.dart';

/// A [BlobStore] backed by a dedicated `blobs` table in the shared
/// [AppDatabase].
///
/// Content-addressed (sha-256) and **identical on native and web** — no
/// platform-specific file IO or browser-storage interop, which makes it the
/// reliable cross-platform choice. Blobs live in their own table, so they never
/// load with the board; they're fetched by hash only on demand.
class SqliteBlobStore implements BlobStore {
  SqliteBlobStore(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'blobs';

  Future<Database> get _db => _appDb.db;

  @override
  Future<bool> has(String hash) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      columns: const ['hash'],
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<Uint8List?> read(String hash) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      columns: const ['bytes'],
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final stored = rows.first['bytes'];
    if (stored is Uint8List) return stored;
    if (stored is List<int>) return Uint8List.fromList(stored);
    return null;
  }

  @override
  Future<String> write(Uint8List bytes) async {
    final hash = contentHashOf(bytes);
    final db = await _db;
    // Content-addressed: identical bytes → same row, so re-writes are no-ops.
    await db.insert(_table, {
      'hash': hash,
      'bytes': bytes,
      'byte_size': bytes.length,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return hash;
  }

  @override
  Future<void> delete(String hash) async {
    final db = await _db;
    await db.delete(_table, where: 'hash = ?', whereArgs: [hash]);
  }
}
