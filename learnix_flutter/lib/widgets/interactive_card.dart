import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            padding: widget.padding ?? EdgeInsets.all(tokens.space24),
            // Lifts 3 px on hover; thin border so the shadow does the work.
            transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? tokens.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? tokens.primary.withOpacity(0.25)
                    : (widget.borderColor ?? const Color(0xFFEEF2F6)),
                width: 1,
              ),
              boxShadow: _isHovered ? tokens.hoverShadow : tokens.cardShadow,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
