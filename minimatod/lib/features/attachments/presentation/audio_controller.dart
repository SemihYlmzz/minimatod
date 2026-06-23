// Named params can't be private (`this._x`), so initializing formals don't
// apply to this constructor. just_audio's StreamAudioSource is marked
// experimental but is the supported way to stream in-memory bytes to the player.
// ignore_for_file: prefer_initializing_formals, experimental_member_use
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../data/attachment_model.dart';
import '../data/attachments_repository.dart';
import '../data/blob_store.dart';
import '../data/recording.dart';

/// A recorded clip that's been stored in the [BlobStore] but not yet attached to
/// an item — produced by the create sheet (which records before the item
/// exists), then handed to [AudioController.attach] once the item is created.
class PendingRecording {
  const PendingRecording({
    required this.hash,
    required this.mimeType,
    required this.byteSize,
  });

  final String hash;
  final String mimeType;
  final int byteSize;
}

/// Records voice-note clips from the mic, attaches them to items, and plays them
/// back. Owns its own recorder/player and persists clips out-of-row: bytes →
/// [BlobStore] (by hash), metadata → [AttachmentsRepository]. Knows nothing about
/// notes — it works on plain item ids.
///
/// Keeps an in-memory `itemId → audio attachment` index ([audioOf]) so the lists
/// can show a play affordance without a per-row query. One voice note per item
/// for now (re-recording replaces).
class AudioController extends ChangeNotifier {
  AudioController({
    required AttachmentsRepository attachments,
    required BlobStore blobs,
    Uuid? uuid,
  }) : _attachments = attachments,
       _blobs = blobs,
       _uuid = uuid ?? const Uuid() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playingKey = null;
        notifyListeners();
      }
    });
  }

  final AttachmentsRepository _attachments;
  final BlobStore _blobs;
  final Uuid _uuid;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  /// itemId → its audio attachment (the index that drives the row play icon).
  final Map<String, Attachment> _audioByItem = {};

  bool _recording = false;
  bool get isRecording => _recording;

  /// Mime type of the in-progress recording, chosen by [_pickEncoder] to match
  /// what the platform's recorder actually supports. Carried into the stored
  /// clip so playback uses the right content type.
  String _mime = 'audio/aac';

  /// Key of the clip currently playing (null when stopped): an attachment id
  /// for an attached clip, or a content hash for a not-yet-attached pending one.
  String? _playingKey;

  /// Position + total duration of the currently-playing clip, ~5×/sec. Drives
  /// the playing row's progress bar. Only that one row subscribes (its
  /// `StreamBuilder` mounts only while playing), so non-playing rows cost
  /// nothing and the list itself never rebuilds per tick.
  late final Stream<({Duration pos, Duration total})> playbackStream = _player
      .positionStream
      .map((pos) => (pos: pos, total: _player.duration ?? Duration.zero));

  /// Loads the audio-attachment index. Call once at startup, after the DB is up.
  Future<void> load() async {
    _audioByItem.clear();
    for (final a in await _attachments.getAll()) {
      if (a.kind == AttachmentKind.audio) {
        _audioByItem.putIfAbsent(a.itemId, () => a);
      }
    }
    notifyListeners();
  }

  /// The item's audio attachment, or null. O(1) — drives the row play icon.
  Attachment? audioOf(String itemId) => _audioByItem[itemId];

  /// Whether the item's audio is the one currently playing.
  bool isPlaying(String itemId) {
    final a = _audioByItem[itemId];
    return a != null && _playingKey == a.id;
  }

  /// Whether a not-yet-attached pending clip is the one currently playing.
  bool isPlayingPending(PendingRecording rec) => _playingKey == rec.hash;

  /// Whether the mic is available/permitted — prompts on first ask.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts a recording (not yet tied to any item). False if denied, busy, or
  /// no codec works — never throws, so a failure surfaces as a snackbar instead
  /// of a silent dead button.
  Future<bool> startRecording() async {
    if (_recording) return false;
    try {
      // Native: hasPermission() asks the OS for the mic up front (and prompts).
      if (!kIsWeb) {
        if (!await _recorder.hasPermission()) return false;
        _mime = 'audio/aac';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: await tempRecordingPath(),
        );
        _recording = true;
        notifyListeners();
        return true;
      }

      // Web: don't pre-check codec support (isEncoderSupported is unreliable —
      // it threw even for opus on Chrome). Just try start() directly: it runs
      // getUserMedia (the real browser prompt) and throws only if the codec
      // itself is unsupported, so try a few in order. opus is smallest
      // (Chrome/Firefox); WAV records via the Web-Audio PCM path and works on
      // every browser including Safari, so it's the guaranteed fallback. The
      // browser shows the mic prompt only once, so retries after Allow don't
      // re-prompt.
      const attempts = <(AudioEncoder, String)>[
        (AudioEncoder.opus, 'audio/webm'),
        (AudioEncoder.aacLc, 'audio/mp4'),
        (AudioEncoder.wav, 'audio/wav'),
      ];
      for (final a in attempts) {
        try {
          await _recorder.start(
            RecordConfig(encoder: a.$1),
            path: await tempRecordingPath(),
          );
          _mime = a.$2;
          _recording = true;
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('Minimatod: web encoder ${a.$1} failed: $e');
          try {
            await _recorder.cancel();
          } catch (_) {}
        }
      }
      return false;
    } catch (e) {
      debugPrint('Minimatod: startRecording failed: $e');
      _recording = false;
      return false;
    }
  }

  /// Stops recording and stores the clip in the BlobStore, returning a handle to
  /// attach once the item exists. Null if nothing was captured.
  Future<PendingRecording?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    notifyListeners();

    final result = await _recorder.stop();
    if (result == null) return null;
    final bytes = await loadRecordingBytes(result);
    if (bytes.isEmpty) return null;

    final hash = await _blobs.write(bytes);
    return PendingRecording(
      hash: hash,
      mimeType: _mime,
      byteSize: bytes.length,
    );
  }

  /// Aborts the current recording without storing it.
  Future<void> cancelRecording() async {
    if (!_recording) return;
    _recording = false;
    notifyListeners();
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  /// Attaches [rec] to [itemId], replacing any existing voice note on it.
  Future<void> attach(String itemId, PendingRecording rec) async {
    final old = _audioByItem[itemId];
    if (old != null) await _attachments.delete(old.id);

    final now = DateTime.now();
    final attachment = Attachment(
      id: _uuid.v4(),
      itemId: itemId,
      kind: AttachmentKind.audio,
      contentHash: rec.hash,
      mimeType: rec.mimeType,
      byteSize: rec.byteSize,
      createdAt: now,
      updatedAt: now,
    );
    await _attachments.add(attachment);
    _audioByItem[itemId] = attachment;

    // GC the replaced blob if nothing else references it.
    if (old != null && old.contentHash != rec.hash) {
      final referenced = await _attachments.referencedHashes();
      if (!referenced.contains(old.contentHash)) {
        await _blobs.delete(old.contentHash);
      }
    }
    notifyListeners();
  }

  /// Plays the item's audio, or stops it if it's already the one playing.
  Future<void> playFor(String itemId) async {
    final a = _audioByItem[itemId];
    if (a == null) return;
    await _togglePlay(a.id, a.contentHash, a.mimeType);
  }

  /// Plays a not-yet-attached pending clip (the create-sheet preview), or stops
  /// it if it's already playing.
  Future<void> playPending(PendingRecording rec) =>
      _togglePlay(rec.hash, rec.hash, rec.mimeType);

  /// Plays the blob [hash] under [key] (an attachment id or a pending hash), or
  /// stops if [key] is already playing.
  Future<void> _togglePlay(String key, String hash, String mimeType) async {
    if (_playingKey == key) {
      await stopPlaying();
      return;
    }
    final bytes = await _blobs.read(hash);
    if (bytes == null) return;
    try {
      // iOS/Android play a file by path reliably; just_audio's in-memory
      // StreamAudioSource is flaky on iOS (AVPlayer silently fails to decode the
      // m4a container served over its proxy). Web has no filesystem, so there we
      // stream the bytes — which the browser's <audio> element handles fine.
      if (kIsWeb) {
        await _player.setAudioSource(_BytesAudioSource(bytes, mimeType));
      } else {
        final path = await writePlayableTempFile(hash, bytes, mimeType);
        await _player.setFilePath(path);
      }
      _playingKey = key;
      notifyListeners();
      await _player.play();
    } catch (e) {
      debugPrint('Minimatod: audio playback failed: $e');
      _playingKey = null;
      notifyListeners();
    }
  }

  Future<void> stopPlaying() async {
    await _player.stop();
    _playingKey = null;
    notifyListeners();
  }

  /// Removes the item's voice note: stops it if playing, soft-deletes the
  /// metadata row (tombstone for sync), drops it from the index, and GCs the
  /// blob if nothing else references it.
  Future<void> remove(String itemId) async {
    final a = _audioByItem.remove(itemId);
    if (a == null) return;
    if (_playingKey == a.id) await stopPlaying();
    await _attachments.delete(a.id);
    final referenced = await _attachments.referencedHashes();
    if (!referenced.contains(a.contentHash)) {
      await _blobs.delete(a.contentHash);
    }
    notifyListeners();
  }

  /// Discards a pending clip the user recorded but didn't keep (deleted it in
  /// the composer, re-recorded over it, or dismissed the sheet) — GCs its blob
  /// if no attachment references it. No-op if it ended up attached.
  Future<void> discardPending(PendingRecording rec) async {
    if (_playingKey == rec.hash) await stopPlaying();
    final referenced = await _attachments.referencedHashes();
    if (!referenced.contains(rec.hash)) {
      await _blobs.delete(rec.hash);
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}

/// Feeds in-memory bytes to just_audio, uniformly on native and web.
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes, this._contentType);

  final Uint8List _bytes;
  final String _contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _contentType,
    );
  }
}
