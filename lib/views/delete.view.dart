import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/view_models/delete.vm.dart';
import 'package:pwa/services/alert.service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _passwordFocusNode.addListener(_handleFocusChange);
    _reasonFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_hasFocusedField) {
      _scrollToBottom();
    }
  }

  bool get _hasFocusedField =>
      _passwordFocusNode.hasFocus || _reasonFocusNode.hasFocus;

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

  bool _hasPendingDeleteDetails([DeleteViewModel? vm]) {
    final model = vm ?? deleteViewModel;
    return _hasText(model.passwordTEC.text) || _hasText(model.reasonTEC.text);
  }

  bool _hasText(String? value) {
    final text = (value ?? "").trim();
    return text.isNotEmpty && text != "null";
  }

  void _leaveDeletePage() {
    Get.back();
  }

  void _confirmLeaveDeletePage([DeleteViewModel? vm]) {
    if (!_hasPendingDeleteDetails(vm)) {
      _leaveDeletePage();
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
        _leaveDeletePage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DeleteViewModel>.reactive(
      viewModelBuilder: () => deleteViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        final imageWidth = (screenWidth - 48).clamp(220.0, 400.0);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            _confirmLeaveDeletePage(vm);
          },
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: mediaQuery.padding.top,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                WidgetButton(
                                  onTap: () => _confirmLeaveDeletePage(vm),
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
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  vm.processAccountDeletion();
                                },
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
          ),
        );
      },
    );
  }
}
