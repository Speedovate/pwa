// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/date_picker.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/view_models/register.vm.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with WidgetsBindingObserver {
  RegisterViewModel registerViewModel = RegisterViewModel();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _referralFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  static const double _registerSelfieVisibleFractionWeb = 0.55;
  static const double _registerSelfieVisibleFractionMobile = 0.60;

  Widget _buildTopCroppedSelfiePreview(
    BoxConstraints constraints, {
    required double visibleFraction,
  }) {
    return SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: constraints.maxHeight / visibleFraction,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(
                    selfieFileNeedsHorizontalFlip ? -1.0 : 1.0,
                    1.0,
                    1.0,
                    1.0,
                  ),
                child: Image.memory(
                  selfieFile!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasPendingRegisterDetails(RegisterViewModel vm) {
    return agreed == true ||
        selfieFile != null ||
        (vm.nameTEC.text != "" && vm.nameTEC.text != "null") ||
        (vm.emailTEC.text != "" && vm.emailTEC.text != "null") ||
        (vm.phoneTEC.text != "" && vm.phoneTEC.text != "null") ||
        (vm.birthdayTEC.text != "" && vm.birthdayTEC.text != "null") ||
        (vm.referralTEC.text != "" && vm.referralTEC.text != "null") ||
        (vm.passwordTEC.text != "" && vm.passwordTEC.text != "null") ||
        (vm.cPasswordTEC.text != "" && vm.cPasswordTEC.text != "null");
  }

  void _leaveRegisterPage() {
    setState(() {
      isTourist = false;
    });
    Get.back();
  }

  void _confirmLeaveRegisterPage(RegisterViewModel vm) {
    if (!_hasPendingRegisterDetails(vm)) {
      _leaveRegisterPage();
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
        _leaveRegisterPage();
      },
    );
  }

  void _toggleTermsAgreement() {
    setState(() {
      agreed = !agreed;
    });
  }

  void _collapseBirthdayPicker(RegisterViewModel vm) {
    if (!vm.isBirthdayActive) {
      return;
    }
    setState(() {
      vm.isBirthdayActive = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameFocusNode.addListener(_handleFocusChange);
    _emailFocusNode.addListener(_handleFocusChange);
    _phoneFocusNode.addListener(_handleFocusChange);
    _passwordFocusNode.addListener(_handleFocusChange);
    _confirmPasswordFocusNode.addListener(_handleFocusChange);
    _referralFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _nameFocusNode.hasFocus ||
      _emailFocusNode.hasFocus ||
      _phoneFocusNode.hasFocus ||
      _passwordFocusNode.hasFocus ||
      _confirmPasswordFocusNode.hasFocus ||
      _referralFocusNode.hasFocus;

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
      _collapseBirthdayPicker(registerViewModel);
      Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameFocusNode.removeListener(_handleFocusChange);
    _emailFocusNode.removeListener(_handleFocusChange);
    _phoneFocusNode.removeListener(_handleFocusChange);
    _passwordFocusNode.removeListener(_handleFocusChange);
    _confirmPasswordFocusNode.removeListener(_handleFocusChange);
    _referralFocusNode.removeListener(_handleFocusChange);
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _referralFocusNode.dispose();
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
        _confirmLeaveRegisterPage(registerViewModel);
      },
      child: ViewModelBuilder<RegisterViewModel>.reactive(
        viewModelBuilder: () => registerViewModel,
        onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final canUseGoogleAuth = isGoogleAuthLikelySupported();
          final showGoogleAuthOption =
              canUseGoogleAuth && !AuthService.inReviewMode();
          final useGoogleFlow = isTourist && showGoogleAuthOption;
          final mediaQuery = MediaQuery.of(context);
          final registerSelfieSize = mediaQuery.size.width.clamp(0, 800) / 2.5;
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _collapseBirthdayPicker(vm);
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
                                onTap: () {
                                  _confirmLeaveRegisterPage(vm);
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
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF030744),
                                ),
                              ),
                            ],
                          ),
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 8),
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    selfieFile != null
                                        ? GestureDetector(
                                            onTap: () async {
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                              await showCameraSource();
                                              if (!mounted) {
                                                return;
                                              }
                                              setState(() {});
                                            },
                                            child: Container(
                                              width: registerSelfieSize,
                                              height: registerSelfieSize,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFF030744),
                                                  width: 1,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(
                                                    1000,
                                                  ),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(
                                                    1000,
                                                  ),
                                                ),
                                                child: kIsWeb
                                                    ? LayoutBuilder(
                                                        builder: (
                                                          context,
                                                          constraints,
                                                        ) {
                                                          return _buildTopCroppedSelfiePreview(
                                                            constraints,
                                                            visibleFraction:
                                                                _registerSelfieVisibleFractionWeb,
                                                          );
                                                        },
                                                      )
                                                    : LayoutBuilder(
                                                        builder: (
                                                          context,
                                                          constraints,
                                                        ) {
                                                          return _buildTopCroppedSelfiePreview(
                                                            constraints,
                                                            visibleFraction:
                                                                _registerSelfieVisibleFractionMobile,
                                                          );
                                                        },
                                                      ),
                                              ),
                                            ),
                                          )
                                        : WidgetButton(
                                            onTap: () async {
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                              await showCameraSource();
                                              if (!mounted) {
                                                return;
                                              }
                                              setState(() {});
                                            },
                                            child: Container(
                                              width: registerSelfieSize,
                                              height: registerSelfieSize,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(
                                                    1000,
                                                  ),
                                                ),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFF030744),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                controller: vm.nameTEC,
                                focusNode: _nameFocusNode,
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
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : !vm.isBirthdayActive
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity.clamp(0, 800),
                                        child: WidgetButton(
                                          borderRadius: 10,
                                          onTap: () async {
                                            setState(() {
                                              vm.isBirthdayActive = true;
                                            });
                                          },
                                          child: Container(
                                            width: mediaQuery.size.width - 48,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.all(
                                                Radius.circular(
                                                  10,
                                                ),
                                              ),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF030744,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 17),
                                                Text(
                                                  (vm.birthdayTEC.text == "" ||
                                                          vm.birthdayTEC.text ==
                                                              "null")
                                                      ? "Birthday"
                                                      : vm.birthdayTEC.text,
                                                  style: const TextStyle(
                                                    height: 1,
                                                    fontSize: 14,
                                                    fontFamily: "Inter",
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF030744),
                                                  ),
                                                ),
                                                const Expanded(
                                                  child: SizedBox(),
                                                ),
                                                const Icon(
                                                  Icons.calendar_month_outlined,
                                                  size: 24,
                                                  color: Color(0xFF030744),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {},
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            child: Container(
                                              width: double.infinity.clamp(
                                                0,
                                                800,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                ),
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                              ),
                                              height: 150,
                                              child: DatePickerWidget(
                                                minYear: 1924,
                                                selectedDate: vm.selectedDate,
                                                onDateTimeChanged: (newDate) {
                                                  setState(() {
                                                    vm.selectedDate = newDate;
                                                  });
                                                },
                                                showDay: true,
                                                showMonth: true,
                                                showYear: true,
                                                order: const [
                                                  'month',
                                                  'day',
                                                  'year',
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 16,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  height: 30,
                                                  child: WidgetButton(
                                                    mainColor:
                                                        const Color(0xFF007BFF),
                                                    borderRadius: 1000,
                                                    useDefaultHoverColor: false,
                                                    onTap: () {
                                                      setState(
                                                        () {
                                                          vm.isBirthdayActive =
                                                              false;
                                                          vm.birthdayTEC.text =
                                                              DateFormat(
                                                            "yyyy/MM/dd",
                                                          )
                                                                  .format(
                                                                    vm.selectedDate,
                                                                  )
                                                                  .toString();
                                                        },
                                                      );
                                                    },
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "Set",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.emailTEC,
                                      focusNode: _emailFocusNode,
                                      hintText: "juandelacruz@gmail.com",
                                      labelText: "Email Address",
                                      textCapitalization:
                                          TextCapitalization.none,
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
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.phoneTEC,
                                      focusNode: _phoneFocusNode,
                                      hintText: "XXXXXXXXX",
                                      labelText: "Phone Number",
                                      textCapitalization:
                                          TextCapitalization.none,
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
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          useGoogleFlow
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
                                      hintText: "Enter your password",
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
                                      minLines: null,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.cPasswordTEC,
                                      focusNode: _confirmPasswordFocusNode,
                                      hintText: "confirm your password",
                                      labelText: "Confirm Password",
                                      textCapitalization:
                                          TextCapitalization.none,
                                      keyboardType: TextInputType.text,
                                      textInputAction:
                                          AuthService.inReviewMode()
                                              ? TextInputAction.done
                                              : TextInputAction.next,
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
                          useGoogleFlow
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity.clamp(0, 800),
                                    child: TextFieldWidget(
                                      controller: vm.referralTEC,
                                      focusNode: _referralFocusNode,
                                      hintText: "Enter referral code",
                                      labelText: "Referral Code (Optional)",
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.done,
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
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: SizedBox(
                              width: double.infinity.clamp(0, 800),
                              child: Row(
                                children: [
                                  if (showGoogleAuthOption)
                                    WidgetButton(
                                      onTap: () {
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
                                      interactionColor: const Color(0x14030744),
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
                                              activeColor:
                                                  const Color(0xFF007BFF),
                                              checkColor: Colors.white,
                                              value: !useGoogleFlow,
                                              onChanged: (value) {
                                                setState(
                                                  () {
                                                    isTourist = !useGoogleFlow;
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "I have a PH 🇵🇭 Phone Number",
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
                                ],
                              ),
                            ),
                          ),
                          AuthService.inReviewMode()
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: SizedBox(
                              width: double.infinity.clamp(0, 800),
                              child: Row(
                                children: [
                                  WidgetButton(
                                    onTap: _toggleTermsAgreement,
                                    borderRadius: 6,
                                    mainColor: Colors.transparent,
                                    isTransparentColor: true,
                                    useDefaultHoverColor: false,
                                    interactionColor: const Color(0x14030744),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            side: const BorderSide(
                                              color: Color(0xFF030744),
                                              width: 2,
                                            ),
                                            activeColor:
                                                const Color(0xFF007BFF),
                                            checkColor: Colors.white,
                                            value: agreed,
                                            onChanged: (_) {
                                              _toggleTermsAgreement();
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
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  WidgetButton(
                                    onTap: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      openWebview(
                                        "Terms of Service",
                                        Api.terms,
                                      );
                                    },
                                    borderRadius: 6,
                                    mainColor: Colors.transparent,
                                    isTransparentColor: true,
                                    useDefaultHoverColor: false,
                                    suppressInteraction: true,
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
                          !useGoogleFlow
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: ActionButton(
                                    text: "Create account",
                                    onTap: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      vm.processRegister(
                                        provider: "custom",
                                      );
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
                                        vm.processRegister(
                                          provider: "google",
                                        );
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
                                            "Sign up with Google",
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
                          const SizedBox(height: 12),
                          const Text(
                            "or",
                            style: TextStyle(
                              fontSize: 14,
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
                                FocusManager.instance.primaryFocus?.unfocus();
                                _confirmLeaveRegisterPage(vm);
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
