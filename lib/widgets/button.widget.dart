import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ActionButton extends StatefulWidget {
  final String text;
  final double height;
  final TextStyle style;
  final Color? mainColor;
  final VoidCallback onTap;
  final Color? borderColor;
  final VoidCallback? onLongPress;
  final double borderRadius;

  const ActionButton({
    super.key,
    this.height = 50,
    required this.text,
    required this.onTap,
    this.style = const TextStyle(
      fontSize: 14,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.mainColor = const Color(0xFF007BFF),
    this.borderColor,
    this.onLongPress,
    this.borderRadius = 8,
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
        onLongPress: widget.onLongPress,
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
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: widget.style,
                  textAlign: TextAlign.center,
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
  final VoidCallback onTapEnd;
  final VoidCallback onTapStart;
  final VoidCallback? onLongPress;
  final bool isTransparentColor;
  final bool useDefaultHoverColor;
  final bool disableGestureDetection;
  final bool suppressInteraction;
  final Color? interactionColor;

  static void _null() {}

  const WidgetButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onTapEnd = _null,
    this.onTapStart = _null,
    this.onLongPress,
    this.borderRadius = 1000,
    this.mainColor = Colors.white,
    this.isTransparentColor = false,
    this.useDefaultHoverColor = true,
    this.disableGestureDetection = false,
    this.suppressInteraction = false,
    this.interactionColor,
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
        onTapDown: (_) {
          _isPressed.value = true;
          widget.onTapStart();
        },
        onTapUp: (_) {
          _isPressed.value = false;
          widget.onTap();
          widget.onTapEnd();
        },
        onTapCancel: () {
          _isPressed.value = false;
          widget.onTapEnd();
        },
        onLongPress: widget.onLongPress,
        // ✅ Added
        child: ValueListenableBuilder2<bool, bool>(
          first: _isHovered,
          second: _isPressed,
          builder: (context, isHovered, isPressed, _) {
            final color = widget.disableGestureDetection ||
                    widget.suppressInteraction
                ? widget.mainColor
                : widget.useDefaultHoverColor
                    ? isPressed
                        ? Colors.grey.shade400
                        : (isHovered
                            ? Colors.grey.shade200
                            : widget.isTransparentColor
                                ? Colors.transparent
                                : widget.mainColor)
                    : isPressed
                        ? pressColor(
                            widget.interactionColor ?? widget.mainColor!,
                          )
                        : (isHovered
                            ? hoverColor(
                                widget.interactionColor ?? widget.mainColor!,
                              )
                            : widget.isTransparentColor
                                ? Colors.transparent
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
