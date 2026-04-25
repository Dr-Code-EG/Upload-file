import 'package:flutter/material.dart';
import '../models/domino_tile.dart';

/// Realistic horizontal domino tile rendered with CustomPainter.
class DominoTileWidget extends StatelessWidget {
  final DominoTile tile;
  final double width;
  final double height;
  final bool faceDown;
  final bool highlight;
  final bool dimmed;

  const DominoTileWidget({
    super.key,
    required this.tile,
    this.width = 56,
    this.height = 28,
    this.faceDown = false,
    this.highlight = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _TilePainter(
            tile: tile,
            faceDown: faceDown,
            highlight: highlight,
            dark: isDark,
          ),
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  final DominoTile tile;
  final bool faceDown;
  final bool highlight;
  final bool dark;

  _TilePainter({
    required this.tile,
    required this.faceDown,
    required this.highlight,
    required this.dark,
  });

  static const _pipPositions = <int, List<Offset>>{
    0: [],
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ],
    6: [
      Offset(0.25, 0.2),
      Offset(0.75, 0.2),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.8),
      Offset(0.75, 0.8),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.18),
    );

    // Tile body — ivory gradient with subtle wood-like sheen.
    final bodyColor = faceDown
        ? (dark ? const Color(0xFF1B1B1B) : const Color(0xFF1E1E1E))
        : (dark ? const Color(0xFFEDE3D0) : const Color(0xFFFFF8E7));
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.5)), shadowPaint);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: faceDown
            ? [const Color(0xFF2A1A0A), const Color(0xFF120A04)]
            : [bodyColor, bodyColor.withOpacity(0.85)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(rrect, bodyPaint);

    // border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? 2.4 : 1.0
      ..color = highlight
          ? Colors.amber
          : (dark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.30));
    canvas.drawRRect(rrect, border);

    if (faceDown) {
      // Decorative back: small bordered rectangle.
      final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.16, w * 0.84, h * 0.68),
        Radius.circular(h * 0.1),
      );
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF6B3A14).withOpacity(0.8);
      canvas.drawRRect(inner, innerPaint);
      return;
    }

    // Center divider line.
    final dividerPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w / 2, h * 0.12), Offset(w / 2, h * 0.88), dividerPaint);

    // Pips: left half [0..0.5] in x, right half [0.5..1] in x.
    final pipPaint = Paint()..color = Colors.black87;
    final pipR = h * 0.085;

    void drawHalf(int v, double xOffset) {
      final positions = _pipPositions[v] ?? const [];
      for (final p in positions) {
        // x in [0,1] within half; map into actual half coords.
        final cx = xOffset + p.dx * (w * 0.5);
        final cy = p.dy * h;
        // soft shadow
        canvas.drawCircle(Offset(cx, cy + 0.4),
            pipR, Paint()..color = Colors.black.withOpacity(0.18));
        canvas.drawCircle(Offset(cx, cy), pipR, pipPaint);
        // highlight
        canvas.drawCircle(
          Offset(cx - pipR * 0.3, cy - pipR * 0.3),
          pipR * 0.35,
          Paint()..color = Colors.white.withOpacity(0.35),
        );
      }
    }

    drawHalf(tile.left, 0);
    drawHalf(tile.right, w * 0.5);
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) =>
      old.tile != tile ||
      old.faceDown != faceDown ||
      old.highlight != highlight ||
      old.dark != dark;
}

/// Vertical version (rotated 90°) — used in some layouts.
class DominoTileVertical extends StatelessWidget {
  final DominoTile tile;
  final double width;
  final double height;
  final bool faceDown;
  final bool highlight;
  const DominoTileVertical({
    super.key,
    required this.tile,
    this.width = 28,
    this.height = 56,
    this.faceDown = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1,
      child: DominoTileWidget(
        tile: tile,
        width: height,
        height: width,
        faceDown: faceDown,
        highlight: highlight,
      ),
    );
  }
}
