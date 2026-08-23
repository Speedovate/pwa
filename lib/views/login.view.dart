import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/send.view.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/views/register.view.dart';
import 'package:pwa/view_models/login.vm.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/text_field.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with WidgetsBindingObserver {
  LoginViewModel loginViewModel = LoginViewModel();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneFocusNode.addListener(_handleFocusChange);
    _passwordFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _phoneFocusNode.hasFocus || _passwordFocusNode.hasFocus;

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
    _phoneFocusNode.removeListener(_handleFocusChange);
    _passwordFocusNode.removeListener(_handleFocusChange);
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasPendingLoginDetails([LoginViewModel? vm]) {
    final model = vm ?? loginViewModel;
    return _hasText(model.phoneTEC.text) || _hasText(model.passwordTEC.text);
  }

  bool _hasText(String? value) {
    final text = (value ?? "").trim();
    return text.isNotEmpty && text != "null";
  }

  void _leaveLoginPage() {
    Get.back();
  }

  void _confirmLeaveLoginPage([LoginViewModel? vm]) {
    if (!_hasPendingLoginDetails(vm)) {
      _leaveLoginPage();
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
        _leaveLoginPage();
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
        _confirmLeaveLoginPage();
      },
      child: ViewModelBuilder<LoginViewModel>.reactive(
        viewModelBuilder: () => loginViewModel,
        onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final canUseGoogleAuth = isGoogleAuthLikelySupported();
          final useGoogleFlow = isTourist && canUseGoogleAuth;
          final mediaQuery = MediaQuery.of(context);
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
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(height: mediaQuery.padding.top + 12),
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              WidgetButton(
                                onTap: () => _confirmLeaveLoginPage(vm),
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
                              const Text(
                                "Login",
                                style: TextStyle(
                                  height: 1,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: SizedBox(
                              width: double.infinity.clamp(0, 800),
                              child: TextFieldWidget(
                                readOnly: useGoogleFlow,
                                controller: vm.phoneTEC,
                                focusNode: _phoneFocusNode,
                                hintText: "XXXXXXXXX",
                                labelText: "Phone Number",
                                textCapitalization: TextCapitalization.none,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                obscureText: false,
                                showPrefix: true,
                                showSuffix: false,
                                prefixText: useGoogleFlow ? null : "+63",
                                suffixIcon: null,
                                onSuffixTap: null,
                                autoFocus: false,
                                minLines: null,
                                maxLines: 1,
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
                                readOnly: useGoogleFlow,
                                controller: vm.passwordTEC,
                                focusNode: _passwordFocusNode,
                                hintText: "Enter your password",
                                labelText: "Password",
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
                                minLines: null,
                                maxLines: 1,
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AuthService.inReviewMode() ||
                                          !canUseGoogleAuth
                                      ? const SizedBox.shrink()
                                      : WidgetButton(
                                          onTap: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            vm.passwordTEC.clear();
                                            vm.phoneTEC.clear();
                                            setState(
                                              () {
                                                isTourist = !useGoogleFlow;
                                              },
                                            );
                                          },
                                          borderRadius: 6,
                                          mainColor: Colors.transparent,
                                          isTransparentColor: true,
                                          useDefaultHoverColor: false,
                                          interactionColor:
                                              const Color(0x14030744),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: Checkbox(
                                                  side: const BorderSide(
                                                    color: Color(0xFF030744),
                                                    width: 2,
                                                  ),
                                                  activeColor: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  checkColor: Colors.white,
                                                  value: !useGoogleFlow,
                                                  onChanged: (value) {
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                    vm.passwordTEC.clear();
                                                    vm.phoneTEC.clear();
                                                    setState(
                                                      () {
                                                        isTourist =
                                                            !useGoogleFlow;
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                "Use 🇵🇭 Phone",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  height: 1,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xFF030744),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  const Expanded(child: SizedBox.shrink()),
                                  WidgetButton(
                                    onTap: () {
                                      if (!useGoogleFlow) {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            reverseTransitionDuration:
                                                Duration.zero,
                                            transitionDuration: Duration.zero,
                                            pageBuilder: (
                                              context,
                                              a,
                                              b,
                                            ) =>
                                                const SendView(
                                              purpose: "forgot_password",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: 6,
                                    mainColor: Colors.transparent,
                                    isTransparentColor: true,
                                    useDefaultHoverColor: false,
                                    disableGestureDetection: useGoogleFlow,
                                    suppressInteraction: true,
                                    child: Text(
                                      "Forgot password?",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: useGoogleFlow
                                            ? Colors.grey
                                            : const Color(0xFF007BFF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          !useGoogleFlow
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: ActionButton(
                                    text: "Login with phone",
                                    onTap: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      vm.processPhoneLogin();
                                    },
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Container(
                                    height: 50,
                                    width: double.infinity.clamp(0, 800),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF030744),
                                      ),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    child: WidgetButton(
                                      borderRadius: 8,
                                      onTap: () {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        vm.processGoogleLogin();
                                      },
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          NetworkImageWidget(
                                            imageUrl: AppImages.google,
                                            memCacheWidth: 600,
                                            width: 24,
                                            height: 24,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            "Sign in with Google",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF030744),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          if (canUseGoogleAuth) const SizedBox(height: 12),
                          if (canUseGoogleAuth)
                            const Text(
                              "or",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF030744),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (canUseGoogleAuth) const SizedBox(height: 12),
                          if (!canUseGoogleAuth) const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: ActionButton(
                              text: "Create an account",
                              mainColor: const Color(0xFF030744),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                setState(() {
                                  agreed = false;
                                  isTourist = false;
                                  selfieFile = null;
                                });
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    reverseTransitionDuration: Duration.zero,
                                    transitionDuration: Duration.zero,
                                    pageBuilder: (
                                      context,
                                      a,
                                      b,
                                    ) =>
                                        const RegisterView(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
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
