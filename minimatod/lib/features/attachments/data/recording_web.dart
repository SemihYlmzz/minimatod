import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: `record` ignores the path and records to an in-memory blob, so this is
/// just a label.
Future<String> tempRecordingPath() async => 'recording.webm';

/// Web: `record`'s stop() returns a `blob:` URL — fetch its bytes, then release
/// the object URL (the bytes now live in the BlobStore).
Future<Uint8List> loadRecordingBytes(String url) async {
  final response = await web.window.fetch(url.toJS).toDart;
  final buffer = await response.arrayBuffer().toDart;
  web.URL.revokeObjectURL(url);
  return buffer.toDart.asUint8List();
}

/// Web never plays via a temp file — the browser plays the bytes in-memory
/// (`StreamAudioSource`). Present only to satisfy the conditional-export seam.
Future<String> writePlayableTempFile(
  String hash,
  Uint8List bytes,
  String mimeType,
) async => throw UnsupportedError('writePlayableTempFile is native-only');
