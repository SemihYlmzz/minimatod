/// The kind of an [Item]: a free-form note or a checkable task.
enum ItemType { note, task }

/// A single note or task in the tree.
///
/// Items form an arbitrarily deep tree via the adjacency-list pattern: every
/// item stores its [parentId] (null for a root item). The class is immutable —
/// use [copyWith] to derive a changed copy instead of mutating in place.
class Item {
  const Item({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.body,
    this.isDone = false,
    this.sortOrder = 0,
    this.deletedAt,
  });

  /// Stable unique identifier (UUID).
  final String id;

  /// Id of the parent item, or null when this is a root item.
  final String? parentId;

  /// Whether this item is a note or a task.
  final ItemType type;

  /// The title/text of the note/task (single line, shown in lists).
  final String content;

  /// The long-form note body (the document shown on the Note page). Null/empty
  /// when there's no body. Plain text/markdown for now; will evolve into a
  /// structured rich-text format for the advanced editor — an additive change
  /// that won't affect the rest of the schema.
  final String? body;

  /// Completion flag. Only meaningful when [type] is [ItemType.task].
  final bool isDone;

  /// Position among siblings sharing the same [parentId] (ascending).
  final int sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete tombstone. Null means the item is active. Kept (not physically
  /// removed) so future cloud sync can propagate deletions across devices.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Item copyWith({
    String? id,
    Object? parentId = _sentinel,
    ItemType? type,
    String? content,
    Object? body = _sentinel,
    bool? isDone,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return Item(
      id: id ?? this.id,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      type: type ?? this.type,
      content: content ?? this.content,
      body: body == _sentinel ? this.body : body as String?,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
    );
  }

  /// Serializes to a row map for sqflite.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'type': type.name,
      'content': content,
      'body': body,
      'is_done': isDone ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  /// Rebuilds an [Item] from a sqflite row map.
  factory Item.fromMap(Map<String, Object?> map) {
    return Item(
      id: map['id']! as String,
      parentId: map['parent_id'] as String?,
      type: ItemType.values.byName(map['type']! as String),
      content: map['content']! as String,
      body: map['body'] as String?,
      isDone: (map['is_done']! as int) != 0,
      sortOrder: map['sort_order']! as int,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at']! as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Item &&
        other.id == id &&
        other.parentId == parentId &&
        other.type == type &&
        other.content == content &&
        other.body == body &&
        other.isDone == isDone &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        parentId,
        type,
        content,
        body,
        isDone,
        sortOrder,
        createdAt,
        updatedAt,
        deletedAt,
      );
}

/// Sentinel used by [Item.copyWith] to distinguish "leave parentId unchanged"
/// from "set parentId to null".
const Object _sentinel = Object();
