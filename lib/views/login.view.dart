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
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  LoginViewModel loginViewModel = LoginViewModel();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if ((loginViewModel.phoneTEC.text == "" ||
                loginViewModel.phoneTEC.text == "null") &&
            (loginViewModel.passwordTEC.text == "" ||
                loginViewModel.passwordTEC.text == "null")) {
          Get.back();
        } else {
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
        }
      },
      child: ViewModelBuilder<LoginViewModel>.reactive(
        viewModelBuilder: () => loginViewModel,
        onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final canUseGoogleAuth = isGoogleAuthLikelySupported();
          final useGoogleFlow = isTourist && canUseGoogleAuth;
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                toolbarHeight: 0,
                backgroundColor: Colors.white,
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          WidgetButton(
                            onTap: () {
                              if ((vm.phoneTEC.text == "" ||
                                      vm.phoneTEC.text == "null") &&
                                  (vm.passwordTEC.text == "" ||
                                      vm.passwordTEC.text == "null")) {
                                Get.back();
                              } else {
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
                              }
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
                          const Text(
                            "Login",
                            style: TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
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
                              AuthService.inReviewMode() || !canUseGoogleAuth
                                  ? const SizedBox.shrink()
                                  : SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        side: const BorderSide(
                                          color: Color(0xFF030744),
                                          width: 2,
                                        ),
                                        activeColor: const Color(0xFF007BFF),
                                        checkColor: Colors.white,
                                        value: !useGoogleFlow,
                                        onChanged: (value) {
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
                                      ),
                                    ),
                              AuthService.inReviewMode() || !canUseGoogleAuth
                                  ? const SizedBox.shrink()
                                  : const SizedBox(width: 8),
                              AuthService.inReviewMode() || !canUseGoogleAuth
                                  ? const SizedBox.shrink()
                                  : const Text(
                                      "Use 🇵🇭 Phone",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        height: 1,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF030744),
                                      ),
                                    ),
                              const Expanded(child: SizedBox.shrink()),
                              GestureDetector(
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
                                  FocusManager.instance.primaryFocus?.unfocus();
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
