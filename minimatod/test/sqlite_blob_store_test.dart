import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/core/database/app_database.dart';
import 'package:minimatod/features/attachments/data/content_hash.dart';
import 'package:minimatod/features/attachments/data/sqlite_blob_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The cross-platform blob store backed by the `blobs` table (schema v9), via
/// real SQLite (FFI). The same code path runs on native and web.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  SqliteBlobStore newStore() {
    final db = AppDatabase(databaseName: inMemoryDatabasePath);
    addTearDown(db.close);
    return SqliteBlobStore(db);
  }

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('write returns the content hash and read round-trips', () async {
    final store = newStore();
    final data = bytes('hello audio clip');

    final hash = await store.write(data);

    expect(hash, contentHashOf(data));
    expect(await store.has(hash), isTrue);
    expect(await store.read(hash), data);
  });

  test('identical bytes dedupe to one row; different bytes differ', () async {
    final store = newStore();
    final h1 = await store.write(bytes('same'));
    final h2 = await store.write(bytes('same'));
    final h3 = await store.write(bytes('other'));

    expect(h1, h2);
    expect(h1, isNot(h3));
  });

  test('read of an unknown hash is null; delete removes the blob', () async {
    final store = newStore();
    expect(await store.read('deadbeef'), isNull);

    final h = await store.write(bytes('x'));
    await store.delete(h);
    expect(await store.has(h), isFalse);
    expect(await store.read(h), isNull);
  });
}
