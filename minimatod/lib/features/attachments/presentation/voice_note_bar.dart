import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import 'audio_controller.dart';
import 'audio_widgets.dart';

/// A compact voice-note manager for an item's detail view: record one clip,
/// play / stop it with a live progress bar, or delete it. One clip per item —
/// recording again replaces it.
///
/// Operates live on [audio]: record/delete persist immediately (like the note
/// body autosave), so there's nothing to "save". Depends only on the
/// [AudioController] + an item id (no notes dependency).
class VoiceNoteBar extends StatelessWidget {
  const VoiceNoteBar({
    super.key,
    required this.audio,
    required this.itemId,
    required this.accent,
  });

  final AudioController audio;
  final String itemId;
  final Color accent;

  Future<void> _toggleRecord(BuildContext context) async {
    HapticFeedback.selectionClick();
    if (audio.isRecording) {
      final rec = await audio.stopRecording();
      if (rec != null) await audio.attach(itemId, rec);
    } else {
      final ok = await audio.startRecording();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).micPermissionNeeded),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final clip = audio.audioOf(itemId);
        final recording = audio.isRecording;

        // No clip yet → a single record affordance (or the recording state).
        if (clip == null) {
          return _RecordButton(
            label: recording ? l.recording : l.recordVoiceNote,
            recording: recording,
            accent: accent,
            onTap: () => _toggleRecord(context),
          );
        }

        // Has a clip → play / stop, label-or-progress, re-record, delete.
        final playing = audio.isPlaying(itemId);
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => audio.playFor(itemId),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: readableOnAccent(accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: playing
                    ? AudioProgressBar(
                        stream: audio.playbackStream,
                        accent: accent,
                      )
                    : Text(
                        l.voiceNote,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
              ),
              IconButton(
                tooltip: l.deleteVoiceNote,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: cs.error,
                ),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await audio.remove(itemId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The "record a voice note" pill shown when an item has no clip yet — flips to
/// a red "Recording…" state with a stop square while capturing.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.label,
    required this.recording,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool recording;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = recording ? cs.error : accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recording ? Icons.stop_rounded : Icons.mic_none_rounded,
              size: 19,
              color: tint,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
