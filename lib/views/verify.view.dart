import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/view_models/verify.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/network_image.widget.dart';

class VerifyView extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String? purpose;
  final String? birthday;
  final String? referral;
  final String? password;

  const VerifyView({
    required this.name,
    required this.email,
    required this.phone,
    required this.purpose,
    required this.birthday,
    required this.referral,
    required this.password,
    super.key,
  });

  @override
  State<VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<VerifyView> {
  VerifyViewModel verifyViewModel = VerifyViewModel();
  final FocusNode _codeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    resendCountdownTimer?.cancel();
    _codeFocusNode.addListener(_handleCodeFocusChange);
    startCountDown();
  }

  @override
  void dispose() {
    resendCountdownTimer?.cancel();
    _codeFocusNode.removeListener(_handleCodeFocusChange);
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _handleCodeFocusChange() {
    if (mounted) {
      setState(() {});
    }
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
          birthday: widget.birthday,
          referral: widget.referral,
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
              body: LayoutBuilder(
                builder: (context, viewportConstraints) {
                  final imageHeight = (viewportConstraints.maxHeight * 0.28)
                      .clamp(140.0, 260.0);

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewportConstraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              WidgetButton(
                                onTap: () {
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
                                "Verify Code",
                                style: TextStyle(
                                  height: 1,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: imageHeight,
                            child: const Center(
                              child: NetworkImageWidget(
                                imageUrl: AppImages.verify,
                                memCacheWidth: 600,
                                fit: BoxFit.contain,
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
                              child: Center(
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
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: SizedBox(
                                width: double.infinity.clamp(0, 800),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final spacing =
                                        constraints.maxWidth < 360 ? 8.0 : 10.0;
                                    final boxSize = ((constraints.maxWidth -
                                                (spacing * 5)) /
                                            6)
                                        .clamp(0.0, 72.0);

                                    return SizedBox(
                                      height: boxSize,
                                      child: GestureDetector(
                                        onTap: () {
                                          _codeFocusNode.requestFocus();
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: 0.02,
                                                child: TextField(
                                                  controller: vm.codeTEC,
                                                  focusNode: _codeFocusNode,
                                                  autofocus: true,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  textAlignVertical:
                                                      TextAlignVertical.center,
                                                  scrollPadding:
                                                      const EdgeInsets.only(
                                                    left: 24,
                                                    top: 24,
                                                    right: 24,
                                                    bottom: 120,
                                                  ),
                                                  autofillHints: const [
                                                    AutofillHints.oneTimeCode,
                                                  ],
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        6),
                                                  ],
                                                  autocorrect: false,
                                                  enableSuggestions: false,
                                                  showCursor: false,
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    counterText: "",
                                                  ),
                                                  onChanged: (_) {
                                                    setState(() {});
                                                  },
                                                  onSubmitted: (_) {
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                    vm.verifyCode(
                                                        "${widget.purpose}");
                                                  },
                                                ),
                                              ),
                                            ),
                                            IgnorePointer(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children:
                                                    List.generate(6, (index) {
                                                  final code = vm.codeTEC.text;
                                                  final hasValue =
                                                      index < code.length;
                                                  final isActive =
                                                      _codeFocusNode.hasFocus &&
                                                          index ==
                                                              code.length
                                                                  .clamp(0, 5);
                                                  return Container(
                                                    width: boxSize,
                                                    height: boxSize,
                                                    margin: EdgeInsets.only(
                                                      right: index == 5
                                                          ? 0
                                                          : spacing,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                        color: isActive
                                                            ? const Color(
                                                                0xFF007BFF)
                                                            : const Color(
                                                                0xFF030744),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        hasValue
                                                            ? code[index]
                                                            : "",
                                                        style: TextStyle(
                                                          height: 1.2,
                                                          fontSize: boxSize < 54
                                                              ? 20
                                                              : 24,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: hasValue
                                                              ? const Color(
                                                                  0xFF030744)
                                                              : const Color(
                                                                      0xFF030744)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.25),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: ActionButton(
                              text: "Verify",
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.verifyCode("${widget.purpose}");
                              },
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
                                  onTap: () {
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
                          const SizedBox(height: 20),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Need help now? ",
                                    style: TextStyle(
                                      height: 1.15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Contact",
                                    style: const TextStyle(
                                      height: 1.15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF007BFF),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        await showFacebookSupportDialog(
                                            context);
                                      },
                                  ),
                                  const TextSpan(
                                    text: " or ",
                                    style: TextStyle(
                                      height: 1.15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Message",
                                    style: const TextStyle(
                                      height: 1.15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF007BFF),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        await showFacebookSupportDialog(
                                            context);
                                      },
                                  ),
                                  const TextSpan(
                                    text: " us!",
                                    style: TextStyle(
                                      height: 1.15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  startCountDown() {
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
