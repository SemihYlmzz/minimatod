import 'dart:typed_data';

import 'blob_store.dart';

/// Creates the platform [BlobStore]. Web persistence (OPFS/IndexedDB) isn't
/// implemented yet — attachments are native-first. This stub reads as "empty"
/// and fails loudly on write, so a web build can never silently lose blob data.
/// Wire OPFS here when canvas/audio ship on web.
BlobStore createBlobStore() => const _UnsupportedBlobStore();

class _UnsupportedBlobStore implements BlobStore {
  const _UnsupportedBlobStore();

  @override
  Future<bool> has(String hash) async => false;

  @override
  Future<Uint8List?> read(String hash) async => null;

  @override
  Future<String> write(Uint8List bytes) => throw UnsupportedError(
    'Blob attachments are not supported on web yet. '
    'Implement OPFS/IndexedDB storage in blob_store_web.dart.',
  );

  @override
  Future<void> delete(String hash) async {}
}
