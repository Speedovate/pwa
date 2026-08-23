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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _passwordFocusNode.addListener(_handleFocusChange);
    _newPasswordFocusNode.addListener(_handleFocusChange);
    _confirmPasswordFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _passwordFocusNode.hasFocus ||
      _newPasswordFocusNode.hasFocus ||
      _confirmPasswordFocusNode.hasFocus;

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

  bool _hasPendingChangeDetails([ChangeViewModel? vm]) {
    final model = vm ?? changeViewModel;
    return _hasText(model.passwordTEC.text) ||
        _hasText(model.nPasswordTEC.text) ||
        _hasText(model.cPasswordTEC.text);
  }

  bool _hasText(String? value) {
    final text = (value ?? "").trim();
    return text.isNotEmpty && text != "null";
  }

  void _leaveChangePage() {
    Get.back();
  }

  void _confirmLeaveChangePage([ChangeViewModel? vm]) {
    if (!_hasPendingChangeDetails(vm)) {
      _leaveChangePage();
      return;
    }

    AlertService().showAppAlert(
      title: "Are you sure?",
      content: "You're about to leave this page",
      hideCancel: false,
      confirmText: "Leave",
      confirmColor: Colors.red,
      confirmAction: () {
        Get.back();
        _leaveChangePage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _confirmLeaveChangePage();
      },
      child: ViewModelBuilder<ChangeViewModel>.reactive(
        viewModelBuilder: () => changeViewModel,
        onViewModelReady: (vm) => vm.initialise(
          phone: widget.phone ?? "",
        ),
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;
          final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
          return GestureDetector(
            onTap: GetPlatform.isWeb
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: GetPlatform.isWeb
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: mediaQuery.padding.top,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(width: 4),
                                  WidgetButton(
                                    onTap: () => _confirmLeaveChangePage(vm),
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
                                    textCapitalization: TextCapitalization.none,
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
                                    textCapitalization: TextCapitalization.none,
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
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
