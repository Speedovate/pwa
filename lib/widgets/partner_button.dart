import 'package:flutter/material.dart';

class PartnerButtonWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final String image;
  final bool show;

  const PartnerButtonWidget({
    required this.onTap,
    required this.image,
    required this.show,
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

    return ClipOval(
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.25),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          child: Ink.image(
            fit: BoxFit.cover,
            image: ResizeImage.resizeIfNeeded(
              600,
              null,
              NetworkImage(widget.image),
            ),
            child: InkWell(
              onTap: widget.onTap,
              hoverDuration: const Duration(milliseconds: 500),
              focusColor: _primaryColor.withOpacity(0.2),
              hoverColor: _primaryColor.withOpacity(0.2),
              splashColor: _primaryColor.withOpacity(0.2),
              highlightColor: _primaryColor.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}
