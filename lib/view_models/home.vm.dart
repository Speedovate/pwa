// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show SetOptions, Timestamp;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/chat.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/models/order.model.dart';
import 'package:pwa/view_models/gmap.vm.dart';
import 'package:pwa/view_models/load.vm.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/chat.service.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/models/chat.model.dart';
import 'package:pwa/models/coupon.model.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/requests/settings.request.dart';

class HomeViewModel extends GMapViewModel {
  final ValueNotifier<double?> driverDistantFareNotifier = ValueNotifier(0.0);
  bool? userSeen;
  Timer? dbTimer;
  int paymentId = 1;
  int providerRiderTypeId = 1;
  Coupon? appliedCoupon;
  Coupon? providerStaffCoupon;
  String? dvrMessage;
  String? lastStatus;
  String cancelRequestStatus = "";
  Order? ongoingOrder;
  Order? deliveredReceiptOrder;
  double rating = 5.0;
  int vehicleIndex = 0;
  bool snackShown = true;
  bool isDisabled = false;
  bool isPreparing = false;
  bool blockCamera = false;
  bool showAnalytics = false;
  bool isUpdatingRequestCancellation = false;
  bool isSendingQuickChat = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? partner;
  Map<String, dynamic>? order;
  VehicleType? selectedVehicle;
  Map<String, dynamic>? cHeaders;
  double driverPositionRotation = 0;
  List<VehicleType> vehicleTypes = [];
  StreamSubscription? userUpdateStream;
  StreamSubscription? partnerUpdateStream;
  StreamSubscription? orderUpdateStream;
  AuthRequest authRequest = AuthRequest();
  SettingsRequest settingsRequest = SettingsRequest();
  Future<void>? _initialOngoingOrderFuture;
  bool isResolvingInitialOngoingOrder = false;
  bool _isDraggingOngoingMap = false;
  bool _isRefreshingPartnerTodayAmount = false;
  bool _isSyncingDriverLocation = false;
  bool _isRefreshingOngoingOrderFromSignal = false;
  bool _hasPendingSignalRefresh = false;
  String? _pendingSignalRefreshReason;
  bool _pendingSignalRefreshForceStop = false;
  Timer? _delayedSignalRefreshTimer;
  bool _isShowingTerminalOrderDialog = false;
  bool _isHandlingCancelledOrderTransition = false;
  bool _shouldSuppressAutomaticPartnerDisplays = false;
  bool _isPollingOngoingOrderWithoutDriver = false;
  bool hasHydratedOngoingOrderMeta = false;
  bool _hasManualPaymentMethodOverride = false;
  double? _pendingStatusFareVisualOverride;
  double? _pendingBookingFareOverride;
  double? _pendingOngoingOrderFareOverride;
  String? _activeOrderStreamCode;
  String? _lastProcessedOrderSnapshotKey;
  String? _latestFirestoreDriverId;
  String? _latestFirestoreStatus;
  String? _latestFirestoreCancelRequestStatus;
  bool? _latestFirestoreUserSeen;
  String? _latestFirestoreDriverMessage;
  DateTime? _lastDriverSyncOrderRefreshAt;
  String? _driverLocationSyncOrderCode;
  String? _lastShownTerminalOrderDialogKey;
  gmaps.LatLng? _latestSyncedDriverLatLng;
  final TextEditingController promoCodeTEC = TextEditingController();

