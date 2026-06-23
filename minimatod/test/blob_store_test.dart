import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimatod/features/attachments/data/blob_store_io.dart';
import 'package:minimatod/features/attachments/data/content_hash.dart';

/// Covers the native filesystem [FileBlobStore] against a throwaway temp
/// directory: content-addressed write/read/has/delete and dedup.
void main() {
  late Directory tempDir;
  late FileBlobStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimatod_blobs');
    store = FileBlobStore(directoryPath: tempDir.path);
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('write returns the content hash and read round-trips', () async {
    final data = bytes('hello canvas');
    final hash = await store.write(data);

    expect(hash, contentHashOf(data));
    expect(await store.has(hash), isTrue);
    expect(await store.read(hash), data);
  });

  test('identical bytes dedupe to one hash; different bytes differ', () async {
    final h1 = await store.write(bytes('same'));
    final h2 = await store.write(bytes('same'));
    final h3 = await store.write(bytes('other'));

    expect(h1, h2);
    expect(h1, isNot(h3));
  });

  test('read of an unknown hash is null; delete removes the blob', () async {
    expect(await store.read('deadbeef'), isNull);

    final h = await store.write(bytes('x'));
    await store.delete(h);
    expect(await store.has(h), isFalse);
  });
}
