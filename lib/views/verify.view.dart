import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/strings.dart';
import 'package:stacked/stacked.dart';
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

class _VerifyViewState extends State<VerifyView> with WidgetsBindingObserver {
  VerifyViewModel verifyViewModel = VerifyViewModel();
  final FocusNode _codeFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool? _lastOtpConfigUsesRemoteVerification;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cancelResendCountdownTimer(reason: "init_state");
    _codeFocusNode.addListener(_handleCodeFocusChange);
    startCountDown();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }
    if (_codeFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelResendCountdownTimer(reason: "dispose");
    _codeFocusNode.removeListener(_handleCodeFocusChange);
    _codeFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelResendCountdownTimer({required String reason}) {
    if (resendCountdownTimer != null) {
      tempTimerDebug(
        "verify.resend_countdown",
        "cancel",
        details: {
          "instanceId": tempTimerInstanceId(resendCountdownTimer),
          "reason": reason,
        },
      );
    }
    resendCountdownTimer?.cancel();
    resendCountdownTimer = null;
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

  void _handleCodeFocusChange() {
    if (_codeFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
    }
    if (mounted) {
      setState(() {});
    }
  }

  bool _hasPendingVerifyDetails([VerifyViewModel? vm]) {
    final text = ((vm ?? verifyViewModel).codeTEC.text).trim();
    return text.isNotEmpty && text != "null";
  }

  void _leaveVerifyPage() {
    Get.back();
  }

  void _confirmLeaveVerifyPage([VerifyViewModel? vm]) {
    if (!_hasPendingVerifyDetails(vm)) {
      _leaveVerifyPage();
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
        _leaveVerifyPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usesRemoteOtpConfig =
        isBool(AppStrings.appSettingsObject?["strings"][itexmo] ?? false);
    if (_lastOtpConfigUsesRemoteVerification != usesRemoteOtpConfig) {
      _lastOtpConfigUsesRemoteVerification = usesRemoteOtpConfig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(verifyViewModel.applyOtpConfigBehavior());
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        _confirmLeaveVerifyPage();
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
          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;
          final otpSectionWidth = screenWidth > 848 ? 800.0 : screenWidth - 48;
          final otpSpacing = otpSectionWidth < 360 ? 8.0 : 10.0;
          final otpBoxSize =
              ((otpSectionWidth - (otpSpacing * 5)) / 6).clamp(0.0, 72.0);
          final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
          final imageHeight = imageWidth * 0.72;

          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
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
                                  onTap: () => _confirmLeaveVerifyPage(vm),
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
                              width: imageWidth,
                              height: imageHeight,
                              child: NetworkImageWidget(
                                imageUrl: AppImages.verify,
                                width: imageWidth,
                                height: imageHeight,
                                memCacheWidth: 600,
                                fit: BoxFit.fitWidth,
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
                                          text:
                                              "We have sent a 6-digit code to ",
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: SizedBox(
                                  width: double.infinity.clamp(0, 800),
                                  child: SizedBox(
                                    height: otpBoxSize,
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
                                                autofocus: false,
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
                                              children: List.generate(
                                                6,
                                                (index) {
                                                  final code = vm.codeTEC.text;
                                                  final hasValue =
                                                      index < code.length;
                                                  final isActive =
                                                      _codeFocusNode.hasFocus &&
                                                          index ==
                                                              code.length
                                                                  .clamp(0, 5);
                                                  return Container(
                                                    width: otpBoxSize,
                                                    height: otpBoxSize,
                                                    margin: EdgeInsets.only(
                                                      right: index == 5
                                                          ? 0
                                                          : otpSpacing,
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
                                                          fontSize:
                                                              otpBoxSize < 54
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
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
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
                                  child: WidgetButton(
                                    onTap: () {
                                      vm.resendCode();
                                      setState(() {
                                        resendSecs = maxResendSeconds;
                                      });
                                      startCountDown();
                                    },
                                    borderRadius: 6,
                                    mainColor: Colors.transparent,
                                    isTransparentColor: true,
                                    useDefaultHoverColor: false,
                                    suppressInteraction: true,
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
                              child: WidgetButton(
                                onTap: () async {
                                  await showFacebookSupportDialog(context);
                                },
                                borderRadius: 6,
                                mainColor: Colors.transparent,
                                isTransparentColor: true,
                                useDefaultHoverColor: false,
                                suppressInteraction: true,
                                child: RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Need help? ",
                                        style: TextStyle(
                                          height: 1.15,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Contact",
                                        style: TextStyle(
                                          height: 1.15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007BFF),
                                        ),
                                      ),
                                      TextSpan(
                                        text: " or ",
                                        style: TextStyle(
                                          height: 1.15,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF030744),
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Message",
                                        style: TextStyle(
                                          height: 1.15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007BFF),
                                        ),
                                      ),
                                      TextSpan(
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
                            ),
                            const SizedBox(height: 32),
                          ],
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

  startCountDown() {
    if (resendCountdownTimer != null && resendCountdownTimer!.isActive) {
      tempTimerDebug("verify.resend_countdown", "skip_existing_active");
      return;
    }
    final instanceId = nextTempTimerInstanceId("verify.resend_countdown");
    tempTimerDebug(
      "verify.resend_countdown",
      "schedule",
      details: {
        "instanceId": instanceId,
        "secondsRemaining": resendSecs,
      },
    );
    resendCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        attachTempTimerInstanceId(timer, instanceId);
        tempTimerDebug(
          "verify.resend_countdown",
          "tick",
          details: {
            "instanceId": tempTimerInstanceId(timer) ?? instanceId,
            "secondsRemaining": resendSecs,
          },
        );
        if (resendSecs > 0) {
          if (mounted) {
            setState(() {
              resendSecs -= 1;
            });
          }
        } else {
          timer.cancel();
          tempTimerDebug(
            "verify.resend_countdown",
            "cancel_complete",
            details: {
              "instanceId": tempTimerInstanceId(timer) ?? instanceId,
            },
          );
          if (identical(resendCountdownTimer, timer)) {
            resendCountdownTimer = null;
          }
        }
      },
    );
  }
}
