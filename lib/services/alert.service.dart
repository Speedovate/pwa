import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/models/available_driver.model.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/branded_circular_loader.widget.dart';
import 'package:permission_handler/permission_handler.dart';

BuildContext? _loadingDialogContext;

void _tempLoadingDebug(
  String label, {
  Map<String, Object?> details = const {},
}) {
  debugPrint(
    "[TEMP_LOADING_DEBUG] ${jsonEncode({
      "ts": DateTime.now().toIso8601String(),
      "label": label,
      "isLoadingDialogOpen": isLoadingDialogOpen,
      "isChatViewOpen": isChatViewOpen,
      "hasLoadingDialogContext": _loadingDialogContext != null,
      ...details,
    })}",
  );
}

class AlertService {
  static const double actionGap = 12;
  static const double bottomWidgetTopGap = 16;

  Future<bool?> showPermissionSettingsDialog({
    required String permissionName,
    String? reason,
  }) {
    final normalizedPermissionName = permissionName.trim();
    final displayName = normalizedPermissionName.isEmpty
        ? "Permission"
        : normalizedPermissionName;
    return showAppAlert(
      asset: AppLotties.error,
      title: "$displayName Permission Required",
      content: reason ??
          'Go to Settings > Apps > PPC TODA > Permissions and allow "$displayName".',
      confirmText: "Go to Settings",
      confirmAction: () {
        Get.back();
        openAppSettings();
      },
    );
  }

