import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Content hash for a blob — the BlobStore key and the `Attachment.contentHash`.
///
/// sha-256 hex, so it's stable across devices and platforms: the same bytes
/// always map to the same key, which gives local/remote dedup and integrity and
/// lets the future server store/transfer each distinct blob exactly once.
String contentHashOf(Uint8List bytes) => sha256.convert(bytes).toString();
