import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/send.view.dart';
import 'package:pwa/views/register.view.dart';
import 'package:pwa/view_models/login.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
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
          Navigator.pop(context);
        } else {
          AlertService().showAppAlert(
            title: "Are you sure?",
            content: "You're about to leave this page",
            hideCancel: false,
            confirmText: "Go back",
            confirmAction: () {
              Navigator.pop(context);
              Navigator.pop(context);
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
                          WidgetButton(
                            onTap: () {
                              if ((vm.phoneTEC.text == "" ||
                                      vm.phoneTEC.text == "null") &&
                                  (vm.passwordTEC.text == "" ||
                                      vm.passwordTEC.text == "null")) {
                                Navigator.pop(context);
                              } else {
                                AlertService().showAppAlert(
                                  title: "Are you sure?",
                                  content: "You're about to leave this page",
                                  hideCancel: false,
                                  confirmText: "Go back",
                                  confirmAction: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SendView(
                                        purpose: "forgot_password",
                                      ),
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
                        child: ActionButton(
                          text: "Login account",
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            vm.processPhoneLogin();
                          },
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
                        child: ActionButton(
                          text: "Create an account",
                          mainColor: const Color(0xFF030744),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              agreed = false;
                              selfieFile = null;
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterView(),
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
