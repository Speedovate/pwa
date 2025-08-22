import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/view_models/verify.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class VerifyView extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String purpose;
  final String? password;

  const VerifyView({
    required this.name,
    required this.email,
    required this.phone,
    required this.purpose,
    required this.password,
    super.key,
  });

  @override
  State<VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<VerifyView> {
  VerifyViewModel verifyViewModel = VerifyViewModel();

  @override
  void initState() {
    super.initState();
    resendCountdownTimer?.cancel();
    startCountDown();
  }

  @override
  void dispose() {
    super.dispose();
    resendCountdownTimer?.cancel();
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
      child: ViewModelBuilder<VerifyViewModel>.reactive(
        viewModelBuilder: () => verifyViewModel,
        onViewModelReady: (vm) => vm.initialise(
          name: widget.name,
          email: widget.email,
          phone: widget.phone,
          password: widget.password,
        ),
        builder: (context, vm, child) {
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
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
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
                            "Verify Code",
                            style: TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF030744),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Image.asset(
                            AppImages.verify,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 32,
                          left: 24,
                          right: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "We have sent a 6-digit code to ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: "Inter",
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                                TextSpan(
                                  text: "0${widget.phone}",
                                  style: const TextStyle(
                                    height: 1,
                                    fontSize: 14,
                                    fontFamily: "Inter",
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF007BFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          child: SizedBox(
                            height:
                                (MediaQuery.of(context).size.width.clamp(0, 800) - 106) / 6,
                            width: double.infinity.clamp(0, 800),
                            child: PinCodeTextField(
                              appContext: context,
                              length: 6,
                              controller: vm.codeTEC,
                              keyboardType: TextInputType.number,
                              animationType: AnimationType.none,
                              autoFocus: true,
                              enableActiveFill: true,
                              pinTheme: PinTheme(
                                shape: PinCodeFieldShape.box,
                                borderRadius: BorderRadius.circular(10),
                                fieldHeight:
                                    (MediaQuery.of(context).size.width.clamp(0, 800) - 106) /
                                        6,
                                fieldWidth:
                                    (MediaQuery.of(context).size.width.clamp(0, 800) - 106) /
                                        6,
                                activeColor: const Color(
                                  0xFF007BFF,
                                ),
                                selectedColor: const Color(
                                  0xFF007BFF,
                                ),
                                inactiveColor: const Color(
                                  0xFF030744,
                                ),
                                activeFillColor: Colors.white,
                                selectedFillColor: Colors.white,
                                inactiveFillColor: Colors.white,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              onChanged: (value) {},
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            child: Ink(
                              child: InkWell(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  vm.verifyCode(widget.purpose);
                                },
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(8),
                                ),
                                focusColor: const Color(0xFF030744).withOpacity(
                                  0.2,
                                ),
                                hoverColor: const Color(0xFF030744).withOpacity(
                                  0.2,
                                ),
                                splashColor:
                                    const Color(0xFF030744).withOpacity(
                                  0.2,
                                ),
                                highlightColor:
                                    const Color(0xFF030744).withOpacity(
                                  0.2,
                                ),
                                child: const Center(
                                  child: Text(
                                    "Verify",
                                    style: TextStyle(
                                      height: 1,
                                      fontSize: 18,
                                      fontFamily: "Inter",
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Didn't receive the code?"),
                          Visibility(
                            visible: resendSecs > 0,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                "($resendSecs)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Visibility(
                            visible: resendSecs == 0,
                            child: GestureDetector(
                              onTap: () async {
                                vm.resendCode();
                                setState(() {
                                  resendSecs = maxResendSeconds;
                                });
                                startCountDown();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  "Resend",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007BFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Expanded(
                        flex: 1,
                        child: SizedBox(height: 24),
                      ),
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

  void startCountDown() {
    if (resendCountdownTimer != null && resendCountdownTimer!.isActive) {
      return;
    }
    resendCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (resendSecs > 0) {
          if (mounted) {
            setState(() {
              resendSecs -= 1;
            });
          }
        } else {
          timer.cancel();
        }
      },
    );
  }
}
