import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/view_models/register.vm.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  RegisterViewModel registerViewModel = RegisterViewModel();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (agreed == false &&
            selfieFile == null &&
            (registerViewModel.nameTEC.text == "" ||
                registerViewModel.nameTEC.text == "null") &&
            (registerViewModel.emailTEC.text == "" ||
                registerViewModel.emailTEC.text == "null") &&
            (registerViewModel.phoneTEC.text == "" ||
                registerViewModel.phoneTEC.text == "null") &&
            (registerViewModel.passwordTEC.text == "" ||
                registerViewModel.passwordTEC.text == "null") &&
            (registerViewModel.cPasswordTEC.text == "" ||
                registerViewModel.cPasswordTEC.text == "null")) {
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
      child: ViewModelBuilder<RegisterViewModel>.reactive(
        viewModelBuilder: () => registerViewModel,
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
                              if (agreed == false &&
                                  selfieFile == null &&
                                  (vm.nameTEC.text == "" ||
                                      vm.nameTEC.text == "null") &&
                                  (vm.emailTEC.text == "" ||
                                      vm.emailTEC.text == "null") &&
                                  (vm.phoneTEC.text == "" ||
                                      vm.phoneTEC.text == "null") &&
                                  (vm.passwordTEC.text == "" ||
                                      vm.passwordTEC.text == "null") &&
                                  (vm.cPasswordTEC.text == "" ||
                                      vm.cPasswordTEC.text == "null")) {
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
                            "Register",
                            style: TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF030744),
                            ),
                          ),
                        ],
                      ),
                      AuthService.inReviewMode()
                          ? const SizedBox()
                          : const SizedBox(height: 8),
                      AuthService.inReviewMode()
                          ? const SizedBox()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                selfieFile != null
                                    ? GestureDetector(
                                        onTap: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          showCameraSource();
                                        },
                                        child: Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width
                                                  .clamp(0, 800) /
                                              2.5,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width
                                                  .clamp(0, 800) /
                                              2.5,
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              fit: BoxFit.cover,
                                              image: MemoryImage(selfieFile!),
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF030744),
                                              width: 1,
                                            ),
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : WidgetButton(
                                        onTap: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          showCameraSource();
                                        },
                                        child: Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width
                                                  .clamp(0, 800) /
                                              2.5,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width
                                                  .clamp(0, 800) /
                                              2.5,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(
                                                1000,
                                              ),
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF030744),
                                            ),
                                          ),
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_camera_outlined,
                                                color: Color(0xFF030744),
                                                size: 50,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                "Profile Photo",
                                                style: TextStyle(
                                                  height: 1.05,
                                                  fontSize: 14,
                                                  fontFamily: "Inter",
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF030744),
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                      AuthService.inReviewMode()
                          ? const SizedBox(height: 12)
                          : const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: TextFieldWidget(
                            readOnly: selfieFile == null &&
                                !AuthService.inReviewMode(),
                            onTap: () {
                              if (selfieFile == null &&
                                  !AuthService.inReviewMode()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processRegister();
                              }
                            },
                            controller: vm.nameTEC,
                            hintText: "Juan Dela Cruz",
                            labelText: "Full Name",
                            textCapitalization: TextCapitalization.words,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            obscureText: false,
                            showPrefix: true,
                            showSuffix: false,
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
                          child: TextFieldWidget(
                            readOnly: selfieFile == null &&
                                !AuthService.inReviewMode(),
                            onTap: () {
                              if (selfieFile == null &&
                                  !AuthService.inReviewMode()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processRegister();
                              }
                            },
                            controller: vm.emailTEC,
                            hintText: "juandelacruz@gmail.com",
                            labelText: "Email Address",
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            obscureText: false,
                            showPrefix: true,
                            showSuffix: false,
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
                          child: TextFieldWidget(
                            readOnly: selfieFile == null &&
                                !AuthService.inReviewMode(),
                            onTap: () {
                              if (selfieFile == null &&
                                  !AuthService.inReviewMode()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processRegister();
                              }
                            },
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
                            readOnly: selfieFile == null &&
                                !AuthService.inReviewMode(),
                            onTap: () {
                              if (selfieFile == null &&
                                  !AuthService.inReviewMode()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processRegister();
                              }
                            },
                            controller: vm.passwordTEC,
                            hintText: "Enter your password",
                            labelText: "Password",
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
                            readOnly: selfieFile == null &&
                                !AuthService.inReviewMode(),
                            onTap: () {
                              if (selfieFile == null &&
                                  !AuthService.inReviewMode()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processRegister();
                              }
                            },
                            controller: vm.cPasswordTEC,
                            hintText: "confirm your password",
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
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  side: const BorderSide(
                                    color: Color(0xFF030744),
                                    width: 2,
                                  ),
                                  activeColor: const Color(0xFF007BFF),
                                  checkColor: Colors.white,
                                  value: agreed,
                                  onChanged: (value) {
                                    setState(
                                      () {
                                        agreed = !agreed;
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "I agree to the",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  height: 1,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF030744),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  openWebview(
                                    "Terms of Service",
                                    Api.terms,
                                  );
                                },
                                child: const Text(
                                  "Terms of Service",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    height: 1,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF007BFF),
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
                          text: "Create account",
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            vm.processRegister();
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
                          text: "Login to account",
                          mainColor: const Color(0xFF030744),
                          onTap: () {
                            Get.back();
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
