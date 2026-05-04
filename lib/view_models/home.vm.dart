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
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';

class HomeViewModel extends GMapViewModel {
  final ValueNotifier<double?> driverDistantFareNotifier = ValueNotifier(0.0);
  bool? userSeen;
  Timer? dbTimer;
  int paymentId = 1;
  int providerRiderTypeId = 1;
  String? dvrMessage;
  String? lastStatus;
  String cancelRequestStatus = "";
  String passRequestStatus = "";
  Order? ongoingOrder;
  double rating = 5.0;
  int vehicleIndex = 0;
  bool snackShown = true;
  bool isDisabled = false;
  bool isPreparing = false;
  bool blockCamera = false;
  bool showAnalytics = false;
  bool isUpdatingRequestCancellation = false;
  bool isUpdatingRequestPass = false;
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
  Future<void>? _initialOngoingOrderFuture;
  bool isResolvingInitialOngoingOrder = false;
  bool _isDraggingOngoingMap = false;
  bool _isRefreshingPartnerTodayAmount = false;
  bool _isSyncingDriverLocation = false;
  bool hasHydratedOngoingOrderMeta = false;
  double? _pendingBookingFareOverride;
  double? _pendingOngoingOrderFareOverride;
  String? _driverLocationSyncOrderCode;
  gmaps.LatLng? _latestSyncedDriverLatLng;

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

  bool get hasAcceptedCancelRequest =>
      cancelRequestStatus.trim().toLowerCase() == "accepted";

  bool get hasAcceptedPassRequest =>
      passRequestStatus.trim().toLowerCase() == "accepted";

  bool get hasDriverChatMessage {
    final message = (dvrMessage ?? "").trim().toLowerCase();
    return message.isNotEmpty && message != "null";
  }

  bool get canCancelAfterWaitWithoutDriverChat =>
      !hasDriverChatMessage &&
      _remainingCancelSecondsForOrder(ongoingOrder) == 0 &&
      !isEnrouteOrBeyondStatus(ongoingOrder?.status);

  bool get canRebookAfterWaitWithoutDriverChat =>
      !hasDriverChatMessage &&
      _remainingRebookSecondsForOrder(ongoingOrder) == 0 &&
      !isEnrouteOrBeyondStatus(ongoingOrder?.status);

  bool get canCancelWithAcceptedRequest =>
      hasAcceptedCancelRequest &&
      !isEnrouteOrBeyondStatus(ongoingOrder?.status);

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
      final ongoingTotal = ongoingOrder?.total ?? 0;
      if (isBool(AuthService.currentUser?.isProvider) &&
          (ongoingOrder?.discount ?? 0) == 0) {
        return ongoingTotal + providerMarkupAmount;
      }
      return ongoingTotal;
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

  double get currentOngoingOrderPayableFare {
    final ongoingTotal = ongoingOrder?.total ?? 0;
    if (isBool(AuthService.currentUser?.isProvider) &&
        (ongoingOrder?.discount ?? 0) == 0) {
      return ongoingTotal + providerMarkupAmount;
    }
    return ongoingTotal;
  }

  double get displayedOngoingOrderPayableFare {
    final overrideFare = _pendingOngoingOrderFareOverride;
    if (overrideFare != null && overrideFare > currentOngoingOrderPayableFare) {
      return overrideFare;
    }
    return currentOngoingOrderPayableFare;
  }

  double get displayedPendingDriverOngoingOrderFare {
    if (ongoingOrder == null || ongoingOrder?.driver != null) {
      return displayedOngoingOrderPayableFare;
    }
    final candidates = <double>[
      displayedOngoingOrderPayableFare,
      _pendingOngoingOrderFareOverride ?? 0,
      _pendingBookingFareOverride ?? 0,
      total ?? 0,
    ];
    var resolvedFare = 0.0;
    for (final candidate in candidates) {
      if (candidate > resolvedFare) {
        resolvedFare = candidate;
      }
    }
    return resolvedFare > 0 ? resolvedFare : displayedOngoingOrderPayableFare;
  }

  gmaps.LatLng get _effectiveDriverLatLng {
    return _latestSyncedDriverLatLng ?? ongoingOrder!.driverLatLng;
  }

  void _syncDriverDistantFareNotifier() {
    final nextFare = _driverDistantPayableFare;
    if (driverDistantFareNotifier.value == nextFare) {
      return;
    }
    driverDistantFareNotifier.value = nextFare;
  }

