import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/browser_utils.dart';

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
  final double fontSize;
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
    this.fontSize = 14.0,
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
  late bool ownsFocusNode;
  bool isFocused = false;
  bool isVisible = true;
  DateTime? _lastWebFieldTapAt;
  bool _webFocusRestorePending = false;
  int _webFocusStabilizerToken = 0;

  bool get _isDesktopSitePhoneWeb =>
      kIsWeb && isDesktopSiteOnPhoneBrowser();

  bool get _shouldRestoreWebFocusAfterBlur {
    if (!_isDesktopSitePhoneWeb || widget.readOnly) {
      return false;
    }
    final lastTapAt = _lastWebFieldTapAt;
    if (lastTapAt == null) {
      return false;
    }
    return DateTime.now().difference(lastTapAt) <=
        const Duration(milliseconds: 1200);
  }

  void _handleFocusChange() {
    if (!internalFocusNode.hasFocus && _shouldRestoreWebFocusAfterBlur) {
      _scheduleWebFocusRestore();
    }
    if (!mounted) return;
    setState(() {
      isFocused = internalFocusNode.hasFocus;
    });
  }

  void _scheduleWebFocusRestore() {
    if (_webFocusRestorePending) {
      return;
    }
    _webFocusRestorePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _webFocusRestorePending = false;
      if (!mounted || internalFocusNode.hasFocus || widget.readOnly) {
        return;
      }
      internalFocusNode.requestFocus();
    });
    _scheduleWebFocusStabilizer();
  }

  void _scheduleWebFocusStabilizer() {
    if (!_isDesktopSitePhoneWeb || widget.readOnly) {
      return;
    }
    final scheduledAt = _lastWebFieldTapAt;
    if (scheduledAt == null) {
      return;
    }
    final token = ++_webFocusStabilizerToken;
    const delays = <int>[0, 80, 180, 320, 520, 820];
    for (final delayMs in delays) {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted ||
            token != _webFocusStabilizerToken ||
            internalFocusNode.hasFocus ||
            widget.readOnly) {
          return;
        }
        final lastTapAt = _lastWebFieldTapAt;
        if (lastTapAt == null ||
            DateTime.now().difference(lastTapAt) >
                const Duration(milliseconds: 1200)) {
          return;
        }
        internalFocusNode.requestFocus();
      });
    }
  }

  void _handleTextFieldTap() {
    if (_isDesktopSitePhoneWeb) {
      _lastWebFieldTapAt = DateTime.now();
      _scheduleWebFocusStabilizer();
    }
    widget.onTap?.call();
  }

  @override
  void initState() {
    super.initState();
    ownsFocusNode = widget.focusNode == null;
    internalFocusNode = widget.focusNode ?? FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        isVisible = !widget.obscureText;
      });
    });
    internalFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode != widget.focusNode) {
      internalFocusNode.removeListener(_handleFocusChange);
      if (ownsFocusNode) {
        internalFocusNode.dispose();
      }

      ownsFocusNode = widget.focusNode == null;
      internalFocusNode = widget.focusNode ?? FocusNode();
      internalFocusNode.addListener(_handleFocusChange);
      isFocused = internalFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    internalFocusNode.removeListener(_handleFocusChange);
    if (ownsFocusNode) {
      internalFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: const Color(0xFF007BFF),
          selectionColor: const Color(0xFF007BFF).withValues(alpha: 0.3),
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
        onTap: _handleTextFieldTap,
        onTapOutside: _isDesktopSitePhoneWeb ? (_) {} : null,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        controller: widget.controller,
        autofocus: widget.autoFocus,
        textCapitalization:
            widget.textCapitalization ?? TextCapitalization.sentences,
        textInputAction: widget.textInputAction,
        keyboardType: widget.keyboardType,
        textAlignVertical: TextAlignVertical.center,
        scrollPadding: const EdgeInsets.only(
          left: 24,
          top: 24,
          right: 24,
          bottom: 120,
        ),
        autocorrect: !widget.obscureText,
        enableSuggestions: !widget.obscureText,
        enableIMEPersonalizedLearning: !widget.obscureText,
        obscureText: !isVisible,
        focusNode: internalFocusNode,
        readOnly: widget.readOnly,
        style: TextStyle(
          height: 1.2,
          fontSize: widget.fontSize,
          fontFamily: "Inter",
          fontWeight: FontWeight.bold,
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
                fontSize: widget.fontSize,
                fontFamily: "Inter",
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
                color: widget.readOnly
                    ? Colors.grey
                    : const Color(0xFF007BFF).withValues(alpha: 0.5),
              ),
              labelStyle: TextStyle(
                height: 1,
                fontSize: widget.fontSize,
                fontFamily: "Inter",
                fontWeight: FontWeight.bold,
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
                        fontSize: widget.fontSize,
                        fontFamily: "Inter",
                        fontWeight: FontWeight.bold,
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
                      color: widget.readOnly
                          ? Colors.grey
                          : !isFocused
                              ? const Color(0xFF030744)
                              : const Color(0xFF007BFF),
                    )
                  : null,
              suffixIcon: !widget.suffixVisibility &&
                      (widget.controller?.text == "" ||
                          widget.controller?.text == null)
                  ? null
                  : widget.obscureText ||
                          (widget.showSuffix && widget.suffixIcon != null)
                      ? GestureDetector(
                          onTap: () {
                            if (!widget.readOnly) {
                              if (widget.obscureText) {
                                setState(() {
                                  isVisible = !isVisible;
                                });
                              } else {
                                widget.onSuffixTap?.call();
                              }
                            }
                          },
                          child: Icon(
                            !widget.obscureText
                                ? widget.suffixIcon
                                : isVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                            size: widget.suffixIconSize,
                            color: widget.readOnly
                                ? Colors.grey
                                : !isFocused
                                    ? const Color(0xFF030744)
                                    : const Color(0xFF007BFF),
                          ),
                        )
                      : null,
            ),
      ),
    );
  }
}
