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
          scale: _isPressed ? 0.98 : (_isHovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            padding: widget.padding ?? EdgeInsets.all(tokens.space24),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? tokens.cardBg,
              borderRadius: tokens.borderRadius16,
              border: Border.all(
                color: _isHovered
                    ? tokens.primary.withOpacity(0.4)
                    : (widget.borderColor ?? tokens.borderSubtle),
                width: 1.5,
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
