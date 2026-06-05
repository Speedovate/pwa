import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/view_models/change.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class ChangeView extends StatefulWidget {
  final String? phone;
  final bool isReset;

  const ChangeView({
    required this.isReset,
    required this.phone,
    super.key,
  });

  @override
  State<ChangeView> createState() => _ChangeViewState();
}

class _ChangeViewState extends State<ChangeView> with WidgetsBindingObserver {
  ChangeViewModel changeViewModel = ChangeViewModel();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keyboardInset = _currentKeyboardInset();
    _passwordFocusNode.addListener(_handleFocusChange);
    _newPasswordFocusNode.addListener(_handleFocusChange);
    _confirmPasswordFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextKeyboardInset = _currentKeyboardInset();
    if ((_keyboardInset - nextKeyboardInset).abs() > 0.5) {
      setState(() {
        _keyboardInset = nextKeyboardInset;
      });
    } else if (mounted) {
      setState(() {});
    }
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _passwordFocusNode.hasFocus ||
      _newPasswordFocusNode.hasFocus ||
      _confirmPasswordFocusNode.hasFocus;

  double _currentKeyboardInset() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleFocusChange() {
    if (_hasFocusedField) {
      Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordFocusNode.removeListener(_handleFocusChange);
    _newPasswordFocusNode.removeListener(_handleFocusChange);
    _confirmPasswordFocusNode.removeListener(_handleFocusChange);
    _passwordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        AlertService().showAppAlert(
          title: "Are you sure?",
          content: "You're about to leave this page",
          hideCancel: false,
          confirmText: "Go back",
          confirmAction: () {
            Get.back();
            Get.back();
          },
        );
      },
      child: ViewModelBuilder<ChangeViewModel>.reactive(
        viewModelBuilder: () => changeViewModel,
        onViewModelReady: (vm) => vm.initialise(
          phone: widget.phone ?? "",
        ),
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
          final screenWidth = mediaQuery.size.width;
          final keyboardInset = mediaQuery.viewInsets.bottom > _keyboardInset
              ? mediaQuery.viewInsets.bottom
              : _keyboardInset;
          final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                toolbarHeight: 0,
              ),
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(bottom: keyboardInset),
                        child: GestureDetector(
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: isMobile
                                      ? mediaQuery.padding.top + 36
                                      : 12,
                                ),
                                Row(
                                  children: [
                                    const SizedBox(width: 4),
                                    WidgetButton(
                                      onTap: () {
                                        AlertService().showAppAlert(
                                          title: "Are you sure?",
                                          content:
                                              "You're about to leave this page",
                                          hideCancel: false,
                                          confirmText: "Go back",
                                          confirmAction: () {
                                            Get.back();
                                            Get.back();
                                          },
                                        );
                                      },
                                      child: const SizedBox(
                                        width: 58,
                                        height: 58,
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              top: 2,
                                              right: 4,
                                              bottom: 2,
                                            ),
                                            child: Icon(
                                              Icons.chevron_left,
                                              color: Color(0xFF030744),
                                              size: 38,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      "${widget.isReset ? "Reset" : "Change"} Password",
                                      style: const TextStyle(
                                        height: 1,
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF030744),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: imageWidth,
                                  child: NetworkImageWidget(
                                    imageUrl: AppImages.auth,
                                    width: imageWidth,
                                    memCacheWidth: 600,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                                widget.isReset
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity.clamp(0, 800),
                                          child: TextFieldWidget(
                                            controller: vm.passwordTEC,
                                            focusNode: _passwordFocusNode,
                                            hintText:
                                                "Must be at least 6 characters",
                                            labelText: "Password",
                                            textCapitalization:
                                                TextCapitalization.none,
                                            keyboardType: TextInputType.text,
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: true,
                                            showPrefix: false,
                                            showSuffix: true,
                                            prefixText: null,
                                            suffixIcon: null,
                                            onSuffixTap: null,
                                            autoFocus: false,
                                            maxLines: 1,
                                            minLines: null,
                                          ),
                                        ),
                                      ),
                                widget.isReset
                                    ? const SizedBox.shrink()
                                    : const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.nPasswordTEC,
                                      focusNode: _newPasswordFocusNode,
                                      hintText: "Must be at least 6 characters",
                                      labelText: "New Password",
                                      textCapitalization:
                                          TextCapitalization.none,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.next,
                                      obscureText: true,
                                      showPrefix: false,
                                      showSuffix: true,
                                      prefixText: null,
                                      suffixIcon: null,
                                      onSuffixTap: null,
                                      autoFocus: false,
                                      maxLines: 1,
                                      minLines: null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.cPasswordTEC,
                                      focusNode: _confirmPasswordFocusNode,
                                      hintText:
                                          "Must match ${widget.isReset ? "your new" : "with your"} password",
                                      labelText: "Confirm Password",
                                      textCapitalization:
                                          TextCapitalization.none,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.done,
                                      obscureText: true,
                                      showPrefix: false,
                                      showSuffix: true,
                                      prefixText: null,
                                      suffixIcon: null,
                                      onSuffixTap: null,
                                      autoFocus: false,
                                      maxLines: 1,
                                      minLines: null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: ActionButton(
                                    text: "Change",
                                    onTap: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      if (widget.isReset) {
                                        vm.resetPassword();
                                      } else {
                                        vm.changePassword();
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: mediaQuery.padding.bottom + 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
