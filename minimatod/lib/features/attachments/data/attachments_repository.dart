import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'attachment_model.dart';

/// Storage for [Attachment] metadata rows (Repository pattern). The blob bytes
/// live in the BlobStore; this only persists the rows. Soft-deletes (tombstone)
/// so deletions can sync, matching [NotesRepository].
abstract class AttachmentsRepository {
  /// Live (not deleted) attachments for [itemId], oldest first.
  Future<List<Attachment>> getForItem(String itemId);

  /// Every live (not deleted) attachment — used to build in-memory indexes.
  Future<List<Attachment>> getAll();

  Future<Attachment?> getById(String id);

  Future<void> add(Attachment attachment);

  Future<void> update(Attachment attachment);

  /// Soft-deletes one attachment (tombstone — the row stays for sync).
  Future<void> delete(String id);

  /// Content hashes still referenced by at least one live attachment — the set
  /// the BlobStore must keep. Any on-disk blob whose hash isn't here is
  /// garbage-collectable.
  Future<Set<String>> referencedHashes();
}

/// sqflite-backed [AttachmentsRepository] over the shared [AppDatabase].
class SqfliteAttachmentsRepository implements AttachmentsRepository {
  SqfliteAttachmentsRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'attachments';

  Future<Database> get _db => _appDb.db;

  @override
  Future<List<Attachment>> getForItem(String itemId) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'item_id = ? AND deleted_at IS NULL',
      whereArgs: [itemId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  @override
  Future<List<Attachment>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  @override
  Future<Attachment?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Attachment.fromMap(rows.first);
  }

  @override
  Future<void> add(Attachment attachment) async {
    final db = await _db;
    await db.insert(
      _table,
      attachment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Attachment attachment) async {
    final db = await _db;
    await db.update(
      _table,
      attachment.toMap(),
      where: 'id = ?',
      whereArgs: [attachment.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      _table,
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Set<String>> referencedHashes() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      columns: ['content_hash'],
      where: 'deleted_at IS NULL',
      distinct: true,
    );
    return rows.map((r) => r['content_hash']! as String).toSet();
  }
}
