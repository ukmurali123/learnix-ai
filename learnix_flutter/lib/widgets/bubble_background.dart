import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Soft brand-tinted background with white bubbles that slowly float upwards.
/// Put it behind a screen whose own background is transparent.
class BubbleBackground extends StatefulWidget {
  final Widget child;
  const BubbleBackground({super.key, required this.child});
  @override
  State<BubbleBackground> createState() => _BubbleBackgroundState();
}

class _Bubble {
  final double x, size, speed, sway, phase;
  const _Bubble(this.x, this.size, this.speed, this.sway, this.phase);
}

class _BubbleBackgroundState extends State<BubbleBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90));
  late final List<_Bubble> _bubbles = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < 18; i++)
        _Bubble(r.nextDouble(), 8 + r.nextDouble() * 44, 0.5 + r.nextDouble() * 1.0, 8 + r.nextDouble() * 22, r.nextDouble()),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              // Bubbles turned off (plain white page). To bring them back, use bubble_background.dart.with-bubbles.
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
      Positioned.fill(child: widget.child),
    ]);
  }
}

class _BubblePainter extends CustomPainter {
  final Animation<double> t;
  final List<_Bubble> bubbles;
  _BubblePainter(this.t, this.bubbles) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fill = Paint()..style = PaintingStyle.fill;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF94A3B8).withOpacity(0.35);
    final shine = Paint()..color = const Color(0xFFE2E8F0);
    final shadow = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final b in bubbles) {
      // Each bubble rises from below the bottom edge to above the top edge, then starts again.
      final p = (t.value * b.speed + b.phase) % 1.0;
      final y = size.height + b.size - p * (size.height + b.size * 2);
      final x = b.x * size.width + math.sin((p * 6 + b.phase * 10) * math.pi) * b.sway;
      final c = Offset(x, y);
      final r = b.size / 2;
      fill.shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [Colors.white, Colors.white.withOpacity(0.92)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c + Offset(0, r * 0.12), r, shadow);
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, rim);
      canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.18, shine);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => false;
}
