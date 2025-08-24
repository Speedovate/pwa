import 'package:flutter/material.dart';

class ActionButton extends StatefulWidget {
  final String text;
  final double height;
  final TextStyle style;
  final Color? mainColor;
  final VoidCallback onTap;
  final Color? borderColor;

  const ActionButton({
    super.key,
    this.height = 50,
    required this.text,
    required this.onTap,
    this.style = const TextStyle(
      fontSize: 16,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.mainColor = const Color(0xFF007BFF),
    this.borderColor,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          height: widget.height,
          width: double.infinity.clamp(0, 800),
          decoration: BoxDecoration(
            color: _isPressed
                ? pressColor(
                    widget.mainColor ?? const Color(0xFF007BFF),
                  )
                : (_isHovered
                    ? hoverColor(
                        widget.mainColor ?? const Color(0xFF007BFF),
                      )
                    : widget.mainColor),
            border: widget.borderColor == null
                ? null
                : Border.all(
                    color: widget.borderColor as Color,
                  ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }
}

class WidgetButton extends StatefulWidget {
  final Widget child;
  final Color? mainColor;
  final VoidCallback onTap;
  final double borderRadius;
  final bool useDefaultHoverColor;

  const WidgetButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 1000,
    this.mainColor = Colors.white,
    this.useDefaultHoverColor = true,
  });

  @override
  State<WidgetButton> createState() => _WidgetButtonState();
}

class _WidgetButtonState extends State<WidgetButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          decoration: BoxDecoration(
            color: widget.useDefaultHoverColor
                ? _isPressed
                    ? Colors.grey.shade400
                    : (_isHovered ? Colors.grey.shade200 : widget.mainColor)
                : _isPressed
                    ? pressColor(
                        widget.mainColor ?? const Color(0xFF007BFF),
                      )
                    : (_isHovered
                        ? hoverColor(
                            widget.mainColor ?? const Color(0xFF007BFF),
                          )
                        : widget.mainColor),
            borderRadius: BorderRadius.circular(
              widget.borderRadius,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

Color pressColor(Color color, [double amount = 0.2]) {
  assert(amount >= 0 && amount <= 1);
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

Color hoverColor(Color color, [double amount = 0.1]) {
  assert(amount >= 0 && amount <= 1);
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}
