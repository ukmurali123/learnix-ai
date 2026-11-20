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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final List<_Bubble> _bubbles = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < 26; i++)
        _Bubble(r.nextDouble(), 10 + r.nextDouble() * 60, 0.6 + r.nextDouble() * 1.4, 10 + r.nextDouble() * 30, r.nextDouble()),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDDF0FA), Color(0xFFF1F8FD), Color(0xFFFFF4E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomPaint(painter: _BubblePainter(_c, _bubbles), size: Size.infinite),
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
      ..color = const Color(0xFF0077B6).withOpacity(0.10);
    final shine = Paint()..color = Colors.white.withOpacity(0.9);
    for (final b in bubbles) {
      // Each bubble rises from below the bottom edge to above the top edge, then starts again.
      final p = (t.value * b.speed + b.phase) % 1.0;
      final y = size.height + b.size - p * (size.height + b.size * 2);
      final x = b.x * size.width + math.sin((p * 6 + b.phase * 10) * math.pi) * b.sway;
      final c = Offset(x, y);
      final r = b.size / 2;
      fill.shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.45)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, rim);
      canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.18, shine);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => false;
}
