import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'blob_store.dart';
import 'content_hash.dart';

/// Creates the platform [BlobStore]. Native: a filesystem store under an
/// `attachments/` directory co-located with the SQLite database (no extra path
/// dependency).
BlobStore createBlobStore() => FileBlobStore();

/// Filesystem-backed [BlobStore] — one file per blob, named by content hash, in
/// a single directory. Content addressing means a file is written at most once.
class FileBlobStore implements BlobStore {
  FileBlobStore({String? directoryPath}) : _override = directoryPath;

  final String? _override;
  Directory? _dir;

  Future<Directory> get _directory async {
    if (_dir != null) return _dir!;
    final base = _override ?? p.join(await getDatabasesPath(), 'attachments');
    final dir = Directory(base);
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<File> _file(String hash) async =>
      File(p.join((await _directory).path, hash));

  @override
  Future<bool> has(String hash) => _file(hash).then((f) => f.exists());

  @override
  Future<Uint8List?> read(String hash) async {
    final file = await _file(hash);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<String> write(Uint8List bytes) async {
    final hash = contentHashOf(bytes);
    final file = await _file(hash);
    // Content-addressed: identical bytes => identical file, so a re-write is a
    // no-op (skip the IO when it already exists).
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return hash;
  }

  @override
  Future<void> delete(String hash) async {
    final file = await _file(hash);
    if (await file.exists()) await file.delete();
  }
}
