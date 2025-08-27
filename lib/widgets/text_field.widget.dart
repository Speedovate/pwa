import 'package:flutter/material.dart';

class TextFieldWidget extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool floatLabel;
  final bool suffixVisibility;
  final String hintText;
  final String labelText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool showPrefix;
  final bool showSuffix;
  final String? prefixText;
  final IconData? prefixIcon;
  final double prefixIconSize;
  final IconData? suffixIcon;
  final double suffixIconSize;
  final Function()? onTap;
  final Function()? onSuffixTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final TextCapitalization? textCapitalization;
  final bool autoFocus;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final EdgeInsetsGeometry? contentPadding;
  final BorderRadius? borderRadius;
  final InputDecoration? inputDecoration;

  const TextFieldWidget({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = '',
    this.labelText = '',
    this.floatLabel = true,
    this.suffixVisibility = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.showPrefix = false,
    this.showSuffix = false,
    this.prefixText,
    this.prefixIcon,
    this.prefixIconSize = 24.0,
    this.suffixIcon,
    this.suffixIconSize = 24.0,
    this.onSuffixTap,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.autoFocus = false,
    this.textCapitalization,
    this.readOnly = false,
    this.maxLines,
    this.minLines,
    this.contentPadding,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.inputDecoration,
  });

  @override
  TextFieldWidgetState createState() => TextFieldWidgetState();
}

class TextFieldWidgetState extends State<TextFieldWidget> {
  late FocusNode internalFocusNode;
  bool isFocused = false;
  bool isVisible = true;

  @override
  void initState() {
    super.initState();
    internalFocusNode = widget.focusNode ?? FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        isVisible = !widget.obscureText;
      });
    });
    internalFocusNode.addListener(() {
      setState(() {
        isFocused = internalFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: const Color(0xFF007BFF),
          selectionColor: const Color(0xFF007BFF).withOpacity(0.3),
          selectionHandleColor: const Color(0xFF007BFF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: widget.readOnly ? Colors.grey : const Color(0xFF030744),
            ),
            borderRadius: widget.borderRadius ??
                const BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: widget.readOnly ? Colors.grey : const Color(0xFF007BFF),
            ),
            borderRadius: widget.borderRadius ??
                const BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      child: TextField(
        onTap: widget.onTap,
        onChanged: (value) {
          final oldText = widget.controller?.text ?? '';
          final oldSelection = widget.controller?.selection ??
              const TextSelection.collapsed(offset: 0);
          widget.controller?.text = value;
          widget.controller?.selection = oldSelection.copyWith(
            baseOffset: oldSelection.baseOffset,
            extentOffset:
                oldSelection.baseOffset + (value.length - oldText.length),
          );
          widget.onChanged?.call(value);
        },
        onSubmitted: widget.onSubmitted,
        controller: widget.controller,
        autofocus: widget.autoFocus,
        textCapitalization:
            widget.textCapitalization ?? TextCapitalization.sentences,
        textInputAction: widget.textInputAction,
        keyboardType: widget.keyboardType,
        obscureText: !isVisible,
        focusNode: internalFocusNode,
        readOnly: widget.readOnly,
        style: TextStyle(
          height: 1,
          fontSize: 14,
          fontFamily: "Inter",
          fontWeight: FontWeight.w500,
          color: widget.readOnly ? Colors.grey : const Color(0xFF030744),
        ),
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        decoration: widget.inputDecoration ??
            InputDecoration(
              filled: true,
              floatingLabelBehavior: widget.readOnly
                  ? FloatingLabelBehavior.never
                  : widget.floatLabel
                      ? null
                      : FloatingLabelBehavior.never,
              alignLabelWithHint: true,
              hintText: widget.readOnly ? widget.labelText : widget.hintText,
              labelText: widget.labelText,
              hintStyle: TextStyle(
                height: 1,
                fontSize: 14,
                fontFamily: "Inter",
                fontWeight: FontWeight.w500,
                overflow: TextOverflow.ellipsis,
                color: widget.readOnly
                    ? Colors.grey
                    : const Color(0xFF007BFF).withOpacity(0.5),
              ),
              labelStyle: TextStyle(
                height: 1,
                fontSize: 14,
                fontFamily: "Inter",
                fontWeight: FontWeight.w500,
                color: widget.readOnly
                    ? Colors.grey
                    : !isFocused
                        ? const Color(0xFF030744)
                        : const Color(0xFF007BFF),
              ),
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 18,
                  ),
              fillColor: Colors.white,
              prefix: widget.showPrefix &&
                      widget.prefixText != "" &&
                      widget.prefixText != null
                  ? Text(
                      widget.prefixText!,
                      style: TextStyle(
                        height: 1.05,
                        fontSize: 14,
                        fontFamily: "Inter",
                        fontWeight: FontWeight.w500,
                        color: widget.readOnly
                            ? Colors.grey
                            : const Color(0xFF030744),
                      ),
                    )
                  : null,
              prefixIcon: widget.showPrefix && widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: widget.prefixIconSize,
                      color: !isFocused
                          ? widget.readOnly
                              ? Colors.grey
                              : const Color(0xFF030744)
                          : const Color(0xFF007BFF),
                    )
                  : null,
              suffixIcon: !widget.suffixVisibility &&
                      ("${widget.controller?.text}".isNotEmpty ||
                          widget.controller?.text == null)
                  ? null
                  : widget.obscureText ||
                          (widget.showSuffix && widget.suffixIcon != null)
                      ? GestureDetector(
                          onTap: () {
                            if (widget.obscureText) {
                              setState(() {
                                isVisible = !isVisible;
                              });
                            } else {
                              widget.onSuffixTap?.call();
                            }
                          },
                          child: Icon(
                            !widget.obscureText
                                ? widget.suffixIcon
                                : isVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                            size: widget.suffixIconSize,
                            color: !isFocused
                                ? widget.readOnly
                                    ? Colors.grey
                                    : const Color(0xFF030744)
                                : const Color(0xFF007BFF),
                          ),
                        )
                      : null,
            ),
      ),
    );
  }
}
