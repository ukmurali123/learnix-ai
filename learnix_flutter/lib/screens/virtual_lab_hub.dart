import 'package:flutter/material.dart';
import '../learnix_live/models_lab_screen.dart';
import '../learnix_live/robo_car_lab_screen.dart';
import 'virtual_lab_screen.dart';

/// Virtual Lab with two labs: the Circuit Lab (breadboard, Arduino circuits) and the Robo Car Lab (3D robot car).
class VirtualLabHub extends StatefulWidget {
  final String baseUrl;
  const VirtualLabHub({super.key, required this.baseUrl});
  @override
  State<VirtualLabHub> createState() => _VirtualLabHubState();
}

class _VirtualLabHubState extends State<VirtualLabHub> {
  int lab = 0;

  Widget _chip(int i, IconData icon, String label, Color color) {
    final on = lab == i;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => lab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? color : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: on ? color : const Color(0xFFE2E8F0)),
            boxShadow: on ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: on ? Colors.white : color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF0F172A))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip(0, Icons.cable_rounded, 'Circuit Lab', const Color(0xFF0077B6)),
              _chip(1, Icons.directions_car_filled_rounded, 'Robo Car Lab (3D)', const Color(0xFFE53935)),
              _chip(2, Icons.view_in_ar_rounded, '3D Working Models', const Color(0xFF7C3AED)),
            ]),
          ),
        ),
        Expanded(
          // Only the open lab is built (the 3D page is a web view that should not stay on screen behind the other lab).
          child: lab == 0
              ? VirtualLabScreen(key: const ValueKey('circuit'), baseUrl: widget.baseUrl)
              : lab == 1
                  ? Padding(
                      key: const ValueKey('robo'),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: RoboCarLabScreen(baseUrl: widget.baseUrl),
                    )
                  : Padding(
                      key: const ValueKey('models'),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: ModelsLabScreen(baseUrl: widget.baseUrl),
                    ),
        ),
      ]),
    );
  }
}