  void _applyPendingDriverDistantFareOverride() {
    if (ongoingOrder == null || availableDriver == null) {
      return;
    }
    final pickupFee =
        (availableDriver?.pickupChargeFee?.ceil() ?? 0).toDouble();
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
    final pickupFee =
        (availableDriver?.pickupChargeFee?.ceil() ?? 0).toDouble();
    if (pickupFee <= 0) {
      return;
    }
    final acceptedFare = _driverDistantPayableFare + pickupFee;
    if (acceptedFare <= 0) {
      return;
    }
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
    final normalizedTotal = hasOrderSubTotal
        ? overrideFare
        : isBool(AuthService.currentUser?.isProvider) &&
                (ongoingOrder?.discount ?? 0) == 0
            ? overrideFare - providerMarkupAmount
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
        (ongoingOrder?.status ?? "").trim().toLowerCase() == "cancelled" ||
        currentOngoingOrderPayableFare >= overrideFare) {
      _pendingOngoingOrderFareOverride = null;
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
    if (!hasHydratedOngoingOrderMeta) {
      return true;
    }
    final status = (ongoingOrder?.status ?? "").trim().toLowerCase();
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

  Future<void> ensureInitialOngoingOrderLoaded() async {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    _initialOngoingOrderFuture ??= _resolveInitialOngoingOrder();
    await _initialOngoingOrderFuture;
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
      LoadViewModel().getLoadBalance();
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
  Future<void> recenterHomeMap() async {
    cancelPendingCameraMove();
    setDraggingOngoingMap(false);
    final status = (ongoingOrder?.status ?? "").toLowerCase();
    final pickupLatLng = ongoingOrder?.taxiOrder?.pickupLatLng;
    final dropoffLatLng = ongoingOrder?.taxiOrder?.dropoffLatLng;
    final driverLatLng = ongoingOrder?.driverLatLng;

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

    await super.recenterHomeMap();
  }

  bool _fitOngoingOrderBoundsByStatus({
    required String status,
    required gmaps.LatLng pickupLatLng,
    gmaps.LatLng? dropoffLatLng,
    gmaps.LatLng? driverLatLng,
    EdgeInsets padding = const EdgeInsets.fromLTRB(75, 90, 75, 90),
  }) {
    final controller = map;
    if (controller == null) {
      return false;
    }

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
        padding: padding,
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
      driverLatLng: order.driverLatLng,
      padding: const EdgeInsets.fromLTRB(75, 90, 75, 90),
    );
  }

  void resetUnavailableLocationState() {
    clearGMapDetails();
    pickupAddress = null;
    dropoffAddress = null;
    selectedVehicle = null;
    vehicleTypes = [];
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
    await AlertService().showDriverDistantDialog(
      availableDriver: availableDriver!,
      totalAmountListenable: driverDistantFareNotifier,
      originalFare: _driverDistantDialogBaseFare,
      newBaseFare: _driverDistantDialogBaseFare,
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
    await drawDropPolyLines(
      "pickup-dropoff",
      pickupAddress!.latLng,
      dropoffAddress!.latLng,
      null,
    );
    fitCurrentRouteBounds(
      padding: const EdgeInsets.fromLTRB(75, 90, 75, 90),
    );
    await fetchVehicleTypesPricing();
    isPreparing = false;
    notifyListeners();
  }

  Future<void> _handleCancelledOrderState(
    Order? cancelledOrder,
  ) async {
    final reason = (cancelledOrder?.reason ?? "").toLowerCase();
    final shouldRestorePreview = reason != "rebook";
    final shouldShowAlert = reason != "rebook";

    cHeaders = null;
    ongoingOrder = null;
    bookingId = 0;
    snackShown = true;
    notifyListeners();
    stopAllListeners();

    if (shouldRestorePreview) {
      unawaited(_restoreCancelledBookingRoutePreview());
    }

    if (!shouldShowAlert) {
      return;
    }

    if (!isChatViewOpen) {
      Get.until((route) => route.isFirst);
    }

    AlertService().showAppAlert(
      dismissible: false,
      title: "Booking ${reason == "pass" ? "Passed" : "Cancelled"}",
      asset: reason == "pass" ? AppLotties.success : AppLotties.error,
      content:
          "Your booking has been ${reason == "pass" ? "passed" : "cancelled"}",
      confirmAction: () async {
        if (!isChatViewOpen) {
          Get.until((route) => route.isFirst);
        }
      },
    );
  }

  double _normalizeWholePeso(double value) {
    return value.floorToDouble();
  }

  double _normalizeStaffWholePeso(double value) {
    return value.ceilToDouble();
  }

  calculateTotalAmount() {
    final rawSubTotal = selectedVehicle?.total ?? 0;
    subTotal = rawSubTotal;
    if (isBool(AuthService.currentUser?.isProvider)) {
      if (providerRiderTypeId == 8) {
        final grossTotal = rawSubTotal + 20;
        final discountedTotal = _normalizeStaffWholePeso(grossTotal * 0.95);
        final normalizedDiscount = grossTotal - discountedTotal;
        discount = normalizedDiscount;
        final normalizedSubTotal = discountedTotal + normalizedDiscount - 20;
        subTotal = normalizedSubTotal < 0 ? 0 : normalizedSubTotal;
        total = discountedTotal;
      } else {
        discount = 0;
        total = _normalizeWholePeso(
          rawSubTotal + providerMarkupAmount + 20,
        );
      }
    } else {
      discount = 0;
      total = (rawSubTotal) - (discount ?? 0);
    }
    _reapplyPendingDriverDistantBookingFareOverride();
    syncTotalAmountNotifier();
    _syncDriverDistantFareNotifier();
    notifyListeners();
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
  }) async {
    pickupAddress = pickup;
    dropoffAddress = dropoff;
    isPreparing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await drawDropPolyLines(
      "pickup-dropoff",
      pickup.latLng,
      dropoff.latLng,
      null,
    );
    await fetchVehicleTypesPricing();
    fitCurrentRouteBounds(
      padding: const EdgeInsets.fromLTRB(75, 90, 75, 90),
    );
    isPreparing = false;
    notifyListeners();
  }

  fetchVehicleTypesPricing() async {
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
        calculateTotalAmount();
      }
    } finally {
      setBusyForObject(vehicleTypes, false);
    }
  }

  getOngoingOrder({
    bool refresh = false,
    bool showSnack = false,
    bool forceStop = false,
  }) async {
    setBusyForObject(ongoingOrder, true);
    if (refresh) {
      lastStatus = null;
      notifyListeners();
    }
    try {
      ongoingOrder = (await taxiRequest.ongoingOrderRequest())!;
      hasHydratedOngoingOrderMeta = false;
      _pendingBookingFareOverride = null;
      _applyPendingDriverDistantFareToOngoingOrder();
      _reconcilePendingOngoingOrderFareOverride();
      notifyListeners();
      if (ongoingOrder != null) {
        if (ongoingOrder?.status == "pending" ||
            ongoingOrder?.status == "preparing") {
          lastStatus = null;
          notifyListeners();
        }
        await startHandlingOngoingOrder(forceStop: forceStop);
        await loadUIByOngoingOrderStatus(forceStop: forceStop);
        bookingId = ongoingOrder?.id ?? 0;
        notifyListeners();
      }
    } catch (_) {
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
                      "Searching for vehicles",
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
                      "PPC TODA (Beta) is searching for tricycle drivers near you. If this takes too long, there might be no available tricycle drivers near your current area.",
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
        } catch (_) {
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
            "vehicle_type_id": selectedVehicle?.id,
            "vehicle_type": selectedVehicle?.encrypted,
            "coupon_code": providerRiderTypeId == 8 ? "employee" : null,
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
            "discount": 0.0,
            "coupon_code": null,
            "payment_method": null,
            "payment_method_id": paymentId,
            "total": resolvedBookingPayableFare,
            "sub_total": resolvedBookingPayableFare,
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
        ScaffoldMessenger.of(Get.context!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              apiResponse.message,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (manageLoading) {
        AlertService().stopLoading(forceStop: true);
      }
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  cancelOrder() {
    int remainingCancelSeconds() {
      return _remainingCancelSecondsForOrder(ongoingOrder);
    }

    int remainingRebookSeconds() {
      return _remainingRebookSecondsForOrder(ongoingOrder);
    }

    void showWaitSnackBar(int seconds) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please wait for $seconds second${seconds == 1 ? "" : "s"}!",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final initialRemainingRebookSeconds = remainingRebookSeconds();
    if (!canOpenCancelFlow) {
      final message = hasDriverChatMessage
          ? "Cancellation is unavailable once the driver has already sent a chat."
          : "Please wait for $initialRemainingRebookSeconds second${initialRemainingRebookSeconds == 1 ? "" : "s"}!";
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
      thirdText: "Get a new driver now!",
      content: "Do you want to cancel this booking?",
      hideThird: false,
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: Colors.red,
      thirdAction: () async {
        final latestRemainingRebookSeconds = remainingRebookSeconds();
        if (!canCancelWithAcceptedRequest && latestRemainingRebookSeconds > 0) {
          showWaitSnackBar(latestRemainingRebookSeconds);
        } else {
          Get.until((route) => route.isFirst);
          try {
            AlertService().showLoading();
            await _findAvailableDriverForRebook();
            AlertService().stopLoading(forceStop: true);
            if (availableDriver?.driver != null &&
                availableDriver!.kmDistance != 0) {
              if ((availableDriver?.pickupKm ?? 0.0) <=
                  _driverSearchPickupKmLimit) {
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
            ScaffoldMessenger.of(Get.context!).clearSnackBars();
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
        }
      },
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        final latestRemainingCancelSeconds = remainingCancelSeconds();
        if (!canCancelWithAcceptedRequest && latestRemainingCancelSeconds > 0) {
          showWaitSnackBar(latestRemainingCancelSeconds);
        } else {
          Get.back();
          if (AuthService.inReviewMode()) {
            Get.back();
          } else {
            AlertService().showLoading();
            try {
              ApiResponse apiResponse = await taxiRequest.cancelOrderRequest(
                id: ongoingOrder!.id!,
                reason: "initiated by passenger",
                rebook: false,
              );
              if (!isChatViewOpen) {
                Get.until((route) => route.isFirst);
              }
              if (apiResponse.allGood) {
                ongoingOrder = null;
                AlertService().stopLoading(forceStop: true);
                await loadUIByOngoingOrderStatus();
              } else {
                if (apiResponse.message.contains("cancel")) {
                  clearGMapDetails();
                } else {
                  throw apiResponse.message;
                }
              }
            } catch (e) {
              if (!isChatViewOpen) {
                Get.until((route) => route.isFirst);
              }
              ScaffoldMessenger.of(Get.context!).clearSnackBars();
              ScaffoldMessenger.of(Get.context!).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  content: Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
          }
        }
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
    } catch (_) {
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
      final orderCode = ongoingOrder?.code?.trim();
      if (orderCode != null && orderCode.isNotEmpty) {
        await fbStore.collection("orders").doc(orderCode).update(
          {
            "driver_accept_id": null,
            "driver_accept_latitude": null,
            "driver_accept_longitude": null,
          },
        );
      }
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
      _pendingOngoingOrderFareOverride = null;
      notifyListeners();
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
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
    orderUpdateStream?.cancel();
    partnerUpdateStream?.cancel();
    globalTimer?.cancel();
    globalTimer = null;
    hasHydratedOngoingOrderMeta = false;
    _pendingBookingFareOverride = null;
    _pendingOngoingOrderFareOverride = null;
    _driverLocationSyncOrderCode = null;
    _isSyncingDriverLocation = false;
    _latestSyncedDriverLatLng = null;
  }

  closeOrder() async {
    LoadViewModel().getLoadBalance();
    selectedVehicle = null;
    dropoffAddress = null;
    pickupAddress = null;
    ongoingOrder = null;
    lastCenter = null;
    lastStatus = null;
    cancelRequestStatus = "";
    passRequestStatus = "";
    dvrMessage = null;
    hasHydratedOngoingOrderMeta = false;
    _pendingBookingFareOverride = null;
    _pendingOngoingOrderFareOverride = null;
    cHeaders = null;
    vehicleTypes = [];
    getOngoingOrder();
    clearGMapDetails();
    clearPickupDisplayState();
    Get.forceAppUpdate();
    final target = await zoomToCurrentLocation();
    if (target != null) {
      await mapCameraMove(
        "closeOrder",
        target,
        debounceDuration: Duration.zero,
      );
    }
  }

  startHandlingOngoingOrder({bool forceStop = false}) async {
    if (dbTimer != null && dbTimer!.isActive) {
      dbTimer?.cancel();
    }
    orderUpdateStream?.cancel();
    dbTimer = Timer(
      const Duration(milliseconds: 3000),
      () async {
        orderUpdateStream = fbStore
            .collection("orders")
            .doc("${ongoingOrder?.code}")
            .snapshots()
            .listen(
          (event) async {
            order = event.data();
            String orderSyncedAt = StorageService.prefs?.getString(
                  "orderSyncedAt",
                ) ??
                "Not Yet Synced";
            if (user != null &&
                ongoingOrder?.discount == 0 &&
                providerMarkupAmount > 0 &&
                isBool(AuthService.currentUser?.isProvider) &&
                event.data()?["markup_amount"] == null) {
              fbStore.collection("orders").doc(ongoingOrder?.code).update(
                {
                  "markup_amount": providerMarkupAmount,
                },
              );
            }
            if (ongoingOrder?.discount == 0 &&
                providerMarkupAmount > 0 &&
                isBool(AuthService.currentUser?.isProvider) &&
                event.data()?["markup_amount"] == null) {
              fbStore.collection("orders").doc(ongoingOrder?.code).update(
                {
                  "markup_amount": providerMarkupAmount,
                },
              );
            }
            try {
              final previousUserSeen = userSeen;
              final previousDriverMessage = dvrMessage;
              final previousCancelRequestStatus = cancelRequestStatus;
              final nextStatus = "${event.data()?["status"]}";
              if ((orderSyncedAt != "${event.data()?["syncedAt"]}" &&
                      !isCompletedReceiptStatus(nextStatus)) ||
                  (ongoingOrder?.status != nextStatus &&
                      !isCompletedReceiptStatus(nextStatus))) {
                await getOngoingOrder(forceStop: forceStop);
              } else {
                if (isCompletedReceiptStatus(nextStatus)) {
                  await clearGMapDetails();
                }
              }
              if ("cancelled" == nextStatus ||
                  isCompletedReceiptStatus(nextStatus)) {
                ongoingOrder?.status = nextStatus;
                notifyListeners();
              }
              userSeen = isBool(event.data()?["userSeen"]);
              dvrMessage = "${event.data()?["driverMessage"]}";
              cancelRequestStatus =
                  "${event.data()?["cancel_request_status"] ?? ""}";
              passRequestStatus =
                  "${event.data()?["pass_request_status"] ?? ""}";
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
                "${event.data()?["syncedAt"]}",
              );
            } catch (_) {}
            loadUIByOngoingOrderStatus(forceStop: forceStop);
          },
        );
        syncDriverLocation(forceStop: forceStop);
      },
    );
  }

  loadUIByOngoingOrderStatus({
    bool forceStop = false,
    bool forceRedraw = false,
  }) async {
    if (ongoingOrder != null) {
      if (ongoingOrder?.driver == null) {
        final shouldShowLoading = !isChatViewOpen;
        if (shouldShowLoading) {
          AlertService().showLoading();
        }
        await Future.delayed(
          const Duration(seconds: 5),
        );
        await getOngoingOrder(
          showSnack: true,
          forceStop: forceStop,
        );
        if (shouldShowLoading) {
          AlertService().stopLoading(forceStop: forceStop);
        }
      } else {
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
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                _effectiveDriverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "preparing":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                _effectiveDriverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
          case "ready":
            if (forceRedraw || lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                _effectiveDriverLatLng,
              );
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
                _effectiveDriverLatLng,
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
              ongoingOrder = (await taxiRequest.lastOrderRequest())!;
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
    if (ongoingOrder == null ||
        !AuthService.isLoggedIn() ||
        orderCode == null ||
        orderCode.isEmpty) {
      globalTimer?.cancel();
      globalTimer = null;
      _driverLocationSyncOrderCode = null;
      _isSyncingDriverLocation = false;
      return;
    }

    if (globalTimer != null &&
        globalTimer!.isActive &&
        _driverLocationSyncOrderCode == orderCode) {
      return;
    }

    globalTimer?.cancel();
    _driverLocationSyncOrderCode = orderCode;

    Future<void> syncTick() async {
      if (_isSyncingDriverLocation) {
        return;
      }
      if (ongoingOrder == null || !AuthService.isLoggedIn()) {
        globalTimer?.cancel();
        globalTimer = null;
        _driverLocationSyncOrderCode = null;
        return;
      }

      _isSyncingDriverLocation = true;
      try {
        ApiResponse apiResponse = await taxiRequest.syncDriverLocationRequest();
        unawaited(loadUIByOngoingOrderStatus(forceStop: forceStop));
        if (apiResponse.allGood) {
          ongoingOrder?.driver?.lat = apiResponse.body['lat'];
          ongoingOrder?.driver?.lng = apiResponse.body['long'];
          _latestSyncedDriverLatLng = gmaps.LatLng(
            ongoingOrder?.driver?.lat ?? 0.0,
            ongoingOrder?.driver?.lng ?? 0.0,
          );
          driverPositionRotation = apiResponse.body['rotation'] ?? 0;
          updateDriverMarkerPosition(
            _latestSyncedDriverLatLng!,
            rotationDegrees: driverPositionRotation,
          );
        } else {
          globalTimer?.cancel();
          globalTimer = null;
          _driverLocationSyncOrderCode = null;
          _latestSyncedDriverLatLng = null;
        }
      } catch (_) {
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
        user = event.data();
        syncProviderPaymentMode();
        _syncDriverDistantFareNotifier();
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
            AuthService.currentUser = await authRequest.getUser();
            await AuthService().saveUserToStorage(
              jsonEncode(
                AuthService.currentUser,
              ),
            );
            await AuthService.getUserFromStorage();
            final isProvider = isBool(AuthService.currentUser?.isProvider);
            syncProviderPaymentMode();
            if (wasProvider != isProvider) {
              calculateTotalAmount();
            }
            _syncDriverDistantFareNotifier();
            notifyListeners();
            StorageService.prefs?.setString(
              "userSyncedAt",
              "${event.data()?["syncedAt"]}",
            );
            debugPrint(
              "home userSyncedAt success",
            );
            Get.forceAppUpdate();
          }
        } catch (e) {
          if ("$e".toLowerCase().contains("logged out")) {
            await AuthService().logout();
            return;
          }
          debugPrint(
            "home userSyncedAt error: $e",
          );
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
        partner = event.data();
        await _refreshPartnerTodayAmountIfNeeded(partner);
        syncProviderPaymentMode();
        _syncDriverDistantFareNotifier();
        if (previousPaymentMode != providerDisplayPaymentMode &&
            selectedVehicle != null) {
          calculateTotalAmount();
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
        fbStore.collection("orders").doc(ongoingOrder?.code).update(
          {
            "driverSeen": false,
            "userMessage": message,
          },
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
    bool isRequestPass = false,
    bool openChatAfter = false,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || ongoingOrder == null) {
      return;
    }
    final normalizedMessage = trimmedMessage.toLowerCase();
    final isCancellationRequest =
        isRequestCancellation || normalizedMessage == "request cancellation";
    final isPassRequest = isRequestPass || normalizedMessage == "request pass";
    if (isCancellationRequest && hasAcceptedCancelRequest) {
      return;
    }
    if (isPassRequest && hasAcceptedPassRequest) {
      return;
    }

    final chatEntity = _buildUserChatEntity();
    if (chatEntity == null) {
      return;
    }

    await fbStore.collection("orders").doc(ongoingOrder?.code).update(
      {
        "driverSeen": false,
        "userMessage": trimmedMessage,
        if (isCancellationRequest) "cancel_request_status": "pending",
        if (isPassRequest) "pass_request_status": "pending",
      },
    );

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
  }

  Future<void> updateRequestCancellationStatus(String status) async {
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
    } finally {
      isUpdatingRequestCancellation = false;
      notifyListeners();
    }
  }

  Future<void> updateRequestPassStatus(String status) async {
    if (ongoingOrder == null || isUpdatingRequestPass) {
      return;
    }

    isUpdatingRequestPass = true;
    notifyListeners();
    try {
      await fbStore.collection("orders").doc(ongoingOrder?.code).update(
        {
          "pass_request_status": status,
          "userSeen": true,
        },
      );
      userSeen = true;

      final chatEntity = _buildUserChatEntity();
      if (chatEntity != null) {
        final currentUserName =
            (AuthService.currentUser?.name ?? "User").trim();
        final otherParticipantName =
            (ongoingOrder?.driver?.name ?? "Driver").trim();
        final chatRef = fbStore.collection("${chatEntity.path}/Activity");
        final chatMessage = ChatMessage(
          text:
              "$currentUserName $status $otherParticipantName's pass request!",
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
    } finally {
      isUpdatingRequestPass = false;
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
    fbStore.collection("orders").doc(ongoingOrder?.code).update(
      {
        "userSeen": true,
      },
    );
    userSeen = true;
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
