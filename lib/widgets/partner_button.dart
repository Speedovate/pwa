import 'package:flutter/material.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class PartnerButtonWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPressChanged;
  final String image;
  final bool show;
  final Color? borderColor;
  final double borderWidth;

  const PartnerButtonWidget({
    required this.onTap,
    required this.image,
    required this.show,
    this.onPressChanged,
    this.borderColor,
    this.borderWidth = 0,
    super.key,
  });

  @override
  State<PartnerButtonWidget> createState() => _PartnerButtonWidgetState();
}

class _PartnerButtonWidgetState extends State<PartnerButtonWidget> {
  static const Color _primaryColor = Color(0xFF030744);

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final hasBorder = widget.borderColor != null && widget.borderWidth > 0;

    return Container(
      width: 66,
      height: 66,
      padding: EdgeInsets.all(hasBorder ? widget.borderWidth : 0),
      decoration: BoxDecoration(
        color: hasBorder ? widget.borderColor : Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.25),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: _PartnerImageSurface(
            imageUrl: widget.image,
            onTap: widget.onTap,
            onPressChanged: widget.onPressChanged,
            primaryColor: _primaryColor,
          ),
        ),
      ),
    );
  }
}

class _PartnerImageSurface extends StatefulWidget {
  const _PartnerImageSurface({
    required this.imageUrl,
    required this.onTap,
    this.onPressChanged,
    required this.primaryColor,
  });

  final String imageUrl;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPressChanged;
  final Color primaryColor;

  @override
  State<_PartnerImageSurface> createState() => _PartnerImageSurfaceState();
}

class _PartnerImageSurfaceState extends State<_PartnerImageSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
    widget.onPressChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          NetworkImageWidget(
            imageUrl: widget.imageUrl,
            memCacheWidth: 600,
            fit: BoxFit.cover,
            progressIndicatorBuilder: (context, imageUrl, progress) {
              return const SizedBox.shrink();
            },
            errorWidget: (context, imageUrl, error) {
              return Container(
                color: Colors.white,
                child: Icon(
                  Icons.storefront_outlined,
                  color: widget.primaryColor.withValues(alpha: 0.5),
                ),
              );
            },
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: _pressed
                  ? widget.primaryColor.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