  void _tempCancelDebug(
    String label, {
    Map<String, Object?> details = const {},
  }) {
    debugPrint(
      "[TEMP_CANCEL_DEBUG] ${jsonEncode({
            "ts": DateTime.now().toIso8601String(),
            "label": label,
            "bookingId": bookingId,
            "ongoingOrderId": ongoingOrder?.id,
            "ongoingOrderCode": ongoingOrder?.code,
            "ongoingOrderStatus": ongoingOrder?.status,
            "ongoingOrderReason": ongoingOrder?.reason,
            "cancelledByWho": ongoingOrder?.cancelledByWho,
            "latestFirestoreStatus": _latestFirestoreStatus,
            "lastStatus": lastStatus,
            "isShowingTerminalOrderDialog": _isShowingTerminalOrderDialog,
            "isHandlingCancelledOrderTransition":
                _isHandlingCancelledOrderTransition,
            "lastShownTerminalOrderDialogKey": _lastShownTerminalOrderDialogKey,
            ...details,
          })}",
    );
  }

  String get currentBookingTypeLabel {
    if (!isBool(AuthService.currentUser?.isProvider)) {
      return "normal";
    }
    return providerRiderTypeId == 8 ? "staff" : "guest";
  }

  String orderBookingTypeLabel(Order? order) {
    if (order == null) {
      return "unknown";
    }
    if (order.appearsToBeProviderStaffFare) {
      return "staff";
    }
    if (order.appearsToBeProviderGuestFare) {
      return "guest";
    }
    if (order.isNormalBooking) {
      return "normal";
    }
    return "unknown";
  }

  bool isEnrouteOrBeyondStatus(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return [
      "enroute",
      "delivered",
      "completed",
      "successful",
      "cancelled",
    ].contains(normalized);
  }

  bool isCompletedReceiptStatus(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return [
      "delivered",
      "completed",
      "successful",
    ].contains(normalized);
  }

  Order? get completedReceiptOrder {
    if (_isValidCompletedReceiptOrder(ongoingOrder)) {
      return ongoingOrder;
    }
    if (_isValidCompletedReceiptOrder(deliveredReceiptOrder)) {
      return deliveredReceiptOrder;
    }
    return null;
  }

  bool get hasCompletedReceiptOrder => completedReceiptOrder != null;

  bool get shouldShowCompletedReceiptOverlay {
    final receiptOrder = completedReceiptOrder;
    return receiptOrder != null &&
        _isValidCompletedReceiptOrder(receiptOrder) &&
        receiptOrder.id == bookingId;
  }

  double _resolvedProviderGuestMarkupForHome(Order? order) {
    if (!isBool(AuthService.currentUser?.isProvider) || order == null) {
      return 0;
    }
    final orderMarkupAmount = order.resolvedMarkupAmount;
    if (orderMarkupAmount > 0) {
      return orderMarkupAmount;
    }
    if (order.appearsToBeProviderGuestFare) {
      return providerMarkupAmount > 0 ? providerMarkupAmount : 0;
    }
    return 0;
  }

  double resolvedProviderGuestMarkupForDisplay(Order? order) {
    return _resolvedProviderGuestMarkupForHome(order);
  }

  double resolvedVisibleOrderFareForDisplay(Order? order) {
    if (order == null) {
      return 0;
    }
    final guestMarkupAmount = resolvedProviderGuestMarkupForDisplay(order);
    return guestMarkupAmount > 0
        ? (order.total ?? 0) + guestMarkupAmount
        : (order.total ?? 0);
  }

  double get displayedCompletedReceiptFare {
    final receiptOrder = completedReceiptOrder;
    return resolvedVisibleOrderFareForDisplay(receiptOrder);
  }

  bool get hasAcceptedCancelRequest =>
      cancelRequestStatus.trim().toLowerCase() == "accepted";

  bool get hasDriverChatMessage {
    final message = (dvrMessage ?? "").trim().toLowerCase();
    return message.isNotEmpty && message != "null";
  }

  bool _isCancelRequestResolutionStatus(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    return normalized == "accepted" || normalized == "rejected";
  }

  bool _isCancelRequestResolutionMessage(String? message) {
    final normalized = (message ?? "").trim().toLowerCase();
    return normalized.contains("cancel request") &&
        (normalized.contains("has accepted") ||
            normalized.contains("has rejected"));
  }

  bool get isShowingTerminalOrderTransition =>
      _isHandlingCancelledOrderTransition || _isShowingTerminalOrderDialog;

  bool get shouldSuppressAutomaticPartnerDisplays =>
      _shouldSuppressAutomaticPartnerDisplays ||
      isShowingTerminalOrderTransition;

  Future<void> markCurrentOrderUserSeen({
    bool syncRemote = true,
  }) async {
    if (ongoingOrder == null) {
      return;
    }
    final orderCode = ongoingOrder?.code?.trim();
    if (syncRemote && orderCode != null && orderCode.isNotEmpty) {
      try {
        await fbStore.collection("orders").doc(orderCode).update(
          {
            "userSeen": true,
          },
        );
      } catch (_) {}
    }
    userSeen = true;
    _latestFirestoreUserSeen = true;
    notifyListeners();
  }

  String _normalizeOrderStatus(String? status) {
    final normalized = (status ?? "").trim().toLowerCase();
    switch (normalized) {
      case "ongoing":
        return "enroute";
      default:
        return normalized;
    }
  }

  bool _isMeaningfulOrderStatus(String? status) {
    final normalized = _normalizeOrderStatus(status);
    return normalized.isNotEmpty && normalized != "null";
  }

  bool _shouldAttemptCompletedReceiptRestoreFromFetchedNull(
    String previousOrderStatus,
  ) {
    final normalized = _normalizeOrderStatus(previousOrderStatus);
    if (bookingId == 0 || normalized.isEmpty || normalized == "null") {
      return false;
    }
    if (normalized == "cancelled" || normalized == "failed") {
      return false;
    }
    return true;
  }

  int _statusProgressRank(String? status) {
    switch (_normalizeOrderStatus(status)) {
      case "pending":
        return 1;
      case "preparing":
        return 2;
      case "ready":
        return 3;
      case "enroute":
        return 4;
      case "delivered":
      case "completed":
      case "successful":
        return 5;
      case "failed":
      case "cancelled":
        return 6;
      default:
        return 0;
    }
  }

  bool _shouldIgnoreFirestoreStatusRegression({
    required String currentStatus,
    required String nextStatus,
    bool allowRegression = false,
  }) {
    if (allowRegression) {
      return false;
    }
    if (!_isMeaningfulOrderStatus(currentStatus) ||
        !_isMeaningfulOrderStatus(nextStatus)) {
      return false;
    }
    if (nextStatus == "cancelled" || nextStatus == "failed") {
      return false;
    }
    return _statusProgressRank(nextStatus) < _statusProgressRank(currentStatus);
  }

  bool _shouldKeepFresherFirestoreStatusOverFetchedBackend({
    required String fetchedBackendStatus,
    required bool refresh,
    String? signalReason,
  }) {
    if (refresh || !_isMeaningfulOrderStatus(fetchedBackendStatus)) {
      return false;
    }
    final normalizedSignalReason = (signalReason ?? "").trim();
    final isFirestoreFollowUpRefresh = normalizedSignalReason ==
            "pending_status_changed" ||
        normalizedSignalReason == "pending_status_changed_delayed" ||
        normalizedSignalReason == "status_change_without_driver_change" ||
        normalizedSignalReason == "status_change_without_driver_change_delayed";
    if (!isFirestoreFollowUpRefresh) {
      return false;
    }
    if (fetchedBackendStatus == "cancelled" ||
        fetchedBackendStatus == "failed") {
      return false;
    }

    final latestSignalStatus = _normalizeOrderStatus(_latestFirestoreStatus);
    if (!_isMeaningfulOrderStatus(latestSignalStatus)) {
      return false;
    }
    if (latestSignalStatus == "cancelled" || latestSignalStatus == "failed") {
      return false;
    }

    return _statusProgressRank(latestSignalStatus) >
        _statusProgressRank(fetchedBackendStatus);
  }

  bool _isValidCompletedReceiptOrder(Order? order) {
    if (order == null || !isCompletedReceiptStatus(order.status)) {
      return false;
    }
    final pickupAddress = (order.taxiOrder?.pickupAddress ?? "").trim();
    final dropoffAddress = (order.taxiOrder?.dropoffAddress ?? "").trim();
    return order.id != null &&
        pickupAddress.isNotEmpty &&
        pickupAddress.toLowerCase() != "null" &&
        dropoffAddress.isNotEmpty &&
        dropoffAddress.toLowerCase() != "null" &&
        order.total != null &&
        order.paymentMethodId != null;
  }

  Map<String, Object?> debugCompletedReceiptOrderState(Order? order) {
    final pickupAddress = (order?.taxiOrder?.pickupAddress ?? "").trim();
    final dropoffAddress = (order?.taxiOrder?.dropoffAddress ?? "").trim();
    return {
      "id": order?.id,
      "status": order?.status,
      "normalizedStatus": _normalizeOrderStatus(order?.status),
      "isCompletedReceiptStatus": isCompletedReceiptStatus(order?.status),
      "pickupAddress": pickupAddress,
      "dropoffAddress": dropoffAddress,
      "hasPickupAddress":
          pickupAddress.isNotEmpty && pickupAddress.toLowerCase() != "null",
      "hasDropoffAddress":
          dropoffAddress.isNotEmpty && dropoffAddress.toLowerCase() != "null",
      "total": order?.total,
      "paymentMethodId": order?.paymentMethodId,
      "isValidCompletedReceiptOrder": _isValidCompletedReceiptOrder(order),
    };
  }

  void _cacheDeliveredReceiptOrderIfValid(Order? order) {
    if (_isValidCompletedReceiptOrder(order)) {
      deliveredReceiptOrder = order;
    }
  }

  void _resetTerminalDialogKeyForActiveNonTerminalOrder() {
    final activeOrderId = ongoingOrder?.id ?? bookingId;
    if (activeOrderId == 0) {
      return;
    }
    final status = _normalizeOrderStatus(ongoingOrder?.status);
    final isTerminalStatus = status == "cancelled" ||
        status == "failed" ||
        isCompletedReceiptStatus(status);
    if (isTerminalStatus) {
      return;
    }
    final expectedPrefix = "$activeOrderId|";
    if ((_lastShownTerminalOrderDialogKey ?? "").startsWith(expectedPrefix)) {
      _lastShownTerminalOrderDialogKey = null;
    }
  }

  Future<void> _refreshOngoingOrderFromSignal({
    required String reason,
    bool forceStop = false,
  }) async {
    if (_isRefreshingOngoingOrderFromSignal) {
      _hasPendingSignalRefresh = true;
      _pendingSignalRefreshReason = reason;
      _pendingSignalRefreshForceStop =
          _pendingSignalRefreshForceStop || forceStop;
      return;
    }
    _isRefreshingOngoingOrderFromSignal = true;
    try {
      await getOngoingOrder(
        forceStop: forceStop,
        signalReason: reason,
      );
    } finally {
      _isRefreshingOngoingOrderFromSignal = false;
      final shouldReplayPendingRefresh = _hasPendingSignalRefresh;
      final replayReason =
          _pendingSignalRefreshReason ?? "pending_signal_refresh";
      final replayForceStop = _pendingSignalRefreshForceStop;
      _hasPendingSignalRefresh = false;
      _pendingSignalRefreshReason = null;
      _pendingSignalRefreshForceStop = false;
      if (shouldReplayPendingRefresh) {
        await _refreshOngoingOrderFromSignal(
          reason: replayReason,
          forceStop: replayForceStop,
        );
      }
    }
  }

  void _scheduleDelayedSignalRefresh({
    required String reason,
    bool forceStop = false,
    Duration delay = const Duration(milliseconds: 1200),
  }) {
    final orderCode = (ongoingOrder?.code ?? "").trim();
    if (orderCode.isEmpty) {
      tempTimerDebug(
        "home.delayed_signal_refresh",
        "skip_missing_order_code",
        details: {
          "reason": reason,
          "forceStop": forceStop,
        },
      );
      return;
    }
    final instanceId = nextTempTimerInstanceId("home.delayed_signal_refresh");
    tempTimerDebug(
      "home.delayed_signal_refresh",
      "schedule",
      details: {
        "instanceId": instanceId,
        "reason": reason,
        "forceStop": forceStop,
        "delayMs": delay.inMilliseconds,
        "orderCode": orderCode,
      },
    );
    _cancelDelayedSignalRefreshTimer();
    _delayedSignalRefreshTimer = Timer(delay, () async {
      _delayedSignalRefreshTimer = null;
      final currentOrderCode = (ongoingOrder?.code ?? "").trim();
      if (currentOrderCode.isEmpty || currentOrderCode != orderCode) {
        tempTimerDebug(
          "home.delayed_signal_refresh",
          "fire_ignored_order_changed",
          details: {
            "instanceId": instanceId,
            "reason": reason,
            "scheduledOrderCode": orderCode,
            "currentOrderCode": currentOrderCode,
          },
        );
        return;
      }
      tempTimerDebug(
        "home.delayed_signal_refresh",
        "fire",
        details: {
          "instanceId": instanceId,
          "reason": reason,
          "forceStop": forceStop,
          "orderCode": orderCode,
        },
      );
      await _refreshOngoingOrderFromSignal(
        reason: "${reason}_delayed",
        forceStop: forceStop,
      );
    });
    if (_delayedSignalRefreshTimer != null) {
      attachTempTimerInstanceId(_delayedSignalRefreshTimer!, instanceId);
    }
  }

  void _cancelDelayedSignalRefreshTimer() {
    if (_delayedSignalRefreshTimer != null) {
      tempTimerDebug(
        "home.delayed_signal_refresh",
        "cancel",
        details: {
          "instanceId": tempTimerInstanceId(_delayedSignalRefreshTimer),
        },
      );
    }
    _delayedSignalRefreshTimer?.cancel();
    _delayedSignalRefreshTimer = null;
  }

  Future<bool> _restoreCompletedReceiptOrderForCurrentBooking() async {
    _cacheDeliveredReceiptOrderIfValid(ongoingOrder);
    if (_isValidCompletedReceiptOrder(deliveredReceiptOrder) &&
        deliveredReceiptOrder?.id == bookingId) {
      ongoingOrder = deliveredReceiptOrder;
      lastStatus = ongoingOrder?.status;
      return true;
    }
    try {
      final lastOrder = await taxiRequest.lastOrderRequest();
      if (_isValidCompletedReceiptOrder(lastOrder) &&
          lastOrder?.id == bookingId) {
        ongoingOrder = lastOrder;
        deliveredReceiptOrder = lastOrder;
        lastStatus = ongoingOrder?.status;
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool _isCancelledStatusMismatch({
    required String currentStatus,
    required String firestoreStatus,
  }) {
    return false;
  }

  bool _shouldTriggerOngoingOrderRefreshFromDriverSync({
    required String orderCode,
  }) {
    final hasActiveOrderStream =
        orderUpdateStream != null && _activeOrderStreamCode == orderCode;
    if (!hasActiveOrderStream) {
      return true;
    }
    final lastRefreshAt = _lastDriverSyncOrderRefreshAt;
    if (lastRefreshAt == null) {
      return true;
    }
    return DateTime.now().difference(lastRefreshAt) >=
        const Duration(seconds: 30);
  }

  bool get canCancelAfterWaitWithoutDriverChat =>
      !hasDriverChatMessage &&
      _remainingCancelSecondsForOrder(ongoingOrder) == 0 &&
      !isEnrouteOrBeyondStatus(ongoingOrder?.status);

  bool get canRebookAfterWaitWithoutDriverChat =>
      !hasDriverChatMessage &&
      _remainingRebookSecondsForOrder(ongoingOrder) == 0 &&
      !isEnrouteOrBeyondStatus(ongoingOrder?.status);

  bool get canCancelWithAcceptedRequest {
    if (!hasAcceptedCancelRequest) {
      return false;
    }
    final normalizedStatus = _normalizeOrderStatus(ongoingOrder?.status);
    return normalizedStatus != "cancelled" &&
        normalizedStatus != "failed" &&
        !isCompletedReceiptStatus(normalizedStatus);
  }

  int? get _driverSearchVehicleTypeId =>
      selectedVehicle?.id ??
      ongoingOrder?.driver?.vehicle?.vehicleType?.id ??
      ongoingOrder?.taxiOrder?.vehicleTypeId;

  double get _driverSearchPickupKmLimit =>
      selectedVehicle?.pickupKmLimit ??
      ongoingOrder?.driver?.vehicle?.vehicleType?.pickupKmLimit ??
      ongoingOrder?.taxiOrder?.vehicleType?.pickupKmLimit ??
      0.0;

  double get _driverDistantPayableFare {
    if (ongoingOrder != null) {
      return resolvedVisibleOrderFareForDisplay(ongoingOrder);
    }
    return totalAmountNotifier.value ?? total ?? selectedVehicle?.total ?? 0.0;
  }

  double get _driverDistantDialogBaseFare {
    final ongoingSubTotal = ongoingOrder?.subTotal ?? 0;
    if (ongoingSubTotal > 0) {
      return ongoingSubTotal;
    }
    return _driverDistantPayableFare;
  }

  double _resolvedDriverDistantDialogBaseFare() {
    if (ongoingOrder != null) {
      return _driverDistantDialogBaseFare;
    }
    if (isBool(AuthService.currentUser?.isProvider) &&
        providerRiderTypeId == 8 &&
        availableDriver != null) {
      final pickupDropoffSubtotal =
          availableDriver?.pickupDropoffSubtotal ?? selectedVehicle?.total ?? 0;
      final baseFare = pickupDropoffSubtotal +
          _providerBundleFee -
          _resolvedProviderStaffWholePesoDiscount(
            rawSubTotal: (selectedVehicle?.total ?? 0) + _providerBundleFee,
          );
      if (baseFare > 0) {
        return baseFare;
      }
    }
    return _driverDistantDialogBaseFare;
  }

  double get currentOngoingOrderPayableFare {
    return resolvedVisibleOrderFareForDisplay(ongoingOrder);
  }

  double get displayedPreBookingFare {
    if (selectedVehicle == null) {
      return _resolvedBookingPayableFare;
    }
    if (isBool(AuthService.currentUser?.isProvider) &&
        providerRiderTypeId == 8) {
      final providerBundleAdjustedSubTotal =
          (selectedVehicle?.total ?? 0) + _providerBundleFee;
      final displayFare = providerBundleAdjustedSubTotal -
          _resolvedProviderStaffWholePesoDiscount(
            rawSubTotal: providerBundleAdjustedSubTotal,
          );
      if (displayFare > 0) {
        return displayFare;
      }
    }
    return _resolvedBookingPayableFare;
  }

  double get displayedOngoingOrderPayableFare {
    final overrideFare = _pendingOngoingOrderFareOverride;
    if (overrideFare != null && overrideFare > currentOngoingOrderPayableFare) {
      return overrideFare;
    }
    return currentOngoingOrderPayableFare;
  }

  double get displayedPendingDriverOngoingOrderFare {
    if (ongoingOrder == null) {
      return displayedOngoingOrderPayableFare;
    }
    if (!_isPendingWithoutDriverFareOverrideStatus(ongoingOrder?.status)) {
      return displayedOngoingOrderPayableFare;
    }
    final pendingOverrideFare = _pendingStatusFareVisualOverride;
    if (pendingOverrideFare != null && pendingOverrideFare > 0) {
      final payableFare = displayedOngoingOrderPayableFare;
      return payableFare > pendingOverrideFare
          ? payableFare
          : pendingOverrideFare;
    }
    final bookingOverrideFare = _pendingBookingFareOverride;
    if (bookingOverrideFare != null && bookingOverrideFare > 0) {
      final payableFare = displayedOngoingOrderPayableFare;
      return payableFare > bookingOverrideFare
          ? payableFare
          : bookingOverrideFare;
    }
    final payableFare = displayedOngoingOrderPayableFare;
    if (payableFare > 0) {
      return payableFare;
    }
    final localTotal = total ?? 0;
    return localTotal;
  }

  bool _isPendingWithoutDriverFareOverrideStatus(String? status) {
    final normalized = _normalizeOrderStatus(status);
    return normalized == "pending" || normalized == "preparing";
  }

  bool _shouldWriteProviderGuestMarkupToFirestore() {
    if (!isBool(AuthService.currentUser?.isProvider)) {
      return false;
    }
    final order = ongoingOrder;
    if (order == null) {
      return false;
    }
    if (order.appearsToBeProviderStaffFare) {
      return false;
    }
    if (order.appearsToBeProviderGuestFare) {
      return providerMarkupAmount > 0;
    }
    return false;
  }

  bool get _hasAssignedOngoingDriver {
    final order = ongoingOrder;
    if (order == null) {
      return false;
    }
    if (order.driver != null) {
      return true;
    }
    final driverId = "${order.driverId ?? ""}".trim();
    return driverId.isNotEmpty && driverId.toLowerCase() != "null";
  }

  gmaps.LatLng? get _assignedDriverLatLngOrNull {
    if (!_hasAssignedOngoingDriver) {
      return null;
    }
    final syncedDriverLatLng = _latestSyncedDriverLatLng;
    if (syncedDriverLatLng != null &&
        (syncedDriverLatLng.lat != 0 || syncedDriverLatLng.lng != 0)) {
      return syncedDriverLatLng;
    }
    final orderDriverLatLng = ongoingOrder?.driverLatLng;
    if (orderDriverLatLng == null ||
        (orderDriverLatLng.lat == 0 && orderDriverLatLng.lng == 0)) {
      return null;
    }
    return orderDriverLatLng;
  }

  void _syncDriverDistantFareNotifier() {
    final nextFare = _driverDistantPayableFare;
    if (driverDistantFareNotifier.value == nextFare) {
      return;
    }
    driverDistantFareNotifier.value = nextFare;
  }

  double _resolvedDriverDistantPickupFee({
    Order? order,
  }) {
    final rawPickupFee = availableDriver?.pickupChargeFee ?? 0;
    if (rawPickupFee <= 0) {
      return 0;
    }
    final appliedPickupFee = rawPickupFee.ceilToDouble();
    return appliedPickupFee;
  }

  double _resolvedProviderStaffWholePesoDiscount({
    required double rawSubTotal,
  }) {
    if (!isBool(AuthService.currentUser?.isProvider) ||
        providerRiderTypeId != 8) {
      return discount ?? 0;
    }
    final coupon = providerStaffCoupon;
    if (coupon == null || rawSubTotal <= 0) {
      return 0;
    }
    try {
      final validatedDiscount = _resolveCouponDiscountAmount(
        coupon,
        rawSubTotal,
      );
      return _normalizeWholePeso(validatedDiscount);
    } catch (_) {
      return _normalizeWholePeso(discount ?? 0);
    }
  }

  double _resolveAcceptedDriverDistantBookingFare(double pickupFee) {
    if (pickupFee <= 0) {
      return 0;
    }
    if (isBool(AuthService.currentUser?.isProvider) &&
        providerRiderTypeId == 8) {
      final driverTotal = availableDriver?.total ?? 0;
      if (driverTotal > 0) {
        final acceptedFare = driverTotal +
            _providerBundleFee -
            _resolvedProviderStaffWholePesoDiscount(
              rawSubTotal: (selectedVehicle?.total ?? 0) + _providerBundleFee,
            );
        return acceptedFare > 0 ? acceptedFare : 0;
      }
    }
    return _driverDistantPayableFare + pickupFee;
  }

  void _applyPendingDriverDistantFareOverride() {
    if (ongoingOrder == null || availableDriver == null) {
      return;
    }
    final pickupFee = _resolvedDriverDistantPickupFee(
      order: ongoingOrder,
    );
    if (pickupFee <= 0) {
      return;
    }
    _pendingOngoingOrderFareOverride = _driverDistantDialogBaseFare + pickupFee;
    _applyPendingDriverDistantFareToOngoingOrder();
    notifyListeners();
  }

  void _applyAcceptedDriverDistantFareToBookingTotal() {
    if (ongoingOrder != null || availableDriver == null) {
      return;
    }
    final pickupFee = _resolvedDriverDistantPickupFee();
    if (pickupFee <= 0) {
      return;
    }
    final acceptedFare = _resolveAcceptedDriverDistantBookingFare(pickupFee);
    if (acceptedFare <= 0) {
      return;
    }
    _pendingStatusFareVisualOverride = acceptedFare;
    _pendingBookingFareOverride = acceptedFare;
    total = acceptedFare;
    if (!isBool(AuthService.currentUser?.isProvider)) {
      selectedVehicle?.total = acceptedFare;
      subTotal = acceptedFare;
    }
    syncTotalAmountNotifier();
    _syncDriverDistantFareNotifier();
    notifyListeners();
  }

  Future<void> _applyDriverAssignmentFromFirestore(String nextDriverId) async {
    final parsedDriverId = int.tryParse(nextDriverId);
    if (parsedDriverId == null || ongoingOrder == null) {
      return;
    }
    ongoingOrder?.driverId = parsedDriverId;
    if (ongoingOrder?.driver?.id == parsedDriverId) {
      return;
    }
    _latestSyncedDriverLatLng = null;
    driverPositionRotation = 0;

    try {
      final driver = await taxiRequest.getDriverInfo(parsedDriverId);
      final latestFirestoreDriverId = (_latestFirestoreDriverId ?? "").trim();
      final currentOrderCode = (ongoingOrder?.code ?? "").trim();
      if (ongoingOrder == null ||
          currentOrderCode.isEmpty ||
          latestFirestoreDriverId != nextDriverId) {
        return;
      }
      ongoingOrder?.driver = driver;
      ongoingOrder?.driverId = driver.id ?? parsedDriverId;
      _latestSyncedDriverLatLng = driver.latLng;
      driverPositionRotation = 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _reconcileOrderWithLatestFirestoreState({
    required String nextOrderCode,
    bool preferBackendStatus = false,
  }) async {
    if (ongoingOrder == null) {
      return;
    }

    final currentCode = (ongoingOrder?.code ?? "").trim();
    if (currentCode.isEmpty || currentCode != nextOrderCode) {
      return;
    }

    final firestoreStatus = _normalizeOrderStatus(_latestFirestoreStatus);
    final firestoreDriverId = (_latestFirestoreDriverId ?? "").trim();
    final currentDriverId =
        "${ongoingOrder?.driverId ?? ongoingOrder?.driver?.id ?? ""}".trim();
    final hasFirestoreDriverAssignmentChange = firestoreDriverId.isNotEmpty &&
        firestoreDriverId.toLowerCase() != "null" &&
        firestoreDriverId != currentDriverId;
    if (_isMeaningfulOrderStatus(firestoreStatus)) {
      final currentStatus = _normalizeOrderStatus(ongoingOrder?.status);
      final shouldIgnoreStatusRegression =
          _shouldIgnoreFirestoreStatusRegression(
        currentStatus: currentStatus,
        nextStatus: firestoreStatus,
        allowRegression: hasFirestoreDriverAssignmentChange,
      );
      final shouldApplyFirestoreTerminalStatus =
          firestoreStatus == "cancelled" || firestoreStatus == "failed";
      if (_isCancelledStatusMismatch(
        currentStatus: currentStatus,
        firestoreStatus: firestoreStatus,
      )) {
      } else if (preferBackendStatus && !shouldApplyFirestoreTerminalStatus) {
      } else if (shouldIgnoreStatusRegression) {
      } else {
        ongoingOrder?.status = firestoreStatus;
      }
    }
    if (firestoreDriverId.isNotEmpty &&
        firestoreDriverId.toLowerCase() != "null" &&
        firestoreDriverId != currentDriverId) {
      await _applyDriverAssignmentFromFirestore(firestoreDriverId);
    }
  }

  void _reapplyPendingDriverDistantBookingFareOverride() {
    final overrideFare = _pendingBookingFareOverride;
    if (overrideFare == null) {
      return;
    }
    if (ongoingOrder != null) {
      _pendingBookingFareOverride = null;
      return;
    }
    if (overrideFare <= 0) {
      _pendingBookingFareOverride = null;
      return;
    }
    if ((total ?? 0) < overrideFare) {
      total = overrideFare;
    }
  }

  double get _resolvedBookingPayableFare {
    return _pendingBookingFareOverride ??
        totalAmountNotifier.value ??
        total ??
        selectedVehicle?.total ??
        0.0;
  }

  void _applyPendingDriverDistantFareToOngoingOrder() {
    final overrideFare = _pendingOngoingOrderFareOverride;
    if (ongoingOrder == null || overrideFare == null) {
      return;
    }
    final hasOrderSubTotal = (ongoingOrder?.subTotal ?? 0) > 0;
    final guestMarkupAmount = _resolvedProviderGuestMarkupForHome(ongoingOrder);
    final normalizedTotal = hasOrderSubTotal
        ? overrideFare
        : guestMarkupAmount > 0
            ? overrideFare - guestMarkupAmount
            : overrideFare;
    if (normalizedTotal <= 0) {
      return;
    }
    if ((ongoingOrder?.total ?? 0) < normalizedTotal) {
      ongoingOrder?.total = normalizedTotal;
    }
  }

  void _reconcilePendingOngoingOrderFareOverride() {
    final overrideFare = _pendingOngoingOrderFareOverride;
    if (overrideFare == null) {
      return;
    }
    if (ongoingOrder == null ||
        (ongoingOrder?.status ?? "").trim().toLowerCase() == "cancelled") {
      _pendingOngoingOrderFareOverride = null;
      return;
    }
    if (ongoingOrder?.driver == null &&
        _isPendingWithoutDriverFareOverrideStatus(ongoingOrder?.status)) {
      return;
    }
    if (currentOngoingOrderPayableFare >= overrideFare) {
      _pendingOngoingOrderFareOverride = null;
    }
  }

  void _reconcilePendingStatusFareVisualOverride() {
    final overrideFare = _pendingStatusFareVisualOverride;
    if (overrideFare == null) {
      return;
    }
    if (ongoingOrder == null ||
        !_isPendingWithoutDriverFareOverrideStatus(ongoingOrder?.status)) {
      _pendingStatusFareVisualOverride = null;
      return;
    }
    if (displayedOngoingOrderPayableFare >= overrideFare) {
      _pendingStatusFareVisualOverride = null;
    }
  }

  bool get canOpenCancelFlow =>
      canCancelWithAcceptedRequest ||
      canCancelAfterWaitWithoutDriverChat ||
      canRebookAfterWaitWithoutDriverChat;

  bool get isOngoingOrderStatusUncertain {
    if (isResolvingInitialOngoingOrder) {
      return true;
    }
    if (ongoingOrder == null) {
      return false;
    }
    final code = (ongoingOrder?.code ?? "").trim();
    final status = (ongoingOrder?.status ?? "").trim().toLowerCase();
    final hasStableOrderIdentity = code.isNotEmpty;
    final hasStableStatus = status.isNotEmpty && status != "null";
    if (!hasHydratedOngoingOrderMeta) {
      return !(hasStableOrderIdentity && hasStableStatus);
    }
    return status.isEmpty || status == "null";
  }

  @override
  bool get shouldSkipInitialMapCameraMove =>
      isResolvingInitialOngoingOrder || ongoingOrder != null;

  @override
  bool get shouldAutoFitMapToRoute => !_isDraggingOngoingMap;

  void setDraggingOngoingMap(bool value) {
    if (_isDraggingOngoingMap == value) {
      return;
    }
    _isDraggingOngoingMap = value;
  }

  Future<void> ensureInitialOngoingOrderLoaded({
    bool forceRefresh = false,
  }) async {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    final hasOngoingOrder = ongoingOrder != null;
    if (forceRefresh ||
        (!hasOngoingOrder && _initialOngoingOrderFuture != null)) {
      _initialOngoingOrderFuture = null;
    }
    _initialOngoingOrderFuture ??= _resolveInitialOngoingOrder();
    await _initialOngoingOrderFuture;
    if (ongoingOrder != null && orderUpdateStream == null) {
      await startHandlingOngoingOrder(forceStop: true);
    }
  }

  Future<void> _resolveInitialOngoingOrder() async {
    isResolvingInitialOngoingOrder = true;
    notifyListeners();
    try {
      await getOngoingOrder();
    } finally {
      isResolvingInitialOngoingOrder = false;
      if (ongoingOrder == null) {
        startInitialMapCameraMoveIfNeeded();
      }
      notifyListeners();
    }
  }

  initialise() async {
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ??
        !AuthService.isLoggedIn();
    isAd1Seen = StorageService.prefs?.getBool("is_ad_1_seen") ??
        !AuthService.isLoggedIn();
    if (isBool(AuthService.currentUser?.isProvider)) {
      paymentId = providerPaymentId;
    }
    notifyListeners();
    if (AuthService.isLoggedIn()) {
      if (ongoingOrder == null) {
        ensureInitialOngoingOrderLoaded();
      }
      await LoadViewModel().getLoadBalance();
      syncAutomaticPaymentMethodForCurrentBooking();
      startListeningToUser();
      startListeningToPartner();
      try {
        final userDoc = await fbStore
            .collection(
              "users",
            )
            .doc(AuthService.currentUser?.id.toString())
            .get();
        final docRef = userDoc.reference;
        if (userDoc.data() == null) {
          docRef.set(
            {
              "id": AuthService.currentUser?.id,
            },
          );
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  Future<void> recenterHomeMap({
    gmaps.LatLng? fallbackTarget,
    bool allowSinglePointFit = true,
  }) async {
    cancelPendingCameraMove();
    setDraggingOngoingMap(false);
    final status = (ongoingOrder?.status ?? "").toLowerCase();
    final pickupLatLng = ongoingOrder?.taxiOrder?.pickupLatLng;
    final dropoffLatLng = ongoingOrder?.taxiOrder?.dropoffLatLng;
    final driverLatLng = _assignedDriverLatLngOrNull;

    if (ongoingOrder != null &&
        status != "cancelled" &&
        status != "delivered" &&
        pickupLatLng != null) {
      if (_fitOngoingOrderBoundsByStatus(
        status: status,
        pickupLatLng: pickupLatLng,
        dropoffLatLng: dropoffLatLng,
        driverLatLng: driverLatLng,
      )) {
        return;
      }
    }

    final hasPickupOnlySelection = ongoingOrder == null &&
        pickupAddress != null &&
        dropoffAddress == null &&
        fallbackTarget == null;
    final effectiveAllowSinglePointFit =
        hasPickupOnlySelection ? false : allowSinglePointFit;

    await super.recenterHomeMap(
      fallbackTarget: fallbackTarget,
      allowSinglePointFit: effectiveAllowSinglePointFit,
    );
  }

  bool _fitOngoingOrderBoundsByStatus({
    required String status,
    required gmaps.LatLng pickupLatLng,
    gmaps.LatLng? dropoffLatLng,
    gmaps.LatLng? driverLatLng,
    EdgeInsets? padding,
  }) {
    final controller = map;
    if (controller == null) {
      return false;
    }
    final effectivePadding = padding ?? routeBoundsPadding;

    final points = <gmaps.LatLng>[];
    if ((status == "pending" || status == "preparing" || status == "ready") &&
        driverLatLng != null) {
      points.add(driverLatLng);
      points.add(pickupLatLng);
    } else if (status == "enroute" && dropoffLatLng != null) {
      points.add(pickupLatLng);
      points.add(dropoffLatLng);
    } else {
      if (pickupLatLng.lat != 0 || pickupLatLng.lng != 0) {
        points.add(pickupLatLng);
      }
      if (dropoffLatLng != null &&
          (dropoffLatLng.lat != 0 || dropoffLatLng.lng != 0)) {
        points.add(dropoffLatLng);
      }
      if (driverLatLng != null &&
          (driverLatLng.lat != 0 || driverLatLng.lng != 0)) {
        points.add(driverLatLng);
      }
    }

    final uniquePoints = <String, gmaps.LatLng>{};
    for (final point in points) {
      uniquePoints["${point.lat},${point.lng}"] = point;
    }
    final targetPoints = uniquePoints.values.toList();
    if (targetPoints.isEmpty) {
      return false;
    }

    ignoreCameraMovesFor(
      const Duration(milliseconds: 1200),
    );
    if (targetPoints.length == 1) {
      controller.recenter(
        targetPoints.first,
        zoom: 16,
      );
    } else {
      controller.fitToCoordinates(
        targetPoints,
        padding: effectivePadding,
      );
    }
    return true;
  }

  void _centerOngoingOrderForStatusChange() {
    final order = ongoingOrder;
    final pickupLatLng = order?.taxiOrder?.pickupLatLng;
    if (order == null || pickupLatLng == null) {
      return;
    }
    setDraggingOngoingMap(false);
    _fitOngoingOrderBoundsByStatus(
      status: (order.status ?? "").toLowerCase(),
      pickupLatLng: pickupLatLng,
      dropoffLatLng: order.taxiOrder?.dropoffLatLng,
      driverLatLng: _assignedDriverLatLngOrNull,
      padding: routeBoundsPadding,
    );
  }

  Future<void> _resetAndRedrawMapForDriverChange({
    bool forceStop = false,
  }) async {
    clearGMapDetails();
    lastStatus = null;
    _latestSyncedDriverLatLng = null;
    driverPositionRotation = 0;
    notifyListeners();
    await loadUIByOngoingOrderStatus(
      forceStop: forceStop,
      forceRedraw: true,
    );
  }

  void resetUnavailableLocationState() {
    resetManualPaymentMethodOverride();
    clearGMapDetails();
    pickupAddress = null;
    dropoffAddress = null;
    selectedVehicle = null;
    vehicleTypes = [];
    appliedCoupon = null;
    promoCodeTEC.clear();
    _pendingStatusFareVisualOverride = null;
    _pendingBookingFareOverride = null;
    total = 0;
    subTotal = 0;
    discount = 0;
    syncTotalAmountNotifier();
    _syncDriverDistantFareNotifier();
    locUnavailable = false;
    clearPickupDisplayState();
    restorePickupDisplay();
    notifyListeners();
  }

  Future<void> _showDriverDistantDialog({
    VoidCallback? onAccept,
  }) async {
    if (availableDriver == null || total == null) {
      return;
    }
    _syncDriverDistantFareNotifier();
    final displayedPickupFee = _resolvedDriverDistantPickupFee(
      order: ongoingOrder,
    );
    final displayedBaseFare = _resolvedDriverDistantDialogBaseFare();
    await AlertService().showDriverDistantDialog(
      availableDriver: availableDriver!,
      totalAmountListenable: driverDistantFareNotifier,
      originalFare: displayedBaseFare,
      newBaseFare: displayedBaseFare,
      displayedPickupFee: displayedPickupFee,
      onAccept: () async {
        _applyAcceptedDriverDistantFareToBookingTotal();
        _applyPendingDriverDistantFareOverride();
        if (onAccept != null) {
          onAccept();
        } else {
          await placeNewOrder();
        }
      },
    );
  }

  Future<void> _restoreCancelledBookingRoutePreview() async {
    if (pickupAddress == null || dropoffAddress == null) {
      return;
    }
    isPreparing = true;
    notifyListeners();
    unawaited(fetchVehicleTypesPricing());
    await drawDropPolyLines(
      "pickup-dropoff",
      pickupAddress!.latLng,
      dropoffAddress!.latLng,
      null,
      autoFitMap: true,
      autoFitAnimated: true,
    );
    fitCurrentRouteBounds(
      padding: routeBoundsPadding,
      animated: true,
      allowSinglePointFit: false,
    );
    isPreparing = false;
    notifyListeners();
  }

  Future<void> _showTerminalOrderDialogOnce({
    required Order? order,
    required String terminalDialogType,
    required String reason,
  }) async {
    final resolvedOrderId = order?.id ?? bookingId;
    final dialogKey = "$resolvedOrderId|$terminalDialogType";
    _tempCancelDebug(
      "ShowTerminalOrderDialogAttempt",
      details: {
        "dialogKey": dialogKey,
        "terminalDialogType": terminalDialogType,
        "reason": reason,
        "isChatViewOpen": isChatViewOpen,
      },
    );

    if (_lastShownTerminalOrderDialogKey == dialogKey ||
        _isShowingTerminalOrderDialog) {
      _tempCancelDebug(
        "ShowTerminalOrderDialogSkipped",
        details: {
          "dialogKey": dialogKey,
          "terminalDialogType": terminalDialogType,
          "reason": reason,
        },
      );
      return;
    }

    _lastShownTerminalOrderDialogKey = dialogKey;
    _shouldSuppressAutomaticPartnerDisplays = true;
    _isShowingTerminalOrderDialog = true;

    if (!isChatViewOpen) {
      Get.until((route) => route.isFirst);
    }

    try {
      _tempCancelDebug(
        "ShowTerminalOrderDialogStart",
        details: {
          "dialogKey": dialogKey,
          "terminalDialogType": terminalDialogType,
          "reason": reason,
        },
      );
      await AlertService().showAppAlert(
        dismissible: false,
        title: "Booking ${reason == "pass" ? "Passed" : "Cancelled"}",
        asset: reason == "pass" ? AppLotties.success : AppLotties.error,
        content:
            "Your booking has been ${reason == "pass" ? "passed" : "cancelled"}",
        confirmAction: () async {
          _tempCancelDebug(
            "ShowTerminalOrderDialogConfirm",
            details: {
              "dialogKey": dialogKey,
              "terminalDialogType": terminalDialogType,
              "reason": reason,
            },
          );
          Navigator.of(Get.context!, rootNavigator: true).pop();
          if (isChatViewOpen) {
            Future.microtask(() {
              Navigator.of(Get.context!, rootNavigator: true).popUntil(
                (route) => route.isFirst,
              );
            });
          }
        },
      );
    } finally {
      _isShowingTerminalOrderDialog = false;
      _tempCancelDebug(
        "ShowTerminalOrderDialogEnd",
        details: {
          "dialogKey": dialogKey,
          "terminalDialogType": terminalDialogType,
          "reason": reason,
        },
      );
    }
  }

  Future<void> _handleCancelledOrderState(
    Order? cancelledOrder,
  ) async {
    _tempCancelDebug(
      "HandleCancelledOrderStateStart",
      details: {
        "inputCancelledOrderId": cancelledOrder?.id,
        "inputCancelledOrderCode": cancelledOrder?.code,
        "inputCancelledOrderStatus": cancelledOrder?.status,
        "inputCancelledOrderReason": cancelledOrder?.reason,
        "inputCancelledOrderCancelledByWho": cancelledOrder?.cancelledByWho,
      },
    );
    if (_isHandlingCancelledOrderTransition) {
      _tempCancelDebug("HandleCancelledOrderStateSkippedAlreadyHandling");
      return;
    }
    _isHandlingCancelledOrderTransition = true;
    _shouldSuppressAutomaticPartnerDisplays = true;

    final reason = (cancelledOrder?.reason ?? "").toLowerCase();
    final shouldRestorePreview = reason != "rebook";
    final shouldShowAlert = reason != "rebook";

    try {
      _tempCancelDebug(
        "HandleCancelledOrderStateDecision",
        details: {
          "reason": reason,
          "shouldRestorePreview": shouldRestorePreview,
          "shouldShowAlert": shouldShowAlert,
        },
      );
      if (shouldShowAlert) {
        await _showTerminalOrderDialogOnce(
          order: cancelledOrder,
          terminalDialogType: reason == "pass" ? "passed" : "cancelled",
          reason: reason,
        );
      }

      cHeaders = null;
      ongoingOrder = null;
      bookingId = 0;
      snackShown = true;
      notifyListeners();
      stopAllListeners();
      _tempCancelDebug("HandleCancelledOrderStateAfterReset");

      if (shouldRestorePreview) {
        await _restoreCancelledBookingRoutePreview();
      }
    } finally {
      _isHandlingCancelledOrderTransition = false;
      _tempCancelDebug("HandleCancelledOrderStateEnd");
    }
  }

  double _normalizeWholePeso(double value) {
    return value.floorToDouble();
  }

  double get _providerBundleFee => 20.0;

  String get paymentMethodLabel => paymentId == 1 ? "Cash" : "Load";

  String get promoSelectionLabel {
    if (isBool(AuthService.currentUser?.isProvider)) {
      return providerRiderTypeId == 8 ? "Staff" : "Guest";
    }
    final coupon = appliedCoupon;
    if (coupon == null) {
      return "Code";
    }
    if (coupon.usesPercentageDiscount) {
      return "${coupon.discountValue.toStringAsFixed(0)}% OFF";
    }
    if (coupon.discountValue > 0) {
      return "Promo On";
    }
    final code = (coupon.code ?? "").trim();
    return code.isEmpty ? "Promo On" : code.toUpperCase();
  }

  void applyPaymentMethodSelection(int nextPaymentId) {
    if (isBool(AuthService.currentUser?.isProvider)) {
      syncProviderPaymentMode();
      notifyListeners();
      return;
    }
    if (paymentId == nextPaymentId) {
      return;
    }
    _hasManualPaymentMethodOverride = true;
    paymentId = nextPaymentId;
    calculateTotalAmount();
  }

  bool syncAutomaticPaymentMethodForCurrentBooking({
    bool notify = true,
  }) {
    if (!AuthService.isLoggedIn() ||
        isBool(AuthService.currentUser?.isProvider) ||
        ongoingOrder != null ||
        pickupAddress == null ||
        dropoffAddress == null ||
        selectedVehicle == null) {
      return false;
    }

    if (_hasManualPaymentMethodOverride) {
      return false;
    }

    final bookingFare = _resolvedBookingPayableFare;
    if (bookingFare <= 0) {
      return false;
    }

    final availableLoad = gLoad?.balance ?? 0;
    final nextPaymentId = availableLoad >= bookingFare ? 8 : 1;
    if (paymentId == nextPaymentId) {
      return false;
    }

    paymentId = nextPaymentId;
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  void resetManualPaymentMethodOverride() {
    _hasManualPaymentMethodOverride = false;
  }

  Future<void> applyPromoCode(
    String rawCode, {
    bool notify = true,
  }) async {
    final resolvedPromo = await resolvePromoCode(rawCode);
    applyResolvedPromoCode(
      resolvedPromo.coupon,
      resolvedPromo.code,
      notify: notify,
    );
  }

  Future<({Coupon coupon, String code})> resolvePromoCode(
      String rawCode) async {
    if (isBool(AuthService.currentUser?.isProvider)) {
      throw "Promo codes are not available for provider bookings";
    }
    final code = rawCode.trim();
    if (code.isEmpty) {
      throw "Please enter a promo code";
    }
    final coupon = await taxiRequest.coupon(code);
    if (!(coupon.isActive ?? false)) {
      throw "Promo is inactive";
    }
    if ((coupon.useLeft ?? 0) <= 0) {
      throw "Promo use limit exceeded";
    }
    if (coupon.isExpired) {
      throw "Promo has expired";
    }

    if (pickupAddress == null) {
      throw "Please set your pickup address";
    }
    if (dropoffAddress == null) {
      throw "Please set your dropoff address";
    }
    if ((pickupAddress?.latLng == dropoffAddress?.latLng ||
            travelTime(selectedVehicle?.kmDistance ?? 0) == "0 secs") &&
        !AuthService.inReviewMode()) {
      throw locUnavailable
          ? "Please try another location"
          : "Pickup and dropoff must differ";
    }
    if (selectedVehicle == null) {
      throw locUnavailable
          ? "Please try another location"
          : "Please select a vehicle";
    }

    final rawSubTotal = selectedVehicle?.total ?? 0;
    if (rawSubTotal > 0) {
      double estimatedDiscount;
      if (coupon.usesPercentageDiscount) {
        estimatedDiscount = rawSubTotal * (coupon.discountValue / 100);
      } else {
        estimatedDiscount = coupon.discountValue;
      }
      coupon.validateDiscount(rawSubTotal, estimatedDiscount);
    }

    return (coupon: coupon, code: code);
  }

  void applyResolvedPromoCode(
    Coupon coupon,
    String code, {
    bool notify = true,
  }) {
    appliedCoupon = coupon;
    promoCodeTEC.text = code.toUpperCase();
    calculateTotalAmount(notify: notify);
  }

  void clearAppliedPromo() {
    if (appliedCoupon == null && promoCodeTEC.text.isEmpty) {
      return;
    }
    appliedCoupon = null;
    promoCodeTEC.clear();
    calculateTotalAmount();
  }

  bool _isProviderStaffCouponCode(String? code) {
    final normalized = (code ?? "").trim().toLowerCase();
    return normalized == "staff";
  }

  double _resolveCouponDiscountAmount(
    Coupon coupon,
    double rawSubTotal,
  ) {
    final rawDiscount = coupon.usesPercentageDiscount
        ? rawSubTotal * (coupon.discountValue / 100)
        : coupon.discountValue;
    return coupon.validateDiscount(rawSubTotal, rawDiscount);
  }

  Future<void> _ensureProviderStaffCoupon({
    bool showErrorOnFailure = false,
  }) async {
    if (!isBool(AuthService.currentUser?.isProvider) ||
        providerRiderTypeId != 8) {
      return;
    }
    final cachedCoupon = providerStaffCoupon;
    if (cachedCoupon != null &&
        _isProviderStaffCouponCode(cachedCoupon.code) &&
        cachedCoupon.isValid) {
      return;
    }
    try {
      final coupon = await taxiRequest.coupon("STAFF");
      if (!(coupon.isActive ?? false)) {
        throw "STAFF promo is inactive";
      }
      if ((coupon.useLeft ?? 0) <= 0) {
        throw "STAFF promo use limit exceeded";
      }
      if (coupon.isExpired) {
        throw "STAFF promo has expired";
      }
      providerStaffCoupon = coupon;
      calculateTotalAmount();
    } catch (e) {
      providerStaffCoupon = null;
      if (showErrorOnFailure) {
        showError(e.toString());
      }
    }
  }

  calculateTotalAmount({
    bool notify = true,
  }) {
    final rawSubTotal = selectedVehicle?.total ?? 0;
    final providerBundleAdjustedSubTotal = rawSubTotal + _providerBundleFee;
    if (isBool(AuthService.currentUser?.isProvider)) {
      subTotal = providerBundleAdjustedSubTotal;
      if (providerRiderTypeId == 8) {
        final coupon = providerStaffCoupon;
        double nextDiscount = 0;
        if (providerBundleAdjustedSubTotal > 0 && coupon != null) {
          try {
            nextDiscount = _resolvedProviderStaffWholePesoDiscount(
              rawSubTotal: providerBundleAdjustedSubTotal,
            );
          } catch (_) {
            providerStaffCoupon = null;
            nextDiscount = 0;
            unawaited(_ensureProviderStaffCoupon());
          }
        } else if (providerBundleAdjustedSubTotal > 0) {
          unawaited(_ensureProviderStaffCoupon());
        }
        discount = nextDiscount;
        total = _normalizeWholePeso(
          providerBundleAdjustedSubTotal - (discount ?? 0),
        );
      } else {
        discount = 0;
        total = _normalizeWholePeso(
          providerBundleAdjustedSubTotal + providerMarkupAmount,
        );
      }
    } else {
      subTotal = rawSubTotal;
      var nextDiscount = 0.0;
      final coupon = appliedCoupon;
      if (rawSubTotal <= 0) {
        discount = 0;
        total = 0;
        _reapplyPendingDriverDistantBookingFareOverride();
        syncTotalAmountNotifier();
        _syncDriverDistantFareNotifier();
        if (notify) {
          notifyListeners();
        }
        return;
      }
      if (coupon != null) {
        try {
          final rawDiscount = coupon.usesPercentageDiscount
              ? rawSubTotal * (coupon.discountValue / 100)
              : coupon.discountValue;
          nextDiscount = coupon.validateDiscount(rawSubTotal, rawDiscount);
        } catch (_) {
          appliedCoupon = null;
          promoCodeTEC.clear();
          nextDiscount = 0.0;
        }
      }
      discount = nextDiscount;
      total = rawSubTotal - nextDiscount;
      if ((total ?? 0) < 0) {
        total = 0;
      }
    }
    _reapplyPendingDriverDistantBookingFareOverride();
    syncAutomaticPaymentMethodForCurrentBooking(
      notify: false,
    );
    syncTotalAmountNotifier();
    _syncDriverDistantFareNotifier();
    if (notify) {
      notifyListeners();
    }
  }

  double get providerMarkupAmount {
    final value = partner?["markup_amount"] ?? user?["markup_amount"] ?? 0;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse("$value") ?? 0;
  }

  double get providerTodayAmount {
    final value = user?["today_amount"] ?? partner?["today_amount"] ?? 0;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse("$value") ?? 0;
  }

  double get providerMonthAmount {
    final value = user?["month_amount"] ?? partner?["month_amount"] ?? 0;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse("$value") ?? 0;
  }

  double get providerTotalAmount {
    final value = user?["total_amount"] ?? partner?["total_amount"] ?? 0;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse("$value") ?? 0;
  }

  String get providerPaymentMode {
    final paymentMode =
        "${partner?["payment_mode"] ?? user?["payment_mode"] ?? ""}"
            .toLowerCase();
    return paymentMode == "cash" ? "cash" : "load";
  }

  int get providerPaymentId => providerPaymentMode == "cash" ? 1 : 8;

  void syncProviderPaymentMode() {
    if (!isBool(AuthService.currentUser?.isProvider)) {
      if (paymentId != 1) {
        paymentId = 1;
        if (selectedVehicle != null) {
          calculateTotalAmount();
        } else {
          notifyListeners();
        }
      }
      return;
    }
    final nextPaymentId = providerPaymentId;
    if (paymentId == nextPaymentId) {
      return;
    }
    paymentId = nextPaymentId;
    if (selectedVehicle != null) {
      calculateTotalAmount();
    }
  }

  void setProviderRiderType(int riderTypeId) {
    if (!isBool(AuthService.currentUser?.isProvider) ||
        providerRiderTypeId == riderTypeId) {
      return;
    }
    providerRiderTypeId = riderTypeId;
    calculateTotalAmount();
  }

  Future<void> selectProviderStaffRiderType() async {
    if (!isBool(AuthService.currentUser?.isProvider)) {
      return;
    }
    if (providerRiderTypeId != 8) {
      providerRiderTypeId = 8;
    }
    await _ensureProviderStaffCoupon(showErrorOnFailure: true);
    calculateTotalAmount();
  }

  changeSelectedVehicle(VehicleType vehicleType) {
    if (vehicleTypes.isNotEmpty) {
      selectedVehicle = vehicleTypes.firstWhere(
        (vType) => vType.name == vehicleType.name,
      );
    }
    calculateTotalAmount();
  }

  Future<void> previewSelectedRouteOnHome({
    required Address pickup,
    required Address dropoff,
    bool animateMap = true,
  }) async {
    resetManualPaymentMethodOverride();
    pickupAddress = pickup;
    dropoffAddress = dropoff;
    isPreparing = true;
    notifyListeners();
    final pricingFuture = fetchVehicleTypesPricing();
    await drawDropPolyLines(
      "pickup-dropoff",
      pickup.latLng,
      dropoff.latLng,
      null,
      autoFitMap: true,
      autoFitAnimated: animateMap,
    );
    fitCurrentRouteBounds(
      padding: routeBoundsPadding,
      animated: animateMap,
      allowSinglePointFit: false,
    );
    await pricingFuture;
    isPreparing = false;
    notifyListeners();
  }

  Future<void> fetchVehicleTypesPricing() async {
    setBusyForObject(vehicleTypes, true);
    try {
      ApiResponse apiResponse = await taxiRequest.locationAvailableRequest(
        double.parse("${pickupAddress?.latLng.lat}"),
        double.parse("${pickupAddress?.latLng.lng}"),
      );
      if (!apiResponse.allGood && !AuthService.inReviewMode()) {
        locUnavailable = true;
        notifyListeners();
      } else {
        locUnavailable = false;
        notifyListeners();
        vehicleTypes = await taxiRequest.vehicleTypesPricingRequest(
          pickupAddress!,
          dropoffAddress!,
        );
        if (vehicleTypes.isEmpty) {
          selectedVehicle = null;
          _pendingStatusFareVisualOverride = null;
          _pendingBookingFareOverride = null;
          total = 0;
          subTotal = 0;
          discount = 0;
          syncTotalAmountNotifier();
          _syncDriverDistantFareNotifier();
          notifyListeners();
          return;
        }
        await changeSelectedVehicle(
          vehicleTypes.firstWhere(
            (vehicleType) => vehicleType.slug == "tricycle",
            orElse: () => vehicleTypes.first,
          ),
        );
      }
    } finally {
      setBusyForObject(vehicleTypes, false);
    }
  }

  getOngoingOrder({
    bool refresh = false,
    bool showSnack = false,
    bool forceStop = false,
    String? signalReason,
  }) async {
    _tempCancelDebug(
      "GetOngoingOrderStart",
      details: {
        "refresh": refresh,
        "showSnack": showSnack,
        "forceStop": forceStop,
        "signalReason": signalReason,
      },
    );
    setBusyForObject(ongoingOrder, true);
    if (refresh) {
      lastStatus = null;
      notifyListeners();
    }
    final previousOrderCode = ongoingOrder?.code?.trim() ?? "";
    final previousOrderStatus = _normalizeOrderStatus(ongoingOrder?.status);
    final previousDriverId = ongoingOrder?.driverId ?? ongoingOrder?.driver?.id;
    final previousUserSeen = userSeen;
    final previousDriverMessage = dvrMessage;
    final previousCancelRequestStatus = cancelRequestStatus;
    final previousHydratedOrderMeta = hasHydratedOngoingOrderMeta;
    final pendingStatusFareVisualOverride = _pendingStatusFareVisualOverride;
    final pendingBookingFareOverride = _pendingBookingFareOverride;
    final hadExistingOngoingOrder = ongoingOrder != null;
    try {
      final fetchedOngoingOrder = await taxiRequest.ongoingOrderRequest();
      if (fetchedOngoingOrder == null) {
        _tempCancelDebug(
          "GetOngoingOrderFetchedNull",
          details: {
            "hadExistingOngoingOrder": hadExistingOngoingOrder,
            "previousOrderCode": previousOrderCode,
            "previousOrderStatus": previousOrderStatus,
          },
        );
        if (hadExistingOngoingOrder &&
            previousOrderCode.isNotEmpty &&
            _normalizeOrderStatus(_latestFirestoreStatus) == "cancelled") {
          ongoingOrder?.status = "cancelled";
          await _handleCancelledOrderState(ongoingOrder);
          return;
        }
        final shouldRestoreCompletedReceipt = hadExistingOngoingOrder &&
            _shouldAttemptCompletedReceiptRestoreFromFetchedNull(
              previousOrderStatus,
            );
        if (shouldRestoreCompletedReceipt) {
          final restored =
              await _restoreCompletedReceiptOrderForCurrentBooking();
          if (restored) {
            await loadUIByOngoingOrderStatus(forceStop: forceStop);
            return;
          }
        }
        ongoingOrder = null;
        await loadUIByOngoingOrderStatus();
        return;
      }
      final fetchedBackendStatus =
          _normalizeOrderStatus(fetchedOngoingOrder.status);
      _tempCancelDebug(
        "GetOngoingOrderFetched",
        details: {
          "fetchedOrderId": fetchedOngoingOrder.id,
          "fetchedOrderCode": fetchedOngoingOrder.code,
          "fetchedBackendStatus": fetchedBackendStatus,
          "fetchedReason": fetchedOngoingOrder.reason,
          "fetchedCancelledByWho": fetchedOngoingOrder.cancelledByWho,
          "signalReason": signalReason,
        },
      );
      ongoingOrder = fetchedOngoingOrder;
      _pendingBookingFareOverride = null;
      _applyPendingDriverDistantFareToOngoingOrder();
      _reconcilePendingOngoingOrderFareOverride();
      ongoingOrder?.status = _normalizeOrderStatus(ongoingOrder?.status);
      if (_isPendingWithoutDriverFareOverrideStatus(ongoingOrder?.status) &&
          ((pendingStatusFareVisualOverride != null &&
                  pendingStatusFareVisualOverride > 0) ||
              (pendingBookingFareOverride != null &&
                  pendingBookingFareOverride > 0))) {
        _pendingStatusFareVisualOverride =
            pendingStatusFareVisualOverride ?? pendingBookingFareOverride!;
      } else if (!_isPendingWithoutDriverFareOverrideStatus(
          ongoingOrder?.status)) {
        _pendingStatusFareVisualOverride = null;
      }
      _reconcilePendingStatusFareVisualOverride();
      final nextOrderCode = ongoingOrder?.code?.trim() ?? "";
      final isSameOngoingOrder =
          nextOrderCode.isNotEmpty && nextOrderCode == previousOrderCode;
      await _reconcileOrderWithLatestFirestoreState(
        nextOrderCode: nextOrderCode,
        preferBackendStatus: true,
      );
      final shouldKeepFresherFirestoreStatus =
          _shouldKeepFresherFirestoreStatusOverFetchedBackend(
        fetchedBackendStatus: fetchedBackendStatus,
        refresh: refresh,
        signalReason: signalReason,
      );
      if (shouldKeepFresherFirestoreStatus) {
        ongoingOrder?.status = _normalizeOrderStatus(_latestFirestoreStatus);
      } else if (_isMeaningfulOrderStatus(fetchedBackendStatus) &&
          fetchedBackendStatus != "cancelled" &&
          fetchedBackendStatus != "failed") {
        ongoingOrder?.status = fetchedBackendStatus;
        _latestFirestoreStatus = fetchedBackendStatus;
      }
      ongoingOrder?.status = _normalizeOrderStatus(ongoingOrder?.status);
      final nextOrderStatus = _normalizeOrderStatus(ongoingOrder?.status);
      final nextDriverId = ongoingOrder?.driverId ?? ongoingOrder?.driver?.id;
      _resetTerminalDialogKeyForActiveNonTerminalOrder();
      hasHydratedOngoingOrderMeta = isSameOngoingOrder &&
              previousHydratedOrderMeta &&
              nextOrderStatus.isNotEmpty &&
              nextOrderStatus != "null"
          ? true
          : false;
      final cachedFirestoreUserSeen = _latestFirestoreUserSeen;
      final cachedFirestoreDriverMessage = _latestFirestoreDriverMessage;
      userSeen = isSameOngoingOrder
          ? previousUserSeen
          : (cachedFirestoreUserSeen ?? true);
      dvrMessage = isSameOngoingOrder
          ? previousDriverMessage
          : cachedFirestoreDriverMessage;
      final latestFirestoreCancelRequestStatus =
          (_latestFirestoreCancelRequestStatus ?? "").trim();
      cancelRequestStatus = latestFirestoreCancelRequestStatus.isNotEmpty &&
              latestFirestoreCancelRequestStatus.toLowerCase() != "null"
          ? latestFirestoreCancelRequestStatus
          : (isSameOngoingOrder ? previousCancelRequestStatus : "");
      notifyListeners();
      if (ongoingOrder != null) {
        final hasDriverChanged = previousDriverId != nextDriverId &&
            "${nextDriverId ?? ""}".trim().isNotEmpty &&
            "${nextDriverId ?? ""}".trim().toLowerCase() != "null";
        if (hasDriverChanged &&
            _isMeaningfulOrderStatus(fetchedBackendStatus) &&
            !shouldKeepFresherFirestoreStatus) {
          ongoingOrder?.status = fetchedBackendStatus;
          if (_isMeaningfulOrderStatus(_latestFirestoreStatus)) {
            _latestFirestoreStatus = fetchedBackendStatus;
          }
        }
        final shouldResetPendingRedraw =
            (nextOrderStatus == "pending" || nextOrderStatus == "preparing") &&
                (!isSameOngoingOrder ||
                    previousOrderStatus != nextOrderStatus ||
                    previousDriverId != nextDriverId);
        if (shouldResetPendingRedraw) {
          lastStatus = null;
          notifyListeners();
        }
        await startHandlingOngoingOrder(forceStop: forceStop);
        if (hasDriverChanged) {
          await _resetAndRedrawMapForDriverChange(forceStop: forceStop);
        } else {
          await loadUIByOngoingOrderStatus(forceStop: forceStop);
        }
        bookingId = ongoingOrder?.id ?? 0;
        notifyListeners();
      }
    } catch (e) {
      _tempCancelDebug(
        "GetOngoingOrderCatch",
        details: {
          "error": "$e",
          "hadExistingOngoingOrder": hadExistingOngoingOrder,
          "previousOrderCode": previousOrderCode,
        },
      );
      if (hadExistingOngoingOrder && previousOrderCode.isNotEmpty) {
        notifyListeners();
        return;
      }
      ongoingOrder = null;
      await loadUIByOngoingOrderStatus();
    }
    notifyListeners();
    if (ongoingOrder == null) {
      if (showSnack) {
        if (!snackShown) {
          ScaffoldMessenger.of(Get.context!).clearSnackBars();
          ScaffoldMessenger.of(
            Get.context!,
          ).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "No driver found. Try again later",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
          snackShown = true;
        }
      }
    }
    notifyListeners();
    setBusyForObject(ongoingOrder, false);
    _tempCancelDebug(
      "GetOngoingOrderEnd",
      details: {
        "refresh": refresh,
        "showSnack": showSnack,
        "forceStop": forceStop,
        "signalReason": signalReason,
      },
    );
  }

  processNewOrder() async {
    if (pickupAddress == null) {
      ScaffoldMessenger.of(
        Get.context!,
      ).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please set your pickup address",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (dropoffAddress == null) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please set your dropoff address",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if ((pickupAddress?.latLng == dropoffAddress?.latLng ||
            travelTime(selectedVehicle?.kmDistance ?? 0) == "0 secs") &&
        !AuthService.inReviewMode()) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            locUnavailable
                ? "Please try another location"
                : "Pickup and dropoff must differ",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (selectedVehicle == null) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            locUnavailable
                ? "Please try another location"
                : "Please select a vehicle",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      if (AuthService.inReviewMode()) {
        showDialog(
          context: Get.context!,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          useSafeArea: false,
          builder: (BuildContext context) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (
                didPop,
                result,
              ) async {
                if (didPop) {
                  return;
                }
              },
              child: AlertDialog(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(12),
                  ),
                ),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Searching for drivers",
                      style: TextStyle(
                        height: 1.05,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade400,
                      color: const Color(0xFF007BFF),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    const Text(
                      "PPC TODA is searching for drivers near you. If this takes too long, there might be no available tricycle drivers near your current area.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    SizedBox(
                      height: 38,
                      child: ActionButton(
                        onTap: () {
                          cancelOrder();
                        },
                        height: 38,
                        text: "Cancel",
                        mainColor: Colors.red.shade100,
                        style: const TextStyle(
                          height: 1,
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        AlertService().showLoading();
        try {
          snackShown = false;
          availableDriver = null;
          final vehicleTypeId = _driverSearchVehicleTypeId;
          if (vehicleTypeId == null) {
            throw "Vehicle type is unavailable for this booking";
          }
          availableDriver = await taxiRequest.findAvailableDriver(
            types: vehicleTypes,
            pickup: pickupAddress,
            dropoff: dropoffAddress,
            vehicleTypeId: vehicleTypeId,
          );
        } catch (e) {
          availableDriver = null;
        }
        AlertService().stopLoading(forceStop: true);
        if (availableDriver?.driver != null &&
            availableDriver!.kmDistance != 0) {
          if ((availableDriver?.pickupKm ?? 0.0) <=
              _driverSearchPickupKmLimit) {
            placeNewOrder();
          } else {
            _showDriverDistantDialog();
          }
        } else {
          if (!snackShown) {
            ScaffoldMessenger.of(Get.context!).clearSnackBars();
            ScaffoldMessenger.of(
              Get.context!,
            ).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  "No driver found. Try again later",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            );
            snackShown = true;
          }
        }
      }
    }
  }

  placeNewOrder({
    bool manageLoading = true,
  }) async {
    _shouldSuppressAutomaticPartnerDisplays = true;
    notifyListeners();
    final resolvedBookingPayableFare = _resolvedBookingPayableFare;
    dynamic params = isBool(AuthService.currentUser?.isProvider)
        ? {
            "tip": 0.0,
            "total": resolvedBookingPayableFare,
            "is_pautos": false,
            "is_delivery": false,
            "has_luggage": false,
            "discount": discount,
            "sub_total": subTotal,
            "payment_method": null,
            "payment_method_id": providerPaymentId,
            "is_mov_reached": false,
            "includes_ride_cover": true,
            "includes_shower_cap": true,
            "markup_amount":
                providerRiderTypeId == 8 ? 0.0 : providerMarkupAmount,
            "vehicle_type_id": selectedVehicle?.id,
            "vehicle_type": selectedVehicle?.encrypted,
            "coupon_code": providerRiderTypeId == 8
                ? ((providerStaffCoupon?.code ?? "STAFF").trim().toUpperCase())
                : null,
            "actual": {
              "lat": initLatLng?.lat,
              "lng": initLatLng?.lng,
            },
            "pickup": {
              "lat": pickupAddress?.coordinates.latitude,
              "lng": pickupAddress?.coordinates.longitude,
              "address": pickupAddress?.addressLine,
            },
            "dropoff": {
              "lat": dropoffAddress?.coordinates.latitude,
              "lng": dropoffAddress?.coordinates.longitude,
              "address": dropoffAddress?.addressLine,
            },
          }
        : {
            "is_pautos": false,
            "is_delivery": false,
            "has_luggage": false,
            "is_mov_reached": false,
            "includes_ride_cover": false,
            "includes_shower_cap": false,
            "tip": 0.0,
            "discount": discount,
            "coupon_code": appliedCoupon?.code,
            "payment_method": null,
            "payment_method_id": paymentId,
            "total": resolvedBookingPayableFare,
            "sub_total": subTotal,
            "vehicle_type_id": selectedVehicle?.id,
            "vehicle_type": selectedVehicle?.encrypted,
            "actual": {
              "lat": initLatLng?.lat,
              "lng": initLatLng?.lng,
            },
            "pickup": {
              "lat": pickupAddress?.coordinates.latitude,
              "lng": pickupAddress?.coordinates.longitude,
              "address": pickupAddress?.addressLine,
            },
            "dropoff": {
              "lat": dropoffAddress?.coordinates.latitude,
              "lng": dropoffAddress?.coordinates.longitude,
              "address": dropoffAddress?.addressLine,
            },
          };
    if (manageLoading) {
      AlertService().showLoading();
    }
    try {
      ApiResponse apiResponse = await taxiRequest.placeNewOrderRequest(
        params: params,
      );
      if (manageLoading) {
        AlertService().stopLoading(forceStop: true);
      }
      if (apiResponse.allGood) {
        cHeaders = null;
        notifyListeners();
        await getOngoingOrder(forceStop: true);
      } else {
        _shouldSuppressAutomaticPartnerDisplays = false;
        notifyListeners();
        showError(apiResponse.message);
      }
    } catch (e) {
      if (manageLoading) {
        AlertService().stopLoading(forceStop: true);
      }
      _shouldSuppressAutomaticPartnerDisplays = false;
      notifyListeners();
      showError(e);
    }
  }

  cancelOrder() {
    int remainingRebookSeconds() {
      return _remainingRebookSecondsForOrder(ongoingOrder);
    }

    final initialRemainingRebookSeconds = remainingRebookSeconds();
    final initialRemainingCancelSeconds =
        _remainingCancelSecondsForOrder(ongoingOrder);
    final canShowGetNewDriverNowButtonForCurrentOrder =
        canShowGetNewDriverNowAction(
      status: ongoingOrder?.status,
      driver: ongoingOrder?.driver,
      driverId: ongoingOrder?.driverId,
    );
    final canShowRequestCancellationButtonForCurrentOrder =
        canShowRequestCancellationPill(
      status: ongoingOrder?.status,
      driver: ongoingOrder?.driver,
      driverId: ongoingOrder?.driverId,
    );
    final shouldShowRequestCancellationButton = !canCancelWithAcceptedRequest &&
        canShowRequestCancellationButtonForCurrentOrder &&
        initialRemainingCancelSeconds > 0 &&
        initialRemainingRebookSeconds == 0 &&
        canRebookAfterWaitWithoutDriverChat &&
        !hasAcceptedCancelRequest;
    final showBookingCancellationPills = !AuthService.inReviewMode();

    Widget bookingCancellationBottomContent() {
      Widget buildPill({
        required String label,
        required Color color,
        required Future<void> Function() onTap,
      }) {
        return SizedBox(
          width: double.infinity,
          height: 38,
          child: WidgetButton(
            onTap: () async => onTap(),
            mainColor: color.withValues(alpha: 0.08),
            interactionColor: color.withValues(alpha: 0.18),
            useDefaultHoverColor: false,
            borderRadius: 1000,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.18),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    style: TextStyle(
                      height: 1,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final supportLink = Center(
        child: WidgetButton(
          onTap: () async {
            Get.back();
            await showFacebookSupportDialog(Get.context!);
          },
          borderRadius: 6,
          mainColor: Colors.transparent,
          isTransparentColor: true,
          useDefaultHoverColor: false,
          suppressInteraction: true,
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "Need help? ",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF030744),
                  ),
                ),
                TextSpan(
                  text: "Contact",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007BFF),
                  ),
                ),
                TextSpan(
                  text: " or ",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF030744),
                  ),
                ),
                TextSpan(
                  text: "Message",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007BFF),
                  ),
                ),
                TextSpan(
                  text: " us!",
                  style: TextStyle(
                    height: 1.15,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF030744),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBookingCancellationPills) ...[
            if (canShowGetNewDriverNowButtonForCurrentOrder)
              buildPill(
                label: "Get a new driver now!",
                color: const Color(0xFF007BFF),
                onTap: () async {
                  await processAcceptedCancelRequestRebook();
                },
              ),
            if (shouldShowRequestCancellationButton) ...[
              SizedBox(
                height: canShowGetNewDriverNowButtonForCurrentOrder
                    ? AlertService.actionGap
                    : 0,
              ),
              buildPill(
                label: "Request cancellation",
                color: Colors.red,
                onTap: () async {
                  Get.back();
                  await sendQuickChatMessage(
                    "Request cancellation",
                    isRequestCancellation: true,
                    openChatAfter: true,
                  );
                },
              ),
            ],
            const SizedBox(height: AlertService.actionGap),
          ],
          supportLink,
        ],
      );
    }

    if (!canOpenCancelFlow) {
      final message = hasDriverChatMessage
          ? "Cancellation is unavailable once the driver has already sent a chat."
          : "Please wait for $initialRemainingRebookSeconds second${initialRemainingRebookSeconds == 1 ? "" : "s"} or get a new driver now!";
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
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
      return;
    }
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Booking Cancellation",
      content: "Do you want to cancel this booking?",
      hideThird: true,
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: Colors.red,
      bottomWidget: bookingCancellationBottomContent(),
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        Get.back();
        await processAcceptedCancelRequestCancel();
      },
    );
  }

  void _showCancelFlowWaitSnackBar(
    int seconds, {
    bool includeRequestCancellation = false,
  }) {
    final message = includeRequestCancellation
        ? "Please wait for $seconds second${seconds == 1 ? "" : "s"}. Request cancellation or get a new driver now!"
        : "Please wait for $seconds second${seconds == 1 ? "" : "s"} or get a new driver now!";
    ScaffoldMessenger.of(Get.context!).clearSnackBars();
    ScaffoldMessenger.of(Get.context!).showSnackBar(
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

  Future<void> processAcceptedCancelRequestRebook() async {
    final latestRemainingRebookSeconds =
        _remainingRebookSecondsForOrder(ongoingOrder);
    if (!canCancelWithAcceptedRequest && latestRemainingRebookSeconds > 0) {
      _showCancelFlowWaitSnackBar(latestRemainingRebookSeconds);
      return;
    }

    Get.until((route) => route.isFirst);
    try {
      AlertService().showLoading();
      await _findAvailableDriverForRebook();
      AlertService().stopLoading(forceStop: true);
      if (availableDriver?.driver != null && availableDriver!.kmDistance != 0) {
        if ((availableDriver?.pickupKm ?? 0.0) <= _driverSearchPickupKmLimit) {
          await _placeRebookOrder();
        } else {
          await _showDriverDistantDialog(
            onAccept: () {
              _placeRebookOrder();
            },
          );
        }
      } else {
        if (!snackShown) {
          ScaffoldMessenger.of(Get.context!).clearSnackBars();
          ScaffoldMessenger.of(
            Get.context!,
          ).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "No driver found. Try again later",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
          snackShown = true;
        }
      }
    } catch (e) {
      showError(e);
    }
  }

  Future<void> processAcceptedCancelRequestCancel() async {
    _tempCancelDebug("ProcessAcceptedCancelRequestCancelStart");
    final latestRemainingCancelSeconds =
        _remainingCancelSecondsForOrder(ongoingOrder);
    if (!canCancelWithAcceptedRequest && latestRemainingCancelSeconds > 0) {
      _tempCancelDebug(
        "ProcessAcceptedCancelRequestCancelBlockedByWait",
        details: {
          "latestRemainingCancelSeconds": latestRemainingCancelSeconds,
          "canCancelWithAcceptedRequest": canCancelWithAcceptedRequest,
          "canRebookAfterWaitWithoutDriverChat":
              canRebookAfterWaitWithoutDriverChat,
          "hasAcceptedCancelRequest": hasAcceptedCancelRequest,
        },
      );
      _showCancelFlowWaitSnackBar(
        latestRemainingCancelSeconds,
        includeRequestCancellation:
            canRebookAfterWaitWithoutDriverChat && !hasAcceptedCancelRequest,
      );
      return;
    }

    if (AuthService.inReviewMode()) {
      _tempCancelDebug("ProcessAcceptedCancelRequestCancelReviewModeExit");
      Get.back();
      return;
    }

    _tempCancelDebug("ProcessAcceptedCancelRequestCancelShowLoading");
    AlertService().showLoading();
    try {
      final orderCode = ongoingOrder?.code?.trim();
      ApiResponse apiResponse = await taxiRequest.cancelOrderRequest(
        id: ongoingOrder!.id!,
        reason: "initiated by passenger",
        rebook: false,
      );
      _tempCancelDebug(
        "ProcessAcceptedCancelRequestCancelResponse",
        details: {
          "apiAllGood": apiResponse.allGood,
          "apiCode": apiResponse.code,
          "apiMessage": apiResponse.message,
          "orderCode": orderCode,
        },
      );
      if (apiResponse.allGood) {
        _tempCancelDebug(
          "ProcessAcceptedCancelRequestCancelStopLoadingSuccess",
        );
        AlertService().stopLoading(forceStop: true);
        _shouldSuppressAutomaticPartnerDisplays = true;
        if (orderCode != null && orderCode.isNotEmpty) {
          _tempCancelDebug(
            "ProcessAcceptedCancelRequestCancelMarkUserSeen",
            details: {
              "orderCode": orderCode,
            },
          );
          await markCurrentOrderUserSeen();
        } else {
          userSeen = true;
          _latestFirestoreUserSeen = true;
          notifyListeners();
        }
      } else {
        if (apiResponse.message.contains("cancel")) {
          _tempCancelDebug(
            "ProcessAcceptedCancelRequestCancelBackendCancelMessage",
            details: {
              "apiMessage": apiResponse.message,
            },
          );
          clearGMapDetails();
        } else {
          throw apiResponse.message;
        }
      }
    } catch (e) {
      _tempCancelDebug(
        "ProcessAcceptedCancelRequestCancelCatch",
        details: {
          "error": "$e",
        },
      );
      if (!isChatViewOpen) {
        Get.until((route) => route.isFirst);
      }
      showError(e);
    } finally {
      _tempCancelDebug("ProcessAcceptedCancelRequestCancelFinally");
    }
  }

  void confirmAcceptedCancelRequestCancel() {
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Are you sure?",
      content: "Do you want to cancel this booking?",
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: Colors.red,
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        Get.back();
        await processAcceptedCancelRequestCancel();
      },
    );
  }

  void confirmAcceptedCancelRequestRebook() {
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Are you sure?",
      content: "Do you want to get a new driver now?",
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: const Color(0xFF007BFF),
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        Get.back();
        await processAcceptedCancelRequestRebook();
      },
    );
  }

  Future<void> _findAvailableDriverForRebook() async {
    snackShown = false;
    availableDriver = null;
    try {
      final vehicleTypeId = _driverSearchVehicleTypeId;
      if (vehicleTypeId == null) {
        throw "Vehicle type is unavailable for this booking";
      }
      availableDriver = await taxiRequest.findAvailableDriver(
        types: vehicleTypes,
        pickup: pickupAddress,
        dropoff: dropoffAddress,
        vehicleTypeId: vehicleTypeId,
      );
    } catch (e) {
      availableDriver = null;
    }
  }

  Future<void> _placeRebookOrder() async {
    notifyListeners();
    try {
      ApiResponse apiResponse = await taxiRequest.passOrderRequest(
        reason: "rebook",
        id: ongoingOrder!.id!,
        targetDriverId: availableDriver!.driver!.id!,
      );
      if (!apiResponse.allGood) {
        throw apiResponse.message;
      }
      if (ongoingOrder != null && availableDriver?.driver != null) {
        ongoingOrder!.driver = availableDriver!.driver;
        ongoingOrder!.driverId = availableDriver!.driver!.id;
        _latestSyncedDriverLatLng = ongoingOrder!.driverLatLng;
        driverPositionRotation = 0;
        notifyListeners();
      }
      final orderCode = ongoingOrder?.code?.trim();
      if (orderCode != null && orderCode.isNotEmpty) {
        await fbStore.collection("orders").doc(orderCode).update(
          {
            "driver_accept_id": null,
            "driver_accept_latitude": null,
            "driver_accept_longitude": null,
            "userSeen": true,
          },
        );
      }
      userSeen = true;
      _latestFirestoreUserSeen = true;
      final chatEntity = _buildUserChatEntity();
      final currentUserName = (ongoingOrder?.user?.name ?? "User").trim();
      final newDriverName = (availableDriver?.driver?.name ?? "Driver").trim();
      if (chatEntity != null && newDriverName.isNotEmpty) {
        final message =
            "$currentUserName rebooked for a new driver and was assigned to $newDriverName!";
        final chatRef = fbStore.collection("${chatEntity.path}/Activity");
        final chatMessage = ChatMessage(
          text: message,
          user: chatEntity.mainUser!.toChatUser(),
          createdAt: DateTime.now().toUtc(),
        );

        await chatRef.doc().set(Chat.jsonFrom(chatMessage)).timeout(
              const Duration(seconds: 30),
            );
        chatEntity.onMessageSent(
          message,
          chatEntity,
        );
      }
      AlertService().stopLoading(forceStop: true);
    } catch (e) {
      _pendingStatusFareVisualOverride = null;
      _pendingOngoingOrderFareOverride = null;
      notifyListeners();
      showError(e);
    }
  }

  int _remainingCancelSecondsForOrder(Order? order) {
    final createdAt = order?.createdAt ?? order?.taxiOrder?.createdAt;
    if (createdAt == null) {
      return 0;
    }

    final cancelAvailableAt = createdAt.toLocal().add(
          const Duration(minutes: 5),
        );
    final remaining = cancelAvailableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  int _remainingRebookSecondsForOrder(Order? order) {
    final createdAt = order?.createdAt ?? order?.taxiOrder?.createdAt;
    if (createdAt == null) {
      return 0;
    }

    final rebookAvailableAt = createdAt.toLocal().add(
          const Duration(minutes: 2),
        );
    final remaining = rebookAvailableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  stopAllListeners() {
    _cancelDelayedSignalRefreshTimer();
    orderUpdateStream?.cancel();
    partnerUpdateStream?.cancel();
    globalTimer?.cancel();
    globalTimer = null;
    _isRefreshingOngoingOrderFromSignal = false;
    _hasPendingSignalRefresh = false;
    _pendingSignalRefreshReason = null;
    _pendingSignalRefreshForceStop = false;
    _activeOrderStreamCode = null;
    _lastProcessedOrderSnapshotKey = null;
    _latestFirestoreDriverId = null;
    _latestFirestoreStatus = null;
    _latestFirestoreCancelRequestStatus = null;
    _latestFirestoreUserSeen = null;
    _latestFirestoreDriverMessage = null;
    _lastDriverSyncOrderRefreshAt = null;
    hasHydratedOngoingOrderMeta = false;
    _pendingStatusFareVisualOverride = null;
    _pendingBookingFareOverride = null;
    _pendingOngoingOrderFareOverride = null;
    _driverLocationSyncOrderCode = null;
    _isSyncingDriverLocation = false;
    _latestSyncedDriverLatLng = null;
  }

  closeOrder() async {
    LoadViewModel().getLoadBalance();
    stopAllListeners();
    bookingId = 0;
    selectedVehicle = null;
    dropoffAddress = null;
    pickupAddress = null;
    ongoingOrder = null;
    deliveredReceiptOrder = null;
    _shouldSuppressAutomaticPartnerDisplays = false;
    _isRefreshingOngoingOrderFromSignal = false;
    _hasPendingSignalRefresh = false;
    _pendingSignalRefreshReason = null;
    _pendingSignalRefreshForceStop = false;
    lastCenter = null;
    lastStatus = null;
    cancelRequestStatus = "";
    dvrMessage = null;
    _latestFirestoreDriverId = null;
    _latestFirestoreStatus = null;
    _latestFirestoreCancelRequestStatus = null;
    _latestFirestoreUserSeen = null;
    _latestFirestoreDriverMessage = null;
    hasHydratedOngoingOrderMeta = false;
    _pendingStatusFareVisualOverride = null;
    _pendingBookingFareOverride = null;
    _pendingOngoingOrderFareOverride = null;
    cHeaders = null;
    vehicleTypes = [];
    getOngoingOrder();
    clearGMapDetails();
    clearPickupDisplayState();
    notifyListeners();
  }

  startHandlingOngoingOrder({bool forceStop = false}) async {
    final orderCode = ongoingOrder?.code?.trim() ?? "";
    if (orderCode.isEmpty) {
      return;
    }
    final shouldRebindActiveOrderStream = forceStop;
    final isSameActiveOrderStream = !shouldRebindActiveOrderStream &&
        _activeOrderStreamCode == orderCode &&
        orderUpdateStream != null;
    if (dbTimer != null && dbTimer!.isActive) {
      dbTimer?.cancel();
    }
    dbTimer = null;
    if (!isSameActiveOrderStream) {
      orderUpdateStream?.cancel();
      _lastProcessedOrderSnapshotKey = null;
      _activeOrderStreamCode = orderCode;
      orderUpdateStream =
          fbStore.collection("orders").doc(orderCode).snapshots().listen(
        (event) async {
          order = event.data();
          final snapshotKey = [
            orderCode,
            "${event.data()?["syncedAt"] ?? ""}",
            "${event.data()?["status"] ?? ""}",
            "${event.data()?["driver_id"] ?? ""}",
            "${event.data()?["userSeen"] ?? ""}",
            "${event.data()?["driverMessage"] ?? ""}",
            "${event.data()?["cancel_request_status"] ?? ""}",
            "${event.data()?["markup_amount"] ?? ""}",
            "${event.data()?["includes_ride_cover"] ?? ""}",
            "${event.data()?["includes_shower_cap"] ?? ""}",
          ].join("|");
          if (_lastProcessedOrderSnapshotKey == snapshotKey) {
            return;
          }
          _lastProcessedOrderSnapshotKey = snapshotKey;
          final shouldWriteProviderGuestMarkup =
              _shouldWriteProviderGuestMarkupToFirestore();
          final existingFirestoreMarkupAmount = event.data()?["markup_amount"];
          if (event.exists &&
              shouldWriteProviderGuestMarkup &&
              existingFirestoreMarkupAmount == null) {
            unawaited(
              event.reference.set(
                {
                  "markup_amount": providerMarkupAmount,
                },
                SetOptions(merge: true),
              ).catchError((_) {}),
            );
          }
          try {
            final previousUserSeen = userSeen;
            final previousDriverMessage = dvrMessage;
            final previousCancelRequestStatus = cancelRequestStatus;
            final previousOrderSyncedAt = StorageService.prefs?.getString(
                  "orderSyncedAt",
                ) ??
                "";
            final nextOrderSyncedAt = "${event.data()?["syncedAt"] ?? ""}";
            final nextStatus =
                _normalizeOrderStatus("${event.data()?["status"]}");
            final hasMeaningfulNextStatus =
                _isMeaningfulOrderStatus(nextStatus);
            final nextDriverId = "${event.data()?["driver_id"] ?? ""}".trim();
            final nextMarkupAmount =
                parseDouble(event.data()?["markup_amount"], "markup_amount");
            final nextIncludesRideCover = parseBool(
              event.data()?["includes_ride_cover"],
              "includes_ride_cover",
            );
            final nextIncludesShowerCap = parseBool(
              event.data()?["includes_shower_cap"],
              "includes_shower_cap",
            );
            final rawNextUserSeenValue = isBool(event.data()?["userSeen"]);
            final nextDriverMessageValue = "${event.data()?["driverMessage"]}";
            final nextCancelRequestStatusValue =
                "${event.data()?["cancel_request_status"] ?? ""}".trim();
            final hasIncomingCancelRequestResolution =
                _isCancelRequestResolutionStatus(
                        nextCancelRequestStatusValue) &&
                    _isCancelRequestResolutionMessage(nextDriverMessageValue) &&
                    (previousCancelRequestStatus !=
                            nextCancelRequestStatusValue ||
                        previousDriverMessage != nextDriverMessageValue);
            final shouldForceUnreadForIncomingCancelResolution =
                hasIncomingCancelRequestResolution &&
                    !isChatViewOpen &&
                    !rawNextUserSeenValue;
            final nextUserSeenValue =
                shouldForceUnreadForIncomingCancelResolution
                    ? false
                    : rawNextUserSeenValue;
            final currentDriverId =
                "${ongoingOrder?.driverId ?? ongoingOrder?.driver?.id ?? ""}"
                    .trim();
            final hasDriverAssignmentChange = nextDriverId.isNotEmpty &&
                nextDriverId.toLowerCase() != "null" &&
                nextDriverId != currentDriverId;
            final currentStatus = _normalizeOrderStatus(ongoingOrder?.status);
            final shouldIgnoreStatusRegression =
                _shouldIgnoreFirestoreStatusRegression(
              currentStatus: currentStatus,
              nextStatus: nextStatus,
              allowRegression: hasDriverAssignmentChange,
            );
            userSeen = nextUserSeenValue;
            dvrMessage = nextDriverMessageValue;
            _latestFirestoreUserSeen = nextUserSeenValue;
            _latestFirestoreDriverMessage =
                nextDriverMessageValue.trim().isEmpty ||
                        nextDriverMessageValue.trim().toLowerCase() == "null"
                    ? null
                    : nextDriverMessageValue;
            _latestFirestoreCancelRequestStatus =
                nextCancelRequestStatusValue.isEmpty ||
                        nextCancelRequestStatusValue.toLowerCase() == "null"
                    ? null
                    : nextCancelRequestStatusValue;
            cancelRequestStatus = nextCancelRequestStatusValue;
            if (previousUserSeen != userSeen ||
                previousDriverMessage != dvrMessage ||
                previousCancelRequestStatus != cancelRequestStatus) {
              notifyListeners();
            }
            if (ongoingOrder != null) {
              ongoingOrder?.markupAmount = nextMarkupAmount;
              ongoingOrder?.includesRideCover = nextIncludesRideCover;
              ongoingOrder?.includesShowerCap = nextIncludesShowerCap;
            }
            if (hasMeaningfulNextStatus && !shouldIgnoreStatusRegression) {
              _latestFirestoreStatus = nextStatus;
            }
            _latestFirestoreDriverId = nextDriverId;
            if (ongoingOrder != null &&
                hasMeaningfulNextStatus &&
                nextStatus != "cancelled" &&
                nextStatus != "failed" &&
                !isCompletedReceiptStatus(nextStatus)) {
              ongoingOrder?.status = nextStatus;
              _resetTerminalDialogKeyForActiveNonTerminalOrder();
            }
            if (hasMeaningfulNextStatus &&
                nextStatus == "cancelled" &&
                ongoingOrder != null) {
              final shouldConfirmCancelledWithBackend =
                  currentStatus.isNotEmpty &&
                      currentStatus != "cancelled" &&
                      currentStatus != "failed" &&
                      !isCompletedReceiptStatus(currentStatus);
              _tempCancelDebug(
                "FirestoreCancelledSnapshot",
                details: {
                  "currentStatus": currentStatus,
                  "nextStatus": nextStatus,
                  "snapshotReason": "${event.data()?["reason"] ?? ""}",
                  "snapshotCancelledByWho":
                      "${event.data()?["cancelled_by_who"] ?? ""}",
                  "shouldConfirmCancelledWithBackend":
                      shouldConfirmCancelledWithBackend,
                },
              );
              if (shouldConfirmCancelledWithBackend) {
                await _refreshOngoingOrderFromSignal(
                  reason: "firestore_cancelled_confirmation",
                  forceStop: forceStop,
                );
                return;
              }
              if (_isCancelledStatusMismatch(
                currentStatus: currentStatus,
                firestoreStatus: nextStatus,
              )) {
                notifyListeners();
                unawaited(
                  _refreshOngoingOrderFromSignal(
                    reason: "cancelled_status_mismatch",
                    forceStop: forceStop,
                  ),
                );
                return;
              }
              ongoingOrder?.status = "cancelled";
              final nextReason = "${event.data()?["reason"] ?? ""}".trim();
              if (nextReason.isNotEmpty && nextReason.toLowerCase() != "null") {
                ongoingOrder?.reason = nextReason;
              }
              final nextCancelledByWho =
                  "${event.data()?["cancelled_by_who"] ?? ""}".trim();
              if (nextCancelledByWho.isNotEmpty &&
                  nextCancelledByWho.toLowerCase() != "null") {
                ongoingOrder?.cancelledByWho = nextCancelledByWho;
              }
              StorageService.prefs?.setString(
                "orderSyncedAt",
                "${event.data()?["syncedAt"]}",
              );
              _tempCancelDebug(
                "FirestoreCancelledBeforeHandleState",
                details: {
                  "nextReason": nextReason,
                  "nextCancelledByWho": nextCancelledByWho,
                },
              );
              await _handleCancelledOrderState(ongoingOrder);
              return;
            }
            final hasStatusChange = hasMeaningfulNextStatus &&
                !shouldIgnoreStatusRegression &&
                currentStatus != nextStatus;
            if (ongoingOrder != null && hasStatusChange) {
              ongoingOrder?.status = nextStatus;
              notifyListeners();
            }
            final hasSyncedAtChange = nextOrderSyncedAt.isNotEmpty &&
                nextOrderSyncedAt != previousOrderSyncedAt;
            if (!isCompletedReceiptStatus(nextStatus) &&
                hasStatusChange &&
                currentStatus == "pending" &&
                nextStatus != "pending") {
              _scheduleDelayedSignalRefresh(
                reason: "pending_status_changed",
                forceStop: forceStop,
              );
              await _refreshOngoingOrderFromSignal(
                reason: "pending_status_changed",
                forceStop: forceStop,
              );
              return;
            }
            if (!isCompletedReceiptStatus(nextStatus) &&
                hasStatusChange &&
                !hasDriverAssignmentChange) {
              _scheduleDelayedSignalRefresh(
                reason: "status_change_without_driver_change",
                forceStop: forceStop,
              );
              await _refreshOngoingOrderFromSignal(
                reason: "status_change_without_driver_change",
                forceStop: forceStop,
              );
              return;
            } else if (!isCompletedReceiptStatus(nextStatus) &&
                hasDriverAssignmentChange) {
              _scheduleDelayedSignalRefresh(
                reason: hasStatusChange
                    ? "status_change_with_driver_change"
                    : "driver_assignment_change",
                forceStop: forceStop,
              );
              await _refreshOngoingOrderFromSignal(
                reason: hasStatusChange
                    ? "status_change_with_driver_change"
                    : "driver_assignment_change",
                forceStop: forceStop,
              );
              return;
            } else if (!isCompletedReceiptStatus(nextStatus) &&
                (hasStatusChange || hasDriverAssignmentChange)) {
              _scheduleDelayedSignalRefresh(
                reason: "fallback_status_or_driver_change",
                forceStop: forceStop,
              );
              await _refreshOngoingOrderFromSignal(
                reason: "fallback_status_or_driver_change",
                forceStop: forceStop,
              );
              return;
            } else if (!isCompletedReceiptStatus(nextStatus) &&
                hasSyncedAtChange) {
              _scheduleDelayedSignalRefresh(
                reason: "synced_at_changed",
                forceStop: forceStop,
              );
              await _refreshOngoingOrderFromSignal(
                reason: "synced_at_changed",
                forceStop: forceStop,
              );
              return;
            } else {
              if (isCompletedReceiptStatus(nextStatus)) {
                await _refreshOngoingOrderFromSignal(
                  reason: "completed_status_detected",
                  forceStop: forceStop,
                );
                return;
              }
            }
            if ("cancelled" == nextStatus ||
                isCompletedReceiptStatus(nextStatus)) {
              ongoingOrder?.status = nextStatus;
              notifyListeners();
            }
            _reconcilePendingOngoingOrderFareOverride();
            final previousHydratedOrderMeta = hasHydratedOngoingOrderMeta;
            hasHydratedOngoingOrderMeta = true;
            if (previousUserSeen != userSeen ||
                previousDriverMessage != dvrMessage ||
                previousCancelRequestStatus != cancelRequestStatus ||
                previousHydratedOrderMeta != hasHydratedOngoingOrderMeta) {
              notifyListeners();
            }
            StorageService.prefs?.setString(
              "orderSyncedAt",
              nextOrderSyncedAt,
            );
          } catch (_) {}
        },
      );
    }
    syncDriverLocation(forceStop: forceStop);
  }

  loadUIByOngoingOrderStatus({
    bool forceStop = false,
    bool forceRedraw = false,
  }) async {
    if (ongoingOrder != null) {
      final currentDriverId =
          "${ongoingOrder?.driverId ?? ongoingOrder?.driver?.id ?? ""}".trim();
      if (ongoingOrder?.driver == null &&
          currentDriverId.isNotEmpty &&
          currentDriverId.toLowerCase() != "null") {
        await _applyDriverAssignmentFromFirestore(currentDriverId);
      }
      if (ongoingOrder?.driver == null) {
        final polledOrderCode = ongoingOrder?.code?.trim() ?? "";
        pickupAddress = Address(
          addressLine: ongoingOrder?.taxiOrder?.pickupAddress,
          coordinates: Coordinates(
            ongoingOrder?.taxiOrder?.pickupLatitude ?? 0.0,
            ongoingOrder?.taxiOrder?.pickupLongitude ?? 0.0,
          ),
        );
        dropoffAddress = Address(
          addressLine: ongoingOrder?.taxiOrder?.dropoffAddress,
          coordinates: Coordinates(
            ongoingOrder?.taxiOrder?.dropoffLatitude ?? 0.0,
            ongoingOrder?.taxiOrder?.dropoffLongitude ?? 0.0,
          ),
        );
        syncPickupDisplayFromAddress();
        if (pickupAddress != null && dropoffAddress != null) {
          await drawDropPolyLines(
            "pickup-dropoff",
            pickupAddress!.latLng,
            dropoffAddress!.latLng,
            null,
            autoFitMap: true,
            autoFitAnimated: true,
          );
        }
        if (_isPollingOngoingOrderWithoutDriver) {
          return;
        }
        _isPollingOngoingOrderWithoutDriver = true;
        try {
          await Future.delayed(
            const Duration(seconds: 5),
          );
          final currentOrderCode = ongoingOrder?.code?.trim() ?? "";
          final currentDriverId =
              "${ongoingOrder?.driverId ?? ongoingOrder?.driver?.id ?? ""}"
                  .trim();
          final shouldSkipPolling = polledOrderCode.isEmpty ||
              currentOrderCode != polledOrderCode ||
              ongoingOrder?.driver != null ||
              (currentDriverId.isNotEmpty &&
                  currentDriverId.toLowerCase() != "null");
          if (shouldSkipPolling) {
            return;
          }
          await getOngoingOrder(
            showSnack: true,
            forceStop: forceStop,
          );
        } finally {
          _isPollingOngoingOrderWithoutDriver = false;
        }
      } else {
        _isPollingOngoingOrderWithoutDriver = false;
        pickupAddress = Address(
          addressLine: ongoingOrder?.taxiOrder?.pickupAddress,
          coordinates: Coordinates(
            ongoingOrder?.taxiOrder?.pickupLatitude ?? 0.0,
            ongoingOrder?.taxiOrder?.pickupLongitude ?? 0.0,
          ),
        );
        dropoffAddress = Address(
          addressLine: ongoingOrder?.taxiOrder?.dropoffAddress,
          coordinates: Coordinates(
            ongoingOrder?.taxiOrder?.dropoffLatitude ?? 0.0,
            ongoingOrder?.taxiOrder?.dropoffLongitude ?? 0.0,
          ),
        );
        syncPickupDisplayFromAddress();
        switch (ongoingOrder?.status) {
          case "pending":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              if (_hasAssignedOngoingDriver &&
                  _assignedDriverLatLngOrNull != null) {
                await drawPickPolyLines(
                  "driver-pickup",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  _assignedDriverLatLngOrNull!,
                );
              } else if (ongoingOrder?.taxiOrder?.dropoffLatLng != null) {
                await drawDropPolyLines(
                  "pickup-dropoff",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  ongoingOrder!.taxiOrder!.dropoffLatLng,
                  null,
                );
              }
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "preparing":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              if (_hasAssignedOngoingDriver &&
                  _assignedDriverLatLngOrNull != null) {
                await drawPickPolyLines(
                  "driver-pickup",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  _assignedDriverLatLngOrNull!,
                );
              } else if (ongoingOrder?.taxiOrder?.dropoffLatLng != null) {
                await drawDropPolyLines(
                  "pickup-dropoff",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  ongoingOrder!.taxiOrder!.dropoffLatLng,
                  null,
                );
              }
              _centerOngoingOrderForStatusChange();
            }
          case "ready":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              if (_hasAssignedOngoingDriver &&
                  _assignedDriverLatLngOrNull != null) {
                await drawPickPolyLines(
                  "driver-pickup",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  _assignedDriverLatLngOrNull!,
                );
              } else if (ongoingOrder?.taxiOrder?.dropoffLatLng != null) {
                await drawDropPolyLines(
                  "pickup-dropoff",
                  ongoingOrder!.taxiOrder!.pickupLatLng,
                  ongoingOrder!.taxiOrder!.dropoffLatLng,
                  null,
                );
              }
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "enroute":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawDropPolyLines(
                "pickup-dropoff",
                ongoingOrder?.taxiOrder?.pickupLatLng ?? pickupAddress!.latLng,
                ongoingOrder?.taxiOrder?.dropoffLatLng ??
                    dropoffAddress!.latLng,
                _assignedDriverLatLngOrNull,
              );
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "delivered":
          case "completed":
          case "successful":
            cHeaders = null;
            notifyListeners();
            if (lastStatus != ongoingOrder?.status) {
              _cacheDeliveredReceiptOrderIfValid(ongoingOrder);
              try {
                final lastOrder = await taxiRequest.lastOrderRequest();
                if (_isValidCompletedReceiptOrder(lastOrder)) {
                  ongoingOrder = lastOrder;
                  deliveredReceiptOrder = lastOrder;
                } else if (_isValidCompletedReceiptOrder(
                    deliveredReceiptOrder)) {
                  ongoingOrder = deliveredReceiptOrder;
                }
              } catch (_) {
                if (_isValidCompletedReceiptOrder(deliveredReceiptOrder)) {
                  ongoingOrder = deliveredReceiptOrder;
                }
              }
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              stopAllListeners();
            }
            break;
          case "failed":
            cHeaders = null;
            notifyListeners();
            ongoingOrder = null;
            break;
          case "cancelled":
            await _handleCancelledOrderState(ongoingOrder);
            break;
          default:
            cHeaders = null;
            notifyListeners();
            ongoingOrder = null;
            break;
        }
      }
    } else {
      final restoredCompletedReceipt = bookingId != 0 &&
          await _restoreCompletedReceiptOrderForCurrentBooking();
      if (restoredCompletedReceipt) {
        cHeaders = null;
        notifyListeners();
        stopAllListeners();
        return;
      }
      cHeaders = null;
      notifyListeners();
      ongoingOrder = null;
      if (bookingId != 0) {
        Order? lastOrder;
        try {
          lastOrder = await taxiRequest.lastOrderRequest();
        } catch (_) {
          lastOrder = null;
        }
        if (lastOrder?.id == bookingId && lastOrder?.status == "cancelled") {
          await _handleCancelledOrderState(lastOrder);
        }
      }
    }
  }

  syncDriverLocation({bool forceStop = false}) {
    final orderCode = ongoingOrder?.code?.trim();
    final driverId =
        "${ongoingOrder?.driverId ?? ongoingOrder?.driver?.id ?? ""}".trim();
    if (ongoingOrder == null ||
        !AuthService.isLoggedIn() ||
        orderCode == null ||
        orderCode.isEmpty ||
        (ongoingOrder?.driver == null &&
            (driverId.isEmpty || driverId.toLowerCase() == "null"))) {
      tempTimerDebug(
        "home.global_driver_sync",
        "cancel_ineligible",
        details: {
          "forceStop": forceStop,
          "orderCode": orderCode,
          "status": ongoingOrder?.status,
          "driverId": driverId,
          "isLoggedIn": AuthService.isLoggedIn(),
        },
      );
      globalTimer?.cancel();
      globalTimer = null;
      _driverLocationSyncOrderCode = null;
      _lastDriverSyncOrderRefreshAt = null;
      _isSyncingDriverLocation = false;
      return;
    }

    if (globalTimer != null &&
        globalTimer!.isActive &&
        _driverLocationSyncOrderCode == orderCode) {
      tempTimerDebug(
        "home.global_driver_sync",
        "skip_existing_active",
        details: {
          "forceStop": forceStop,
          "orderCode": orderCode,
        },
      );
      return;
    }

    final instanceId = nextTempTimerInstanceId("home.global_driver_sync");
    tempTimerDebug(
      "home.global_driver_sync",
      "schedule",
      details: {
        "instanceId": instanceId,
        "forceStop": forceStop,
        "orderCode": orderCode,
        "seconds":
            AppStrings.homeSettingsObject?["ongoing_trip_sync_seconds"] ?? 5,
      },
    );
    globalTimer?.cancel();
    _driverLocationSyncOrderCode = orderCode;

    Future<void> syncTick() async {
      tempTimerDebug(
        "home.global_driver_sync",
        "tick_start",
        details: {
          "instanceId": tempTimerInstanceId(globalTimer) ?? instanceId,
          "forceStop": forceStop,
          "orderCode": orderCode,
          "isSyncing": _isSyncingDriverLocation,
        },
      );
      if (_isSyncingDriverLocation) {
        tempTimerDebug(
          "home.global_driver_sync",
          "tick_skip_busy",
          details: {
            "orderCode": orderCode,
          },
        );
        return;
      }
      if (ongoingOrder == null || !AuthService.isLoggedIn()) {
        tempTimerDebug(
          "home.global_driver_sync",
          "tick_cancel_missing_order_or_auth",
          details: {
            "orderCode": orderCode,
            "hasOrder": ongoingOrder != null,
            "isLoggedIn": AuthService.isLoggedIn(),
          },
        );
        globalTimer?.cancel();
        globalTimer = null;
        _driverLocationSyncOrderCode = null;
        _lastDriverSyncOrderRefreshAt = null;
        return;
      }

      _isSyncingDriverLocation = true;
      try {
        final shouldRefreshOngoingOrderStatus = ongoingOrder != null &&
            !isCompletedReceiptStatus(ongoingOrder?.status) &&
            _normalizeOrderStatus(ongoingOrder?.status) != "cancelled" &&
            _normalizeOrderStatus(ongoingOrder?.status) != "failed";
        ApiResponse apiResponse = await taxiRequest.syncDriverLocationRequest();
        if (apiResponse.allGood) {
          final currentDriver = ongoingOrder?.driver;
          if (currentDriver == null) {
            _latestSyncedDriverLatLng = null;
            tempTimerDebug(
              "home.global_driver_sync",
              "tick_driver_missing",
              details: {
                "orderCode": orderCode,
                "shouldRefreshOngoingOrderStatus":
                    shouldRefreshOngoingOrderStatus,
              },
            );
            if (shouldRefreshOngoingOrderStatus) {
              unawaited(
                _refreshOngoingOrderFromSignal(
                  reason: "driver_sync_without_driver_status_check",
                  forceStop: forceStop,
                ),
              );
            }
            return;
          }
          final nextLat = apiResponse.body['lat'] is num
              ? (apiResponse.body['lat'] as num).toDouble()
              : double.tryParse("${apiResponse.body['lat']}") ?? 0.0;
          final nextLng = apiResponse.body['long'] is num
              ? (apiResponse.body['long'] as num).toDouble()
              : double.tryParse("${apiResponse.body['long']}") ?? 0.0;
          currentDriver.lat = nextLat;
          currentDriver.lng = nextLng;
          if (nextLat == 0.0 && nextLng == 0.0) {
            _latestSyncedDriverLatLng = null;
            return;
          }
          _latestSyncedDriverLatLng = gmaps.LatLng(
            nextLat,
            nextLng,
          );
          driverPositionRotation = apiResponse.body['rotation'] ?? 0;
          updateDriverMarkerPosition(
            _latestSyncedDriverLatLng!,
            rotationDegrees: driverPositionRotation,
          );
          if (shouldRefreshOngoingOrderStatus) {
            tempTimerDebug(
              "home.global_driver_sync",
              "tick_request_refresh",
              details: {
                "orderCode": orderCode,
                "reason": "driver_sync_status_check",
              },
            );
            if (_shouldTriggerOngoingOrderRefreshFromDriverSync(
              orderCode: orderCode,
            )) {
              _lastDriverSyncOrderRefreshAt = DateTime.now();
              unawaited(
                _refreshOngoingOrderFromSignal(
                  reason: "driver_sync_status_check",
                  forceStop: forceStop,
                ),
              );
            } else {
              tempTimerDebug(
                "home.global_driver_sync",
                "tick_skip_refresh_throttled",
                details: {
                  "instanceId": tempTimerInstanceId(globalTimer) ?? instanceId,
                  "orderCode": orderCode,
                  "reason": "driver_sync_status_check",
                },
              );
            }
          }
        } else {
          tempTimerDebug(
            "home.global_driver_sync",
            "tick_cancel_api_not_good",
            details: {
              "orderCode": orderCode,
            },
          );
          globalTimer?.cancel();
          globalTimer = null;
          _driverLocationSyncOrderCode = null;
          _latestSyncedDriverLatLng = null;
          _lastDriverSyncOrderRefreshAt = null;
        }
      } catch (_) {
        tempTimerDebug(
          "home.global_driver_sync",
          "tick_error",
          details: {
            "orderCode": orderCode,
          },
        );
      } finally {
        _isSyncingDriverLocation = false;
      }
    }

    unawaited(syncTick());
    globalTimer = Timer.periodic(
      Duration(
        seconds:
            AppStrings.homeSettingsObject?["ongoing_trip_sync_seconds"] ?? 5,
      ),
      (_) {
        unawaited(syncTick());
      },
    );
    if (globalTimer != null) {
      attachTempTimerInstanceId(globalTimer!, instanceId);
    }
  }

  void startListeningToUser() async {
    if (userUpdateStream != null && !userUpdateStream!.isPaused) {
      return;
    }
    userUpdateStream = fbStore
        .collection("users")
        .doc("${AuthService.currentUser?.id}")
        .snapshots()
        .listen(
      (event) async {
        final previousMarkupAmount = providerMarkupAmount;
        user = event.data();
        syncProviderPaymentMode();
        final markupChanged =
            (previousMarkupAmount - providerMarkupAmount).abs() > 0.0001;
        if (markupChanged && selectedVehicle != null) {
          calculateTotalAmount(
            notify: false,
          );
        } else {
          _syncDriverDistantFareNotifier();
        }
        if (isBool(AuthService.currentUser?.isProvider) &&
            user?["today"] !=
                DateFormat("MMMM d, yyyy").format(DateTime.now())) {
          fbStore
              .collection("users")
              .doc("${AuthService.currentUser?.id}")
              .update(
            {
              "today": DateFormat("MMMM d, yyyy").format(DateTime.now()),
            },
          );
        }
        if (isBool(AuthService.currentUser?.isProvider) &&
            user?["month"] != DateFormat("MMMM").format(DateTime.now())) {
          fbStore
              .collection("users")
              .doc("${AuthService.currentUser?.id}")
              .update(
            {
              "month": DateFormat("MMMM").format(DateTime.now()),
            },
          );
        }
        notifyListeners();
        String userSyncedAt = StorageService.prefs?.getString(
              "userSyncedAt",
            ) ??
            "Not Yet Synced";
        try {
          if (userSyncedAt != "${event.data()?["syncedAt"]}") {
            final wasProvider = isBool(AuthService.currentUser?.isProvider);
            final fetchedUser = await authRequest.getUser();
            await AuthService().saveUserToStorage(
              jsonEncode(
                fetchedUser,
              ),
            );
            await AuthService.getUserFromStorage();
            try {
              final homeSettingsResponse =
                  await settingsRequest.homeSettingsRequest();
              await AppStrings.saveHomeSettingsToStorage(
                jsonEncode(homeSettingsResponse.body),
              );
              await AppStrings.getHomeSettingsFromStorage();

              final appSettingsResponse =
                  await settingsRequest.appSettingsRequest();
              await AppStrings.saveAppSettingsToStorage(
                jsonEncode(appSettingsResponse.body),
              );
              await AppStrings.getAppSettingsFromStorage();
              gBanners = await settingsRequest.bannersRequest();
            } catch (_) {}
            final isProvider = isBool(AuthService.currentUser?.isProvider);
            syncProviderPaymentMode();
            if (wasProvider != isProvider) {
              if (isProvider) {
                appliedCoupon = null;
                promoCodeTEC.clear();
              }
              calculateTotalAmount();
            }
            _syncDriverDistantFareNotifier();
            notifyListeners();
            StorageService.prefs?.setString(
              "userSyncedAt",
              "${event.data()?["syncedAt"]}",
            );
            Get.forceAppUpdate();
          }
        } catch (e) {
          if ("$e".toLowerCase().contains("logged out")) {
            await AuthService().logout();
            return;
          }
        }
      },
    );
    try {
      final userDoc = await fbStore
          .collection(
            "users",
          )
          .doc(AuthService.currentUser?.id.toString())
          .get();
      final docRef = userDoc.reference;
      if (userDoc.data() == null) {
        docRef.set(
          {
            "id": AuthService.currentUser?.id,
          },
        );
      }
    } catch (_) {}
  }

  void startListeningToPartner() {
    if (partnerUpdateStream != null && !partnerUpdateStream!.isPaused) {
      return;
    }
    partnerUpdateStream = fbStore
        .collection("partners")
        .doc("${AuthService.currentUser?.id}")
        .snapshots()
        .listen(
      (event) async {
        final previousPaymentMode = providerDisplayPaymentMode;
        final previousMarkupAmount = providerMarkupAmount;
        partner = event.data();
        await _refreshPartnerTodayAmountIfNeeded(partner);
        syncProviderPaymentMode();
        final markupChanged =
            (previousMarkupAmount - providerMarkupAmount).abs() > 0.0001;
        if ((previousPaymentMode != providerDisplayPaymentMode ||
                markupChanged) &&
            selectedVehicle != null) {
          calculateTotalAmount();
        } else {
          _syncDriverDistantFareNotifier();
        }
        notifyListeners();
      },
    );
  }

  Future<void> _refreshPartnerTodayAmountIfNeeded(
    Map<String, dynamic>? partnerData,
  ) async {
    if (!isBool(AuthService.currentUser?.isProvider) ||
        partnerData == null ||
        _isRefreshingPartnerTodayAmount) {
      return;
    }

    final todayLabel = DateFormat("MMMM d, yyyy").format(DateTime.now());
    final monthLabel = DateFormat("MMMM").format(DateTime.now());
    final needsTodayRefresh = "${partnerData["today"] ?? ""}" != todayLabel;
    final needsMonthRefresh = "${partnerData["month"] ?? ""}" != monthLabel;
    if (!needsTodayRefresh && !needsMonthRefresh) {
      return;
    }

    _isRefreshingPartnerTodayAmount = true;
    try {
      final partnerId = "${AuthService.currentUser?.id ?? ""}";
      if (partnerId.isEmpty) {
        return;
      }

      final transactionsSnapshot = await fbStore
          .collection("partners")
          .doc(partnerId)
          .collection("transactions_v2")
          .get();

      final now = DateTime.now();
      var todayTotal = 0.0;
      var monthTotal = 0.0;
      var totalAmount = 0.0;
      final currentMonthKey = DateFormat("yyyy-MM").format(now);
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data["amount"] as num?)?.toDouble() ?? 0;
        if (amount <= 0 || data["is_credit"] != true) {
          continue;
        }
        totalAmount += amount;
        final createdAt = _dateTimeFromPartnerTransactionValue(
          data["created_at"],
        );
        if (createdAt == null) {
          continue;
        }
        if (DateFormat("yyyy-MM").format(createdAt) == currentMonthKey) {
          monthTotal += amount;
        }
        if (createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day) {
          todayTotal += amount;
        }
      }

      final updatedAt = Timestamp.now();
      final batch = fbStore.batch();
      batch.set(
        fbStore.collection("partners").doc(partnerId),
        {
          "today": todayLabel,
          "month": monthLabel,
          "today_amount": todayTotal,
          "month_amount": monthTotal,
          "total_amount": totalAmount,
          "updated_at": updatedAt,
        },
        SetOptions(merge: true),
      );
      batch.set(
        fbStore.collection("users").doc(partnerId),
        {
          "today_amount": todayTotal,
          "month_amount": monthTotal,
          "total_amount": totalAmount,
          "updated_at": updatedAt,
          if (partnerData.containsKey("markup_amount"))
            "markup_amount": partnerData["markup_amount"],
          if (partnerData.containsKey("payment_mode"))
            "payment_mode": partnerData["payment_mode"],
          if ("${partnerData["partner_name"] ?? ""}".trim().isNotEmpty)
            "partner_name": partnerData["partner_name"],
          if ("${partnerData["partner_name"] ?? ""}".trim().isNotEmpty)
            "name": partnerData["partner_name"],
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } finally {
      _isRefreshingPartnerTodayAmount = false;
    }
  }

  DateTime? _dateTimeFromPartnerTransactionValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _cancelDelayedSignalRefreshTimer();
    globalTimer?.cancel();
    globalTimer = null;
    dbTimer?.cancel();
    orderUpdateStream?.cancel();
    partnerUpdateStream?.cancel();
    userUpdateStream?.cancel();
    _driverLocationSyncOrderCode = null;
    _isSyncingDriverLocation = false;
    _latestSyncedDriverLatLng = null;
    driverDistantFareNotifier.dispose();
    promoCodeTEC.dispose();
    super.dispose();
  }

  String get providerDisplayPaymentMode {
    final paymentMode =
        "${partner?["payment_mode"] ?? user?["payment_mode"] ?? ""}"
            .toLowerCase();
    return paymentMode == "cash" ? "cash" : "load";
  }

  ChatEntity? _buildUserChatEntity() {
    if (ongoingOrder == null) {
      return null;
    }

    final peers = {
      '${ongoingOrder?.user?.id}': PeerUser(
        id: '${ongoingOrder?.user?.id}',
        name: '${ongoingOrder?.user?.name}',
        image: ongoingOrder?.user?.photo ?? "",
      ),
      '${ongoingOrder?.driver?.id}': PeerUser(
        id: "${ongoingOrder?.driver?.id}",
        name: '${ongoingOrder?.driver?.name}',
        image: ongoingOrder?.driver?.photo ?? "",
      ),
    };

    return ChatEntity(
      onMessageSent: (message, chatEntity) {
        unawaited(
          fbStore.collection("orders").doc(ongoingOrder?.code).update(
            {
              "driverSeen": false,
              "userMessage": message,
            },
          ).catchError((_) {}),
        );
        ChatService.sendChatMessage(
          message,
          chatEntity,
        );
      },
      mainUser: peers['${ongoingOrder?.user?.id}'],
      peers: peers,
      path: 'orders/${ongoingOrder?.code}/customerDriver/chats',
      title: "Chat with driver",
    );
  }

  Future<void> sendQuickChatMessage(
    String message, {
    bool isRequestCancellation = false,
    bool openChatAfter = false,
  }) async {
    final trimmedMessage = message.trim();
    if (isSendingQuickChat || trimmedMessage.isEmpty || ongoingOrder == null) {
      return;
    }
    final isCancellationRequest =
        isRequestCancellation || isRequestCancellationMessage(trimmedMessage);
    if (isCancellationRequest && hasAcceptedCancelRequest) {
      return;
    }

    final chatEntity = _buildUserChatEntity();
    if (chatEntity == null) {
      return;
    }

    isSendingQuickChat = true;
    notifyListeners();
    try {
      await fbStore.collection("orders").doc(ongoingOrder?.code).update(
        {
          "userSeen": true,
          "driverSeen": false,
          "userMessage": trimmedMessage,
          if (isCancellationRequest) "cancel_request_status": "pending",
        },
      );
      userSeen = true;
      _latestFirestoreUserSeen = true;
      notifyListeners();

      final chatRef = fbStore.collection("${chatEntity.path}/Activity");
      final chatMessage = ChatMessage(
        text: trimmedMessage,
        user: chatEntity.mainUser!.toChatUser(),
        createdAt: DateTime.now().toUtc(),
      );

      await chatRef.doc().set(Chat.jsonFrom(chatMessage)).timeout(
            const Duration(seconds: 30),
          );
      chatEntity.onMessageSent(
        trimmedMessage,
        chatEntity,
      );
      if (openChatAfter && !isChatViewOpen) {
        await chatDriver();
      }
    } finally {
      isSendingQuickChat = false;
      notifyListeners();
    }
  }

  Future<void> updateRequestCancellationStatus(
    String status, {
    bool openChatAfter = false,
  }) async {
    if (ongoingOrder == null || isUpdatingRequestCancellation) {
      return;
    }

    isUpdatingRequestCancellation = true;
    notifyListeners();
    try {
      await fbStore.collection("orders").doc(ongoingOrder?.code).update(
        {
          "cancel_request_status": status,
          "userSeen": true,
        },
      );
      userSeen = true;
      _latestFirestoreUserSeen = true;

      final chatEntity = _buildUserChatEntity();
      if (chatEntity != null) {
        final currentUserName =
            (AuthService.currentUser?.name ?? "User").trim();
        final otherParticipantName =
            (ongoingOrder?.driver?.name ?? "Driver").trim();
        final chatRef = fbStore.collection("${chatEntity.path}/Activity");
        final chatMessage = ChatMessage(
          text:
              "$currentUserName $status $otherParticipantName's cancel request!",
          user: chatEntity.mainUser!.toChatUser(),
          createdAt: DateTime.now().toUtc(),
        );

        await chatRef.doc().set(Chat.jsonFrom(chatMessage)).timeout(
              const Duration(seconds: 30),
            );
        chatEntity.onMessageSent(
          chatMessage.text,
          chatEntity,
        );
      }
      if (openChatAfter && !isChatViewOpen) {
        await chatDriver();
      }
    } finally {
      isUpdatingRequestCancellation = false;
      notifyListeners();
    }
  }

  Future<void> chatDriver() async {
    await waitForLoadingDialogToClose();
    if (ongoingOrder == null || Get.context == null) {
      return;
    }
    setChatViewOpen(true);
    notifyListeners();
    unawaited(
      fbStore.collection("orders").doc(ongoingOrder?.code).update(
        {
          "userSeen": true,
        },
      ).catchError((_) {}),
    );
    userSeen = true;
    _latestFirestoreUserSeen = true;
    notifyListeners();
    final chatEntity = _buildUserChatEntity();
    if (chatEntity == null) {
      setChatViewOpen(false);
      return;
    }
    await Navigator.push(
      Get.context!,
      PageRouteBuilder(
        reverseTransitionDuration: Duration.zero,
        transitionDuration: Duration.zero,
        pageBuilder: (
          context,
          a,
          b,
        ) =>
            ChatView(
          chatEntity,
          ongoingOrder!,
        ),
      ),
    );
    setChatViewOpen(false);
  }
}
