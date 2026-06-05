import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/view_models/send.vm.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class SendView extends StatefulWidget {
  final String purpose;

  const SendView({
    required this.purpose,
    super.key,
  });

  @override
  State<SendView> createState() => _SendViewState();
}

class _SendViewState extends State<SendView> with WidgetsBindingObserver {
  SendViewModel sendViewModel = SendViewModel();
  final FocusNode _phoneFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keyboardInset = _currentKeyboardInset();
    _phoneFocusNode.addListener(_handlePhoneFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneFocusNode.removeListener(_handlePhoneFocusChange);
    _phoneFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextKeyboardInset = _currentKeyboardInset();
    if ((_keyboardInset - nextKeyboardInset).abs() > 0.5) {
      setState(() {
        _keyboardInset = nextKeyboardInset;
      });
    }
    if (_phoneFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  double _currentKeyboardInset() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
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

  void _handlePhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
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
        if (sendViewModel.phoneTEC.text == "" ||
            sendViewModel.phoneTEC.text == "null") {
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
      child: ViewModelBuilder<SendViewModel>.reactive(
        viewModelBuilder: () => sendViewModel,
        onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
          final screenWidth = mediaQuery.size.width;
          final keyboardInset = mediaQuery.viewInsets.bottom > _keyboardInset
              ? mediaQuery.viewInsets.bottom
              : _keyboardInset;
          final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
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
              body: Stack(
                children: [
                  Positioned.fill(
                    child: SafeArea(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(
                          bottom: keyboardInset,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: isMobile
                                          ? mediaQuery.padding.top + 36
                                          : 12,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(width: 4),
                                        WidgetButton(
                                          onTap: () {
                                            if (sendViewModel.phoneTEC.text ==
                                                    "" ||
                                                sendViewModel.phoneTEC.text ==
                                                    "null") {
                                              Get.back();
                                            } else {
                                              AlertService().showAppAlert(
                                                title: "Are you sure?",
                                                content:
                                                    "You're about to leave this page",
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
                                        Text(
                                          () {
                                            if (widget.purpose ==
                                                "forgot_password") {
                                              return "Forgot Password";
                                            } else {
                                              return "Get a Code";
                                            }
                                          }(),
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
                                    Padding(
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
                                          textInputAction:
                                              TextInputAction.done,
                                          obscureText: false,
                                          showPrefix: true,
                                          showSuffix: false,
                                          prefixText: "+63",
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
                                        text: "Send Code",
                                        onTap: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          vm.sendCode(widget.purpose);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      height: MediaQuery.of(context)
                                              .padding
                                              .bottom +
                                          32,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
