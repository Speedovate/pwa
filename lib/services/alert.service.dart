import 'dart:async';

import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/models/available_driver.model.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/network_image.widget.dart';

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
      context: Get.context!,
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
              Get.back(result: true);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              onTap: () {
                if (dismissible) {
                  Get.back(result: true);
                }
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent.withValues(alpha: 0.5),
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
                                                    fontSize: 14,
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
                                                        ? const SizedBox
                                                            .shrink()
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
                                                                fontSize: 14,
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
                                                                        Get.back();
                                                                      },
                                                            ),
                                                          ),
                                                    hideCancel
                                                        ? const SizedBox
                                                            .shrink()
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
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        onTap: confirmAction ??
                                                            () {
                                                              Get.back();
                                                            },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              hideThird
                                                  ? const SizedBox.shrink()
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
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              onTap:
                                                                  thirdAction ??
                                                                      () {
                                                                        Get.back();
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

  Future<bool?> showDriverDistantDialog({
    required AvailableDriver availableDriver,
    required double totalAmount,
    required FutureOr<void> Function() onAccept,
    VoidCallback? onCancel,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<bool?>(
      context: Get.context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {},
          child: _DriverDistantDialog(
            availableDriver: availableDriver,
            totalAmount: totalAmount,
            onAccept: onAccept,
            onCancel: onCancel,
          ),
        );
      },
    );
  }

  showLoading({
    Color? bg,
    bool dismissible = false,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    isLoadingDialogOpen = true;
    showDialog(
      context: Get.context!,
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
              Get.back(result: true);
            }
          },
          child: GestureDetector(
            onTap: () {
              if (dismissible) {
                Get.back(result: true);
              }
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
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
                          const Center(
                            child: NetworkImageWidget(
                              imageUrl: AppImages.icon,
                              memCacheWidth: 600,
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
              ),
            ),
          ),
        );
      },
      barrierColor: bg ?? Colors.black.withValues(alpha: 0.5),
    ).whenComplete(() {
      isLoadingDialogOpen = false;
    });
  }

  stopLoading({bool forceStop = false}) {
    if (!forceStop) {
      if (!isLoadingDialogOpen || Get.isDialogOpen != true) {
        return;
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Get.back();
  }
}

class _DriverDistantDialog extends StatefulWidget {
  const _DriverDistantDialog({
    required this.availableDriver,
    required this.totalAmount,
    required this.onAccept,
    this.onCancel,
  });

  final AvailableDriver availableDriver;
  final double totalAmount;
  final FutureOr<void> Function() onAccept;
  final VoidCallback? onCancel;

  @override
  State<_DriverDistantDialog> createState() => _DriverDistantDialogState();
}

class _DriverDistantDialogState extends State<_DriverDistantDialog> {
  static const int _defaultCountdownSeconds = 10;
  Timer? _timer;
  late int _secondsLeft;
  bool _acknowledged = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _defaultCountdownSeconds;
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsLeft > 1) {
          setState(() {
            _secondsLeft -= 1;
          });
        } else {
          timer.cancel();
          setState(() {
            _secondsLeft = 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showValidationSnackBar(String message) {
    final context = Get.context;
    if (context == null) {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAccept = _secondsLeft == 0 && _acknowledged && !_submitting;
    final pickupKmValue = widget.availableDriver.pickupKm ?? 0;
    final pickupKm = pickupKmValue.toStringAsFixed(2);
    final pickupFee =
        widget.availableDriver.pickupChargeFee?.ceil().toStringAsFixed(0) ??
            "0";
    final updatedFare = ((widget.availableDriver.pickupChargeFee?.ceil() ?? 0) +
            widget.totalAmount)
        .toStringAsFixed(0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: SafeArea(
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Center(
                  child: Icon(
                    Icons.warning_rounded,
                    size: 80,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    "Driver is Distant",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.05,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Ka-TODA, the nearest driver is $pickupKm km away. An additional fare of ₱$pickupFee will apply for picking you up. The new fare will be ₱$updatedFare.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 24),
                _DriverDistantMetricTile(
                  icon: Icons.location_on_outlined,
                  label: "Driver Distance",
                  value: "$pickupKm kilometer${pickupKmValue <= 1 ? "" : "s"}",
                ),
                const SizedBox(height: 12),
                _DriverDistantMetricTile(
                  icon: Icons.receipt_long_outlined,
                  label: "Original Fare",
                  value: "${widget.totalAmount.toStringAsFixed(0)} pesos",
                ),
                const SizedBox(height: 12),
                _DriverDistantMetricTile(
                  icon: Icons.add,
                  label: "Pickup Fare",
                  value: "$pickupFee pesos",
                ),
                const SizedBox(height: 12),
                _DriverDistantMetricTile(
                  icon: Icons.payments_outlined,
                  label: "New Fare",
                  value: "$updatedFare pesos",
                ),
                const Expanded(child: SizedBox()),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _acknowledged = !_acknowledged;
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _acknowledged,
                          activeColor: const Color(0xFF007BFF),
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _acknowledged = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            "I'm aware the driver is distant and accept the additional fare voluntarily.",
                            style: TextStyle(
                              height: 1.35,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        height: 52,
                        text: "Cancel",
                        mainColor: Colors.white.withValues(alpha: 0.12),
                        borderColor: Colors.white.withValues(alpha: 0.4),
                        style: const TextStyle(
                          height: 1,
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onTap: widget.onCancel ?? () => Get.back(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ActionButton(
                        height: 52,
                        text: _secondsLeft == 0
                            ? "Accept"
                            : "Accept ($_secondsLeft)",
                        mainColor: canAccept
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.45),
                        borderColor: canAccept
                            ? null
                            : Colors.red.withValues(alpha: 0.8),
                        style: const TextStyle(
                          height: 1,
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onTap: () async {
                          if (_secondsLeft > 0) {
                            _showValidationSnackBar(
                              "Take time to read. Please try again after $_secondsLeft second${_secondsLeft == 1 ? "" : "s"}!",
                            );
                            return;
                          }
                          if (!_acknowledged) {
                            _showValidationSnackBar(
                              "Please confirm that you're aware the driver is distant and accept the additional fare voluntarily.",
                            );
                            return;
                          }
                          setState(() {
                            _submitting = true;
                          });
                          Get.back();
                          await widget.onAccept();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverDistantMetricTile extends StatelessWidget {
  const _DriverDistantMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    height: 1.05,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    height: 1.05,
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
