import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/text_field.dart';
import 'package:pwa/view_models/change.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class ChangeView extends StatefulWidget {
  final String? phone;
  final bool isReset;

  const ChangeView({
    required this.isReset,
    required this.phone,
    super.key,
  });

  @override
  State<ChangeView> createState() => _ChangeViewState();
}

class _ChangeViewState extends State<ChangeView> {
  ChangeViewModel changeViewModel = ChangeViewModel();

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
      child: ViewModelBuilder<ChangeViewModel>.reactive(
        viewModelBuilder: () => changeViewModel,
        onViewModelReady: (vm) => vm.initialise(
          phone: widget.phone ?? "",
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
                          Text(
                            "${widget.isReset ? "Reset" : "Change"} Password",
                            style: const TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF030744),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Image.asset(
                            AppImages.auth,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),
                      widget.isReset
                          ? const SizedBox()
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: SizedBox(
                                width: double.infinity.clamp(0, 800),
                                child: TextFieldWidget(
                                  controller: vm.passwordTEC,
                                  hintText: "Must be at least 6 characters",
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
                                  maxLines: 1,
                                  minLines: null,
                                ),
                              ),
                            ),
                      widget.isReset
                          ? const SizedBox()
                          : const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity.clamp(0, 800),
                          child: TextFieldWidget(
                            controller: vm.nPasswordTEC,
                            hintText: "Must be at least 6 characters",
                            labelText: "New Password",
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
                            controller: vm.cPasswordTEC,
                            hintText:
                                "Must match ${widget.isReset ? "your new" : "with your"} password",
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
                                  if (widget.isReset) {
                                    vm.resetPassword();
                                  } else {
                                    vm.changePassword();
                                  }
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
                                    "Change",
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
}
