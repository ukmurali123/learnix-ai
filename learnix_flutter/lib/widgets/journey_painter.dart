import 'package:flutter/material.dart';

class JourneyLinePainter extends CustomPainter {
  final int totalCount;
  final int completedCount;
  final Color activeColor;
  final Color inactiveColor;

  JourneyLinePainter({
    required this.totalCount,
    required this.completedCount,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalCount <= 1) return;

    final paintInactive = Paint()
      ..color = inactiveColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintActive = Paint()
      ..color = activeColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw vertical or curved line down the spine
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width / 2, size.height);

    canvas.drawPath(path, paintInactive);

    if (completedCount > 0) {
      final activeRatio = (completedCount / totalCount).clamp(0.0, 1.0);
      final activePath = Path();
      activePath.moveTo(size.width / 2, 0);
      activePath.lineTo(size.width / 2, size.height * activeRatio);
      canvas.drawPath(activePath, paintActive);
    }
  }

  @override
  bool shouldRepaint(covariant JourneyLinePainter oldDelegate) {
    return oldDelegate.completedCount != completedCount ||
        oldDelegate.totalCount != totalCount ||
        oldDelegate.activeColor != activeColor;
  }
}
