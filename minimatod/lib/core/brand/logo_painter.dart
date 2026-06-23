import 'package:flutter/material.dart';

import 'brand.dart';

/// Paints the original Minimatod mark: a bold "M" whose inner valley is a
/// checkmark (M + "done").
///
/// The geometry lives in a normalized 0..100 design space and is the single
/// source of truth — it is mirrored exactly in `assets/brand/web/logo.svg`.
class MinimatodLogoPainter extends CustomPainter {
  const MinimatodLogoPainter({
    required this.markColor,
    this.background,
    this.cornerRadiusFraction = 0.22,
    this.markFraction = 0.60,
    this.strokeDesignWidth = 12,
  });

  /// Color of the strokes.
  final Color markColor;

  /// Optional filled tile behind the mark (null = transparent).
  final Color? background;

  /// Tile corner radius as a fraction of the canvas (only used when [background]
  /// is set).
  final double cornerRadiusFraction;

  /// Fraction of the canvas the mark spans (centered).
  final double markFraction;

  /// Stroke width expressed in design (0..100) units.
  final double strokeDesignWidth;

  // --- Design coordinates (0..100), mirrored in logo.svg ---
  // M-check (the header) sits above two "list lines" (the note / to-do).
  static const double leftX = 28;
  static const double rightX = 72;
  static const double topY = 28;
  static const double botY = 72;
  static const double vertexX = 46; // checkmark low point
  static const double vertexY = 60;
  static const double tickX =
      68; // checkmark rising tip (pokes above shoulders)
  static const double tickY = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    if (background != null) {
      final rrect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(s * cornerRadiusFraction),
      );
      canvas.drawRRect(rrect, Paint()..color = background!);
    }

    final markSide = s * markFraction;
    final scale = markSide / 100.0;
    final dx = (size.width - markSide) / 2;
    final dy = (size.height - markSide) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final paint = Paint()
      ..color = markColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeDesignWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer legs of the M.
    canvas.drawLine(
      const Offset(leftX, topY),
      const Offset(leftX, botY),
      paint,
    );
    canvas.drawLine(
      const Offset(rightX, topY),
      const Offset(rightX, botY),
      paint,
    );

    // Inner valley = checkmark (descend into vertex, rise to the tick).
    final check = Path()
      ..moveTo(leftX, topY)
      ..lineTo(vertexX, vertexY)
      ..lineTo(tickX, tickY);
    canvas.drawPath(check, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MinimatodLogoPainter old) =>
      old.markColor != markColor ||
      old.background != background ||
      old.markFraction != markFraction ||
      old.cornerRadiusFraction != cornerRadiusFraction ||
      old.strokeDesignWidth != strokeDesignWidth;
}

/// Convenience widget for showing the logo in-app (e.g. an in-app splash).
class MinimatodLogo extends StatelessWidget {
  const MinimatodLogo({
    super.key,
    this.size = 96,
    this.markColor = Brand.paper,
    this.background,
    this.markFraction = 0.60,
    this.cornerRadiusFraction = 0.22,
  });

  final double size;
  final Color markColor;
  final Color? background;
  final double markFraction;
  final double cornerRadiusFraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MinimatodLogoPainter(
          markColor: markColor,
          background: background,
          markFraction: markFraction,
          cornerRadiusFraction: cornerRadiusFraction,
        ),
      ),
    );
  }
}
