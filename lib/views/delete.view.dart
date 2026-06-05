import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/view_models/delete.vm.dart';
import 'package:pwa/widgets/network_image.widget.dart';
import 'package:pwa/widgets/text_field.widget.dart';

class DeleteView extends StatefulWidget {
  const DeleteView({super.key});

  @override
  State<DeleteView> createState() => _DeleteViewState();
}

class _DeleteViewState extends State<DeleteView> with WidgetsBindingObserver {
  DeleteViewModel deleteViewModel = DeleteViewModel();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _reasonFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keyboardInset = _currentKeyboardInset();
    _passwordFocusNode.addListener(_handleFocusChange);
    _reasonFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextKeyboardInset = _currentKeyboardInset();
    if ((_keyboardInset - nextKeyboardInset).abs() > 0.5) {
      setState(() {
        _keyboardInset = nextKeyboardInset;
      });
    } else if (mounted) {
      setState(() {});
    }
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _passwordFocusNode.hasFocus || _reasonFocusNode.hasFocus;

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

  void _handleFocusChange() {
    if (_hasFocusedField) {
      Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordFocusNode.removeListener(_handleFocusChange);
    _reasonFocusNode.removeListener(_handleFocusChange);
    _passwordFocusNode.dispose();
    _reasonFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DeleteViewModel>.reactive(
      viewModelBuilder: () => deleteViewModel,
      onViewModelReady: (vm) => vm.initialise(),
        builder: (context, vm, child) {
          final mediaQuery = MediaQuery.of(context);
          final isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
          final screenWidth = mediaQuery.size.width;
        final keyboardInset = mediaQuery.viewInsets.bottom > _keyboardInset
            ? mediaQuery.viewInsets.bottom
            : _keyboardInset;
        final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            Get.back();
          },
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                toolbarHeight: 0,
              ),
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(bottom: keyboardInset),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
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
                                      Get.back();
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
                                    "Delete Account",
                                    style: TextStyle(
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
                                    controller: vm.passwordTEC,
                                    focusNode: _passwordFocusNode,
                                    hintText:
                                        "Password must be at least 8 characters",
                                    labelText: "Password",
                                    textCapitalization: TextCapitalization.none,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.next,
                                    autoFocus: false,
                                    maxLines: 1,
                                    minLines: null,
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
                                    controller: vm.reasonTEC,
                                    focusNode: _reasonFocusNode,
                                    hintText: "Please tell us your reason",
                                    labelText: "Reason",
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.done,
                                    obscureText: false,
                                    showPrefix: false,
                                    showSuffix: false,
                                    prefixText: null,
                                    suffixIcon: null,
                                    onSuffixTap: null,
                                    autoFocus: false,
                                    maxLines: null,
                                    minLines: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: ActionButton(
                                  text: "Delete",
                                  mainColor: Colors.red,
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    vm.processAccountDeletion();
                                  },
                                ),
                              ),
                              SizedBox(
                                height: mediaQuery.padding.bottom + 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
