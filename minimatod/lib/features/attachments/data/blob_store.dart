import 'dart:typed_data';

/// Out-of-row binary storage. Blob bytes (canvas drawings, audio clips, images)
/// live here — on disk natively — never inline in a database row. An
/// [Attachment] metadata row references a blob by its content hash.
///
/// Content-addressed: [write] returns the sha-256 hex of the bytes, which is
/// also the `Attachment.contentHash` and the future server's blob key, so the
/// same bytes are stored and transferred exactly once.
///
/// Get the platform implementation from `blob_store_factory.dart`
/// (`createBlobStore()`); test against an in-memory fake.
abstract class BlobStore {
  /// Whether a blob with [hash] exists locally.
  Future<bool> has(String hash);

  /// The bytes for [hash], or null if absent.
  Future<Uint8List?> read(String hash);

  /// Writes [bytes] and returns their content hash (the storage key). Writing
  /// the same bytes twice is idempotent.
  Future<String> write(Uint8List bytes);

  /// Deletes the blob for [hash] (no-op if absent). Call only once no live
  /// attachment references the hash — see
  /// `AttachmentsRepository.referencedHashes`.
  Future<void> delete(String hash);
}
