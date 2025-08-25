import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/widgets/button.widget.dart';

class AlertService {
  Future<bool?> showAppAlert({
    String? title,
    String? content,
    Color? thirdColor,
    String? thirdText,
    String? cancelText,
    String? confirmText,
    Color? confirmColor,
    Widget? customWidget,
    bool isCustom = false,
    bool hideThird = true,
    bool hideCancel = true,
    bool dismissible = true,
    Function()? thirdAction,
    Function()? cancelAction,
    Function()? confirmAction,
    String asset = AppLotties.confirm,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<bool?>(
      barrierDismissible: dismissible,
      context: Get.overlayContext!,
      builder: (BuildContext context) {
        return PopScope(
          canPop: dismissible,
          onPopInvokedWithResult: (
            didPop,
            result,
          ) async {
            if (didPop) {
              return;
            }
            if (dismissible) {
              Navigator.pop(context, true);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              onTap: () {
                if (dismissible) {
                  Navigator.pop(context, true);
                }
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent.withOpacity(0.5),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 70)
                          .clamp(0, 800),
                      child: !isCustom || customWidget == null
                          ? SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 150,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width -
                                              70,
                                          child: Lottie.asset(asset),
                                        ),
                                        SizedBox(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width -
                                              70,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                ),
                                                child: Text(
                                                  title ?? "Lorem Ipsum",
                                                  style: const TextStyle(
                                                    height: 1,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF030744),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                ),
                                                child: Text(
                                                  content ??
                                                      "Lorem ipsum dolor set amet",
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    height: 1.05,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF030744),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 32),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    hideCancel
                                                        ? const SizedBox()
                                                        : Expanded(
                                                            child: ActionButton(
                                                              height: 38,
                                                              text:
                                                                  cancelText ??
                                                                      "Cancel",
                                                              mainColor:
                                                                  Colors.white,
                                                              borderColor:
                                                                  const Color(
                                                                0xFF007BFF,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                height: 1,
                                                                fontSize: 15,
                                                                color: Color(
                                                                  0xFF007BFF,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              onTap:
                                                                  cancelAction ??
                                                                      () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                            ),
                                                          ),
                                                    hideCancel
                                                        ? const SizedBox()
                                                        : const SizedBox(
                                                            width: 16,
                                                          ),
                                                    Expanded(
                                                      child: ActionButton(
                                                        height: 38,
                                                        text: confirmText ??
                                                            (hideCancel
                                                                ? "Got it"
                                                                : "Confirm"),
                                                        mainColor:
                                                            confirmColor ??
                                                                const Color(
                                                                  0xFF007BFF,
                                                                ),
                                                        style: const TextStyle(
                                                          height: 1,
                                                          fontSize: 15,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        onTap: confirmAction ??
                                                            () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              hideThird
                                                  ? const SizedBox()
                                                  : Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 16,
                                                        left: 24,
                                                        right: 24,
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Expanded(
                                                            child: ActionButton(
                                                              height: 38,
                                                              text: thirdText ??
                                                                  "Third Button Text",
                                                              mainColor:
                                                                  thirdColor ??
                                                                      const Color(
                                                                        0xFF007BFF,
                                                                      ),
                                                              style:
                                                                  const TextStyle(
                                                                height: 1,
                                                                fontSize: 15,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              onTap:
                                                                  thirdAction ??
                                                                      () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                              const SizedBox(height: 32),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : customWidget,
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

  showLoading({Color? bg}) {
    FocusManager.instance.primaryFocus?.unfocus();
    showDialog(
      context: Get.overlayContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  children: [
                    Lottie.asset(
                      AppLotties.loading,
                      fit: BoxFit.cover,
                    ),
                    Center(
                      child: Image.asset(
                        AppImages.icon,
                        height: 50,
                        width: 50,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      barrierColor: bg ?? const Color(0xFF030744).withOpacity(0.5),
    );
  }

  stopLoading() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(Get.overlayContext!);
  }
}
