import 'dart:io';
import 'dart:typed_data';

/// Native: a temp file path for `record` to write the clip to.
Future<String> tempRecordingPath() async {
  final dir = Directory.systemTemp;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  return '${dir.path}/minimatod_rec_$stamp.m4a';
}

/// Native: read the recorded file's bytes, then delete the temp file (the bytes
/// now live in the content-addressed BlobStore).
Future<Uint8List> loadRecordingBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return Uint8List(0);
  final bytes = await file.readAsBytes();
  try {
    await file.delete();
  } catch (_) {
    // Best-effort cleanup; a leftover temp file is harmless.
  }
  return bytes;
}

/// Native: materialize blob bytes to a temp file so just_audio can play them by
/// path. iOS's AVPlayer plays a file/url reliably but is flaky with just_audio's
/// in-memory `StreamAudioSource`, so we always go through a file on native.
///
/// Named by content [hash] (+ a format-correct extension) so replaying the same
/// clip reuses one file instead of accumulating one per play.
Future<String> writePlayableTempFile(
  String hash,
  Uint8List bytes,
  String mimeType,
) async {
  final ext = mimeType.contains('webm')
      ? 'webm'
      : (mimeType.contains('mpeg') ? 'mp3' : 'm4a');
  final file = File('${Directory.systemTemp.path}/minimatod_play_$hash.$ext');
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file.path;
}
