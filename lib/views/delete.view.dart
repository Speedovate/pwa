import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/widgets/text_field.dart';
import 'package:pwa/view_models/delete.vm.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class DeleteView extends StatefulWidget {
  const DeleteView({super.key});

  @override
  State<DeleteView> createState() => _DeleteViewState();
}

class _DeleteViewState extends State<DeleteView> {
  DeleteViewModel deleteViewModel = DeleteViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DeleteViewModel>.reactive(
      viewModelBuilder: () => deleteViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
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
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            Get.back();
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
                          "Delete Account",
                          style: TextStyle(
                            height: 1,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF030744),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Image.asset(
                        AppImages.auth,
                        fit: BoxFit.fitWidth,
                        width: MediaQuery.of(context).size.width - 100,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: TextFieldWidget(
                        controller: vm.passwordTEC,
                        hintText: "Password must be at least 8 characters",
                        labelText: "Password",
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autoFocus: false,
                        maxLines: 1,
                        minLines: null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: TextFieldWidget(
                        controller: vm.reasonTEC,
                        hintText: "Please tell us your reason",
                        labelText: "Reason",
                        textCapitalization: TextCapitalization.sentences,
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
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: SizedBox(
                        height: 50,
                        child: Material(
                          color: Colors.red,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          child: SizedBox(
                            child: GestureDetector(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                vm.processAccountDeletion();
                              },
                              // borderRadius: const BorderRadius.all(
                              //   Radius.circular(8),
                              // ),
                              // focusColor: const Color(0xFF030744).withOpacity(
                              //   0.2,
                              // ),
                              // hoverColor: const Color(0xFF030744).withOpacity(
                              //   0.2,
                              // ),
                              // splashColor: const Color(0xFF030744).withOpacity(
                              //   0.2,
                              // ),
                              // highlightColor:
                              //     const Color(0xFF030744).withOpacity(
                              //   0.2,
                              // ),
                              child: const Center(
                                child: Text(
                                  "Delete",
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
