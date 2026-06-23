// Named params can't be private (`this._x`), so initializing formals don't
// apply to this constructor; suppress that suggestion file-wide.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite database shared by every repository (items,
/// attachments, and future tables). Centralizes open/close, the schema version,
/// and the additive migration ladder, so each repository is just SQL against
/// [db] and never opens its own connection.
///
/// Migrations are additive and never destructive: bump [schemaVersion] and add
/// an `if (oldVersion < N)` block in [_migrate]. Fresh installs get the full
/// current shape from [_createSchema]; existing installs walk the ladder.
class AppDatabase {
  AppDatabase({Database? database, String databaseName = 'minimatod.db'})
    : _database = database,
      _databaseName = databaseName;

  /// Current schema version. v1–v7 shaped the `items` table; v8 added the
  /// out-of-row `attachments` metadata table; v9 added the `blobs` byte store
  /// (content-addressed binary data — never inline in an item row).
  static const schemaVersion = 9;

  static const _items = 'items';
  static const _attachments = 'attachments';

  final String _databaseName;
  Database? _database;

  /// The shared, lazily-opened database.
  Future<Database> get db async => _database ??= await _open();

  /// Closes the database (if open); it reopens on next [db] access. Used on app
  /// teardown and by tests, which open a fresh in-memory database per case.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _open() async {
    final String path;
    if (kIsWeb ||
        _databaseName == inMemoryDatabasePath ||
        p.isAbsolute(_databaseName)) {
      // Web opens by name (IndexedDB); in-memory / absolute paths are taken
      // as-is (tests and future build flavors). Otherwise resolve under the
      // platform databases directory.
      path = _databaseName;
    } else {
      path = p.join(await getDatabasesPath(), _databaseName);
    }
    return openDatabase(
      path,
      version: schemaVersion,
      // FK cascade is a native backup — repositories also tombstone subtrees
      // themselves. The web worker can't run this PRAGMA, so skip it there.
      onConfigure: kIsWeb
          ? null
          : (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _migrate,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_items (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        body TEXT,
        icon TEXT,
        color INTEGER,
        reminder_at TEXT,
        is_done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT,
        deleted_at TEXT,
        synced_at TEXT,
        FOREIGN KEY (parent_id) REFERENCES $_items(id) ON DELETE CASCADE
      )
    ''');
    // Composite covering index for the hot read — children of a parent,
    // filtered by active state and already in sibling order — one index range
    // scan, no temp sort. Subsumes a standalone parent_id index.
    await db.execute(
      'CREATE INDEX idx_items_children ON $_items'
      '(parent_id, archived_at, deleted_at, sort_order, created_at)',
    );
    await db.execute('CREATE INDEX idx_items_archived ON $_items(archived_at)');
    await db.execute('CREATE INDEX idx_items_synced ON $_items(synced_at)');

    await _createAttachments(db);
    await _createBlobs(db);
  }

  /// The out-of-row attachments table (schema v8). Blob bytes live on disk via
  /// the BlobStore, keyed by `content_hash`; this row is just the metadata and
  /// syncs like an item (per-row `synced_at` watermark + `deleted_at`
  /// tombstone). Cascades when its owning item is hard-deleted.
  Future<void> _createAttachments(Database db) async {
    await db.execute('''
      CREATE TABLE $_attachments (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        byte_size INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        synced_at TEXT,
        FOREIGN KEY (item_id) REFERENCES $_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attachments_item ON $_attachments(item_id, deleted_at)',
    );
    await db.execute(
      'CREATE INDEX idx_attachments_hash ON $_attachments(content_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_attachments_synced ON $_attachments(synced_at)',
    );
  }

  /// The content-addressed blob byte store (schema v9). Bytes keyed by sha-256
  /// hash, in their own table so they never load with the board — only fetched
  /// by hash on demand. Backs `SqliteBlobStore` (audio clips today, canvas
  /// bitmaps later); the same store works on native and web with no platform IO.
  Future<void> _createBlobs(Database db) async {
    await db.execute('''
      CREATE TABLE blobs (
        hash TEXT PRIMARY KEY,
        bytes BLOB NOT NULL,
        byte_size INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Applies incremental migrations from [oldVersion] up to [newVersion]. Each
  /// version's change is its own `if` block — additive, never destructive.
  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: soft-delete tombstone column + supporting index.
      await db.execute('ALTER TABLE $_items ADD COLUMN deleted_at TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_deleted ON $_items(deleted_at)',
      );
    }
    if (oldVersion < 3) {
      // v3: long-form note body.
      await db.execute('ALTER TABLE $_items ADD COLUMN body TEXT');
    }
    if (oldVersion < 4) {
      // v4: per-item icon, accent colour, and reminder time.
      await db.execute('ALTER TABLE $_items ADD COLUMN icon TEXT');
      await db.execute('ALTER TABLE $_items ADD COLUMN color INTEGER');
      await db.execute('ALTER TABLE $_items ADD COLUMN reminder_at TEXT');
    }
    if (oldVersion < 5) {
      // v5: reversible archive marker + supporting index.
      await db.execute('ALTER TABLE $_items ADD COLUMN archived_at TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_archived ON $_items(archived_at)',
      );
    }
    if (oldVersion < 6) {
      // v6: per-row sync watermark. Existing rows get NULL = "never synced", so
      // the first sync pushes the whole local board to the server.
      await db.execute('ALTER TABLE $_items ADD COLUMN synced_at TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_synced ON $_items(synced_at)',
      );
    }
    if (oldVersion < 7) {
      // v7: composite covering index for child reads — replaces the standalone
      // parent_id index and the low-cardinality deleted_at index.
      await db.execute('DROP INDEX IF EXISTS idx_items_parent');
      await db.execute('DROP INDEX IF EXISTS idx_items_deleted');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_children ON $_items'
        '(parent_id, archived_at, deleted_at, sort_order, created_at)',
      );
    }
    if (oldVersion < 8) {
      // v8: out-of-row attachments table (canvas/audio/image blobs).
      await _createAttachments(db);
    }
    if (oldVersion < 9) {
      // v9: content-addressed blob byte store for audio/canvas binaries.
      await _createBlobs(db);
    }
  }
}
