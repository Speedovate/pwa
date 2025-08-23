import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/send.view.dart';
import 'package:pwa/widgets/text_field.dart';
import 'package:pwa/views/register.view.dart';
import 'package:pwa/view_models/login.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

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
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
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
                            icon: const Padding(
                              padding: EdgeInsets.only(
                                top: 2,
                                right: 4,
                                bottom: 2,
                              ),
                              child: Icon(
                                MingCuteIcons.mgc_left_line,
                                color: Color(0xFF030744),
                                size: 38,
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
                            controller: vm.phoneTEC,
                            hintText: "XXXXXXXXX",
                            labelText: "Phone Number",
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            obscureText: false,
                            showPrefix: true,
                            showSuffix: false,
                            prefixText: "+63",
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
                              GestureDetector(
                                onTap: () {
                                  Get.to(
                                    () => const SendView(
                                      purpose: "forgot_password",
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF007BFF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          height: 50,
                          width: double.infinity.clamp(0, 800),
                          child: Material(
                            color: const Color(0xFF007BFF),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            child: SizedBox(
                              child: GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  vm.processPhoneLogin();
                                },
                                // borderRadius: const BorderRadius.all(
                                //   Radius.circular(8),
                                // ),
                                // focusColor: const Color(0xFF030744).withOpacity(
                                //   0.2,
                                // ),
                                // hoverColor: const Color(0xFF030744).withOpacity(
                                //   0.2,
                                // ),
                                // splashColor:
                                //     const Color(0xFF030744).withOpacity(
                                //   0.2,
                                // ),
                                // highlightColor:
                                //     const Color(0xFF030744).withOpacity(
                                //   0.2,
                                // ),
                                child: const Center(
                                  child: Text(
                                    "Login account",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "or",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF030744),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          height: 50,
                          width: double.infinity.clamp(0, 800),
                          child: Material(
                            color: const Color(0xFF030744),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            child: SizedBox(
                              child: GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    agreed = false;
                                    selfieFile = null;
                                  });
                                  Get.to(
                                    () => const RegisterView(),
                                  );
                                },
                                // borderRadius: const BorderRadius.all(
                                //   Radius.circular(8),
                                // ),
                                // focusColor: Colors.black,
                                // hoverColor: Colors.black,
                                // splashColor: Colors.black,
                                // highlightColor: Colors.black,
                                child: const Center(
                                  child: Text(
                                    "Create an account",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
