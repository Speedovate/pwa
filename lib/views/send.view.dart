import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/text_field.dart';
import 'package:pwa/view_models/send.vm.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class SendView extends StatefulWidget {
  final String purpose;

  const SendView({
    required this.purpose,
    super.key,
  });

  @override
  State<SendView> createState() => _SendViewState();
}

class _SendViewState extends State<SendView> {
  SendViewModel sendViewModel = SendViewModel();

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
                            () {
                              if (widget.purpose == "forgot_password") {
                                return "Forgot Password";
                              } else {
                                return "Get a Code";
                              }
                            }(),
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
                            textInputAction: TextInputAction.done,
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
                                  vm.sendCode(widget.purpose);
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
                                    "Send Code",
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
