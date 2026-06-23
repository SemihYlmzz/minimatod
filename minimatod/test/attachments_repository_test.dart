import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/core/database/app_database.dart';
import 'package:minimatod/features/attachments/data/attachment_model.dart';
import 'package:minimatod/features/attachments/data/attachments_repository.dart';
import 'package:minimatod/features/notes/data/note_model.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Covers the attachments metadata table on the shared [AppDatabase] (real
/// SQLite via FFI): CRUD, tombstone hiding, the FK cascade from items, and the
/// referenced-hash set used for blob GC.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDb;
  late SqfliteNotesRepository notes;
  late SqfliteAttachmentsRepository attachments;

  setUp(() {
    appDb = AppDatabase(databaseName: inMemoryDatabasePath);
    notes = SqfliteNotesRepository(appDb);
    attachments = SqfliteAttachmentsRepository(appDb);
  });
  tearDown(() => appDb.close());

  final t0 = DateTime.utc(2026, 1, 1);

  Future<void> addItem(String id) => notes.add(
    Item(
      id: id,
      type: ItemType.note,
      content: 'c-$id',
      createdAt: t0,
      updatedAt: t0,
    ),
  );

  Attachment att(String id, String itemId, {String hash = 'h'}) => Attachment(
    id: id,
    itemId: itemId,
    kind: AttachmentKind.image,
    contentHash: hash,
    mimeType: 'image/png',
    byteSize: 10,
    createdAt: t0,
    updatedAt: t0,
  );

  test('add + getForItem returns live attachments', () async {
    await addItem('i1');
    await attachments.add(att('a1', 'i1'));
    await attachments.add(att('a2', 'i1', hash: 'h2'));

    final list = await attachments.getForItem('i1');
    expect(list.map((a) => a.id).toSet(), {'a1', 'a2'});
  });

  test('round-trips kind, hash, mime, and size', () async {
    await addItem('i1');
    await attachments.add(
      att('a1', 'i1', hash: 'abc123').copyWith(byteSize: 4096),
    );

    final got = await attachments.getById('a1');
    expect(got!.kind, AttachmentKind.image);
    expect(got.contentHash, 'abc123');
    expect(got.mimeType, 'image/png');
    expect(got.byteSize, 4096);
  });

  test('delete tombstones (hidden from reads)', () async {
    await addItem('i1');
    await attachments.add(att('a1', 'i1'));

    await attachments.delete('a1');

    expect(await attachments.getById('a1'), isNull);
    expect(await attachments.getForItem('i1'), isEmpty);
  });

  test('hard-deleting the owning item cascades its attachment rows', () async {
    await addItem('i1');
    await attachments.add(att('a1', 'i1'));

    // The app soft-deletes items, but a hard delete must not orphan attachment
    // rows — verify the schema-level FK cascade (foreign_keys is ON natively).
    final raw = await appDb.db;
    await raw.delete('items', where: 'id = ?', whereArgs: ['i1']);

    expect(await attachments.getById('a1'), isNull);
  });

  test('referencedHashes lists distinct live hashes only', () async {
    await addItem('i1');
    await attachments.add(att('a1', 'i1', hash: 'h1'));
    await attachments.add(att('a2', 'i1', hash: 'h1')); // duplicate hash
    await attachments.add(att('a3', 'i1', hash: 'h2'));
    await attachments.delete('a3'); // h2 no longer referenced

    expect(await attachments.referencedHashes(), {'h1'});
  });
}
