import 'package:flutter/foundation.dart';
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
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);
  final ValueNotifier<bool> _isPressed = ValueNotifier(false);

  @override
  void dispose() {
    _isHovered.dispose();
    _isPressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: GestureDetector(
        onTapDown: (_) => _isPressed.value = true,
        onTapUp: (_) {
          _isPressed.value = false;
          widget.onTap();
        },
        onTapCancel: () => _isPressed.value = false,
        child: ValueListenableBuilder2<bool, bool>(
          first: _isHovered,
          second: _isPressed,
          builder: (context, isHovered, isPressed, _) {
            final color = isPressed
                ? pressColor(widget.mainColor!)
                : (isHovered
                    ? hoverColor(widget.mainColor!)
                    : widget.mainColor);

            return Container(
              height: widget.height,
              width: double.infinity.clamp(0, 800),
              decoration: BoxDecoration(
                color: color,
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: widget.style,
                ),
              ),
            );
          },
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
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);
  final ValueNotifier<bool> _isPressed = ValueNotifier(false);

  @override
  void dispose() {
    _isHovered.dispose();
    _isPressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: GestureDetector(
        onTapDown: (_) => _isPressed.value = true,
        onTapUp: (_) {
          _isPressed.value = false;
          widget.onTap();
        },
        onTapCancel: () => _isPressed.value = false,
        child: ValueListenableBuilder2<bool, bool>(
          first: _isHovered,
          second: _isPressed,
          builder: (context, isHovered, isPressed, _) {
            final color = widget.useDefaultHoverColor
                ? isPressed
                    ? Colors.grey.shade400
                    : (isHovered ? Colors.grey.shade200 : widget.mainColor)
                : isPressed
                    ? pressColor(widget.mainColor!)
                    : (isHovered
                        ? hoverColor(widget.mainColor!)
                        : widget.mainColor);
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) => builder(context, a, b, null),
        );
      },
    );
  }
}

Color pressColor(Color color, [double amount = 0.2]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color hoverColor(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
