import 'package:flutter/material.dart';

/// Zola, the AI tutor: a friendly robot on a bright blue-to-violet circle with a white ring.
/// Drawn with an icon (not the robot emoji, which shows as a grey outline on some computers).
class ZolaAvatar extends StatelessWidget {
  final double size;
  const ZolaAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF38BDF8), Color(0xFF0077B6), Color(0xFF7C3AED)]),
        border: Border.all(color: Colors.white, width: size * 0.06),
        boxShadow: [BoxShadow(color: const Color(0xFF0077B6).withOpacity(0.35), blurRadius: size * 0.3, offset: Offset(0, size * 0.08))],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: size * 0.56),
    );
  }
}
