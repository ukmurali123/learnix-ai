import 'package:flutter/material.dart';

/// Illustrated card in the style of the live Learnix lab cards: a picture on top with a
/// coloured status pill, then the title, a coloured subtitle and an arrow. Lifts on hover.
class PictureCard extends StatefulWidget {
  final String image; // asset path
  final String title;
  final String subtitle;
  final Color color;
  final String badge;
  final VoidCallback? onTap;
  const PictureCard({super.key, required this.image, required this.title, required this.subtitle, required this.color, this.badge = 'Open', this.onTap});
  @override
  State<PictureCard> createState() => _PictureCardState();
}

class _PictureCardState extends State<PictureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(_hover ? 0.22 : 0.14), blurRadius: _hover ? 28 : 20, spreadRadius: _hover ? 1 : 0, offset: Offset(0, _hover ? 14 : 9)),
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(
                      color: c.withOpacity(0.08),
                      child: Image.asset(widget.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image_outlined, size: 56, color: c))),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
                        child: Text(widget.badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87))),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: c),
                    ]),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
