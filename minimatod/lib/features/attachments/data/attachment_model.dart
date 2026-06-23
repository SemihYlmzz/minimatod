/// The kind of binary an [Attachment] holds — drives how the bytes are
/// interpreted/rendered. Stored as a stable string so it survives sync and
/// future additions.
enum AttachmentKind { image, audio, canvas, file }

/// Metadata for one out-of-row binary attached to an `Item` (a canvas drawing,
/// an audio clip, an image, …).
///
/// The bytes themselves never live here or in the items table — they sit on
/// disk via the BlobStore, addressed by [contentHash]. This row is the syncable
/// record: it carries the same `updatedAt`/`syncedAt` watermark and `deletedAt`
/// tombstone as `Item`, so it rides the same last-write-wins sync, while the
/// blob transfers separately (hash-keyed upload/download) so large media never
/// bloats a row payload. Immutable — derive copies with [copyWith].
class Attachment {
  const Attachment({
    required this.id,
    required this.itemId,
    required this.kind,
    required this.contentHash,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
    this.byteSize = 0,
    this.deletedAt,
    this.syncedAt,
  });

  /// Stable unique identifier (UUID).
  final String id;

  /// The owning item. Attachments cascade when their item is hard-deleted.
  final String itemId;

  final AttachmentKind kind;

  /// Content hash (sha-256 hex) of the bytes — the BlobStore key. Content
  /// addressing gives dedup, integrity, and a stable cross-device sync key.
  final String contentHash;

  final String mimeType;

  /// Size of the blob in bytes (for quotas/UI; the source of truth is the blob).
  final int byteSize;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete tombstone — propagates the deletion via sync and marks the
  /// blob eligible for GC once no live attachment references its hash.
  final DateTime? deletedAt;

  /// Sync watermark — see `Item.syncedAt`. Null or older than [updatedAt] means
  /// the row is dirty (pending push).
  final DateTime? syncedAt;

  bool get isDeleted => deletedAt != null;

  bool get isDirty => syncedAt == null || syncedAt!.isBefore(updatedAt);

  Attachment copyWith({
    String? id,
    String? itemId,
    AttachmentKind? kind,
    String? contentHash,
    String? mimeType,
    int? byteSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
    Object? syncedAt = _sentinel,
  }) {
    return Attachment(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      contentHash: contentHash ?? this.contentHash,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      syncedAt: syncedAt == _sentinel ? this.syncedAt : syncedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'item_id': itemId,
    'kind': kind.name,
    'content_hash': contentHash,
    'mime_type': mimeType,
    'byte_size': byteSize,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'synced_at': syncedAt?.toIso8601String(),
  };

  factory Attachment.fromMap(Map<String, Object?> map) => Attachment(
    id: map['id']! as String,
    itemId: map['item_id']! as String,
    kind: AttachmentKind.values.byName(map['kind']! as String),
    contentHash: map['content_hash']! as String,
    mimeType: map['mime_type']! as String,
    byteSize: map['byte_size']! as int,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    deletedAt: map['deleted_at'] == null
        ? null
        : DateTime.parse(map['deleted_at']! as String),
    syncedAt: map['synced_at'] == null
        ? null
        : DateTime.parse(map['synced_at']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.id == id &&
      other.itemId == itemId &&
      other.kind == kind &&
      other.contentHash == contentHash &&
      other.mimeType == mimeType &&
      other.byteSize == byteSize &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    kind,
    contentHash,
    mimeType,
    byteSize,
    createdAt,
    updatedAt,
    deletedAt,
    syncedAt,
  );
}

/// Sentinel for [Attachment.copyWith] to tell "leave unchanged" from "set null".
const Object _sentinel = Object();