  Future<bool?> showAppAlert({
    String? title,
    String? content,
    Color? thirdColor,
    String? thirdText,
    String? cancelText,
    String? confirmText,
    Color? confirmColor,
    Widget? customWidget,
    Widget? bottomWidget,
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      context: Get.context!,
      useSafeArea: false,
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
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (dismissible) {
                        Get.back(result: true);
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final mediaQuery = MediaQuery.of(context);
                    return Center(
                      child: SizedBox(
                        width: (mediaQuery.size.width - 70).clamp(0, 800),
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
                                            width: mediaQuery.size.width - 70,
                                            child: Lottie.asset(asset),
                                          ),
                                          SizedBox(
                                            width: mediaQuery.size.width - 70,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 20,
                                                  ),
                                                  child: Text(
                                                    title ?? "Lorem Ipsum",
                                                    style: const TextStyle(
                                                      height: 1,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF030744),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 20,
                                                  ),
                                                  child: Text(
                                                    content ??
                                                        "Lorem ipsum dolor set amet",
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      height: 1.05,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Color(0xFF030744),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 24,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      hideCancel
                                                          ? const SizedBox
                                                              .shrink()
                                                          : Expanded(
                                                              child:
                                                                  ActionButton(
                                                                height: 38,
                                                                borderRadius:
                                                                    1000,
                                                                text:
                                                                    cancelText ??
                                                                        "Cancel",
                                                                mainColor:
                                                                    Colors
                                                                        .white,
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
                                                              width:
                                                                  actionGap,
                                                            ),
                                                      Expanded(
                                                        child: ActionButton(
                                                          height: 38,
                                                          borderRadius: 1000,
                                                          text: confirmText ??
                                                              (hideCancel
                                                                  ? "Got it"
                                                                  : "Confirm"),
                                                          mainColor:
                                                              confirmColor ??
                                                                  const Color(
                                                                    0xFF007BFF,
                                                                  ),
                                                          style:
                                                              const TextStyle(
                                                            height: 1,
                                                            fontSize: 14,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          onTap:
                                                              confirmAction ??
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
                                                            const EdgeInsets
                                                                .only(
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
                                                              child:
                                                                  ActionButton(
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
                                                bottomWidget == null
                                                    ? const SizedBox.shrink()
                                                    : Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                          24,
                                                          bottomWidgetTopGap,
                                                          24,
                                                          0,
                                                        ),
                                                        child: bottomWidget,
                                                      ),
                                                const SizedBox(height: 24),
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
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> showDriverDistantDialog({
    required AvailableDriver availableDriver,
    required ValueNotifier<double?> totalAmountListenable,
    double? originalFare,
    double? newBaseFare,
    double? displayedPickupFee,
    required FutureOr<void> Function() onAccept,
    VoidCallback? onCancel,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<bool?>(
      context: Get.context!,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useSafeArea: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {},
          child: _DriverDistantDialog(
            availableDriver: availableDriver,
            totalAmountListenable: totalAmountListenable,
            originalFare: originalFare,
            newBaseFare: newBaseFare,
            displayedPickupFee: displayedPickupFee,
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
    if (isLoadingDialogOpen) {
      _tempLoadingDebug(
        "ShowLoadingSkippedAlreadyOpen",
        details: {
          "dismissible": dismissible,
        },
      );
      return;
    }
    _tempLoadingDebug(
      "ShowLoadingStart",
      details: {
        "dismissible": dismissible,
      },
    );
    if (!isChatViewOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setLoadingDialogOpen(true);
    showDialog(
      context: Get.context!,
      useSafeArea: false,
      builder: (BuildContext context) {
        _loadingDialogContext = context;
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
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (dismissible) {
                        Get.back(result: true);
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandedCircularLoader(imageColor: Colors.white),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      barrierColor: bg ?? Colors.black.withValues(alpha: 0.5),
    ).whenComplete(() {
      _tempLoadingDebug("ShowLoadingWhenComplete");
      _loadingDialogContext = null;
      setLoadingDialogOpen(false);
    });
  }

  stopLoading({bool forceStop = false}) {
    _tempLoadingDebug(
      "StopLoadingStart",
      details: {
        "forceStop": forceStop,
      },
    );
    if (!forceStop) {
      if (!isLoadingDialogOpen) {
        _tempLoadingDebug(
          "StopLoadingSkippedNotOpen",
          details: {
            "forceStop": forceStop,
          },
        );
        return;
      }
    }
    if (!isChatViewOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final dialogContext = _loadingDialogContext;
    _loadingDialogContext = null;
    setLoadingDialogOpen(false);
    if (dialogContext != null) {
      final navigator = Navigator.of(dialogContext, rootNavigator: true);
      if (navigator.canPop()) {
        _tempLoadingDebug("StopLoadingNavigatorPop");
        navigator.pop();
      }
      return;
    }
    if (Get.isDialogOpen == true) {
      _tempLoadingDebug("StopLoadingGetBack");
      Get.back();
    }
  }
}

class _DriverDistantDialog extends StatefulWidget {
  const _DriverDistantDialog({
    required this.availableDriver,
    required this.totalAmountListenable,
    this.originalFare,
    this.newBaseFare,
    this.displayedPickupFee,
    required this.onAccept,
    this.onCancel,
  });

  final AvailableDriver availableDriver;
  final ValueNotifier<double?> totalAmountListenable;
  final double? originalFare;
  final double? newBaseFare;
  final double? displayedPickupFee;
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
      _timer?.cancel();
      final instanceId =
          nextTempTimerInstanceId("alert.driver_distant_countdown");
      tempTimerDebug(
        "alert.driver_distant_countdown",
        "schedule",
        details: {
          "instanceId": instanceId,
          "secondsLeft": _secondsLeft,
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        attachTempTimerInstanceId(timer, instanceId);
        tempTimerDebug(
          "alert.driver_distant_countdown",
          "tick",
          details: {
            "instanceId": tempTimerInstanceId(timer) ?? instanceId,
            "secondsLeft": _secondsLeft,
          },
        );
        if (!mounted) {
          timer.cancel();
          tempTimerDebug(
            "alert.driver_distant_countdown",
            "cancel_unmounted",
            details: {
              "instanceId": tempTimerInstanceId(timer) ?? instanceId,
            },
          );
          if (identical(_timer, timer)) {
            _timer = null;
          }
          return;
        }
        if (_secondsLeft > 1) {
          setState(() {
            _secondsLeft -= 1;
          });
        } else {
          timer.cancel();
          tempTimerDebug(
            "alert.driver_distant_countdown",
            "cancel_complete",
            details: {
              "instanceId": tempTimerInstanceId(timer) ?? instanceId,
            },
          );
          if (identical(_timer, timer)) {
            _timer = null;
          }
          setState(() {
            _secondsLeft = 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (_timer != null) {
      tempTimerDebug(
        "alert.driver_distant_countdown",
        "dispose_cancel",
        details: {
          "instanceId": tempTimerInstanceId(_timer),
        },
      );
    }
    _timer?.cancel();
    _timer = null;
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
    final pickupFeeValue =
        widget.displayedPickupFee ??
        widget.availableDriver.pickupChargeFee?.ceilToDouble() ??
        0;
    final pickupFee = pickupFeeValue.toStringAsFixed(0);
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top + 12;

    return ValueListenableBuilder<double?>(
      valueListenable: widget.totalAmountListenable,
      builder: (context, totalAmount, _) {
        final originalFare = widget.originalFare ?? totalAmount ?? 0;
        final newBaseFare = widget.newBaseFare ?? totalAmount ?? 0;
        final updatedFare = (pickupFeeValue + newBaseFare).toStringAsFixed(0);

        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          body: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox.expand(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxHeight < 760;
                      final topSpacing = isCompact ? 16.0 : 24.0;
                      final sectionSpacing = isCompact ? 16.0 : 24.0;
                      final tileSpacing = isCompact ? 10.0 : 12.0;
                      final iconSize = isCompact ? 64.0 : 80.0;
                      final titleSize = isCompact ? 22.0 : 24.0;
                      final bodySize = isCompact ? 14.0 : 16.0;
                      final buttonHeight = isCompact ? 48.0 : 52.0;
                      final bottomSpacing = (mediaQuery.padding.bottom + 20)
                          .clamp(20.0, 32.0)
                          .toDouble();
                      final checkboxFontSize = isCompact ? 13.0 : 14.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: topSpacing),
                                    Center(
                                      child: Icon(
                                        Icons.warning,
                                        size: iconSize,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        "Driver is Distant",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          height: 1.05,
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: isCompact ? 16 : 20),
                                    Text(
                                      "Ka-TODA, the nearest driver is $pickupKm km away. An additional fare of ₱$pickupFee will apply for picking you up. The new fare will be ₱$updatedFare.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        height: 1.4,
                                        fontSize: bodySize,
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: sectionSpacing),
                                    _DriverDistantMetricTile(
                                      icon: Icons.location_on,
                                      label: "Driver Distance",
                                      value:
                                          "$pickupKm kilometer${pickupKmValue <= 1 ? "" : "s"}",
                                    ),
                                    SizedBox(height: tileSpacing),
                                    _DriverDistantMetricTile(
                                      icon: Icons.description,
                                      label: "Initial Fare",
                                      value:
                                          "${originalFare.toStringAsFixed(0)} pesos",
                                    ),
                                    SizedBox(height: tileSpacing),
                                    _DriverDistantMetricTile(
                                      icon: Icons.add_circle,
                                      label: "Pickup Fare",
                                      value: "$pickupFee pesos",
                                    ),
                                    SizedBox(height: tileSpacing),
                                    _DriverDistantMetricTile(
                                      icon: Icons.warning,
                                      label: "New Fare",
                                      value: "$updatedFare pesos",
                                      containerColor: Colors.red,
                                    ),
                                    SizedBox(height: sectionSpacing),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _acknowledged = !_acknowledged;
                                });
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Center(
                                      child: Checkbox(
                                        value: _acknowledged,
                                        activeColor: Colors.red,
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
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "I'm aware the driver is distant and accept the additional fare voluntarily.",
                                      style: TextStyle(
                                        height: 1.35,
                                        fontSize: checkboxFontSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isCompact ? 14 : 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ActionButton(
                                    height: buttonHeight,
                                    text: "Cancel",
                                    mainColor:
                                        Colors.white.withValues(alpha: 0.12),
                                    borderColor:
                                        Colors.white.withValues(alpha: 0.4),
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
                                    height: buttonHeight,
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
                            SizedBox(height: bottomSpacing),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DriverDistantMetricTile extends StatelessWidget {
  const _DriverDistantMetricTile({
    this.icon,
    required this.label,
    required this.value,
    this.containerColor,
  });

  final IconData? icon;
  final String label;
  final String value;
  final Color? containerColor;

  @override
  Widget build(BuildContext context) {
    const effectiveAccentColor = Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor?.withValues(alpha: 0.14) ??
            Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: containerColor?.withValues(alpha: 0.22) ??
              Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: effectiveAccentColor.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Icon(
              icon,
              color: effectiveAccentColor,
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
                    color: effectiveAccentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    height: 1.05,
                    fontSize: 16,
                    color: effectiveAccentColor.withValues(alpha: 0.82),
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
