import 'package:flutter/material.dart';

/// Shared voice-note UI bits, used by both the list row's mini-player and the
/// detail [VoiceNoteBar]. Kept here (in the attachments feature) so there's one
/// implementation and one look.

/// A slim playback progress bar + `elapsed / total` time, driven by the
/// controller's playback stream. Subscribes itself, so the ~5×/sec position
/// ticks rebuild only this widget — never the surrounding list.
class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({
    super.key,
    required this.stream,
    required this.accent,
  });

  final Stream<({Duration pos, Duration total})> stream;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<({Duration pos, Duration total})>(
      stream: stream,
      builder: (context, snap) {
        final pos = snap.data?.pos ?? Duration.zero;
        final total = snap.data?.total ?? Duration.zero;
        final value = total.inMilliseconds == 0
            ? 0.0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              '${formatClipTime(pos)} / ${formatClipTime(total)}',
              style: TextStyle(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `m:ss` for a short clip's elapsed / total time.
String formatClipTime(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A readable on-colour (white/black) for a filled accent button — the palette
/// accents vary in lightness, so pick by estimated brightness.
Color readableOnAccent(Color accent) {
  return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
      ? Colors.white
      : Colors.black;
}
