// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
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
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';

class HomeViewModel extends GMapViewModel {
  bool? userSeen;
  Timer? dbTimer;
  int paymentId = 1;
  int providerRiderTypeId = 1;
  String? dvrMessage;
  String? lastStatus;
  Order? ongoingOrder;
  double rating = 5.0;
  int vehicleIndex = 0;
  bool snackShown = true;
  bool isDisabled = false;
  bool isPreparing = false;
  bool blockCamera = false;
  bool showAnalytics = false;
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
    total = 0;
    subTotal = 0;
    discount = 0;
    locUnavailable = false;
    clearPickupDisplayState();
    restorePickupDisplay();
    notifyListeners();
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
          total = 0;
          subTotal = 0;
          discount = 0;
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
      notifyListeners();
      if (ongoingOrder != null) {
        if (ongoingOrder?.status == "pending" ||
            ongoingOrder?.status == "preparing") {
          lastStatus = null;
          notifyListeners();
        }
        await startHandlingOngoingOrder(forceStop: forceStop);
        await loadUIByOngoingOrderStatus(forceStop: forceStop);
        if (rebookSecs == 0 && bookingId != ongoingOrder?.id) {
          rebookSecs = 120;
          startRebookTimer();
          notifyListeners();
        }
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
          availableDriver = await taxiRequest.findAvailableDriver(
            types: vehicleTypes,
            pickup: pickupAddress,
            dropoff: dropoffAddress,
            vehicleTypeId: selectedVehicle!.id!,
          );
        } catch (_) {
          availableDriver = null;
        }
        AlertService().stopLoading(forceStop: true);
        if (availableDriver?.driver != null &&
            availableDriver!.kmDistance != 0) {
          if ((availableDriver?.pickupKm ?? 0.0) <
              (selectedVehicle?.pickupKmLimit ?? 0.0)) {
            placeNewOrder();
          } else {
            startPickupCountDown();
            AlertService().showAppAlert(
              title: "Driver is Distant",
              content:
                  'Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(0) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up.\nThe new fare will be "₱${((availableDriver?.pickupChargeFee?.ceil() ?? 0) + total!).toStringAsFixed(0)}"',
              hideCancel: false,
              confirmText: "Accept",
              confirmColor: Colors.red,
              confirmAction: () {
                if (pickupSecs != 0) {
                  ScaffoldMessenger.of(
                    Get.context!,
                  ).clearSnackBars();
                  ScaffoldMessenger.of(
                    Get.context!,
                  ).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        "Take time to read. Please wait for $pickupSecs second${pickupSecs == 1 ? "" : "s"}!",
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                } else {
                  Get.back();
                  placeNewOrder();
                }
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
      }
    }
  }

  placeNewOrder() async {
    dynamic params = isBool(AuthService.currentUser?.isProvider)
        ? {
            "tip": 0.0,
            "total": total,
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
            "total": selectedVehicle?.total,
            "sub_total": selectedVehicle?.total,
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
    AlertService().showLoading();
    try {
      ApiResponse apiResponse = await taxiRequest.placeNewOrderRequest(
        params: params,
      );
      AlertService().stopLoading(forceStop: true);
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
      AlertService().stopLoading(forceStop: true);
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
    AlertService().showAppAlert(
      asset: AppLotties.confirm,
      title: "Booking Cancellation",
      thirdText: "Search for a new driver",
      content: "Do you want to cancel this booking?",
      hideThird: false,
      hideCancel: false,
      cancelText: "No",
      confirmText: "Yes",
      confirmColor: Colors.red,
      thirdAction: () async {
        if (rebookSecs != 0) {
          ScaffoldMessenger.of(
            Get.context!,
          ).clearSnackBars();
          ScaffoldMessenger.of(
            Get.context!,
          ).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "Please wait for $rebookSecs second${rebookSecs == 1 ? "" : "s"}!",
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
        } else {
          Get.back();
          AlertService().showLoading();
          notifyListeners();
          try {
            ApiResponse apiResponse = await taxiRequest.cancelOrderRequest(
              id: ongoingOrder!.id!,
              reason: "rebook",
              rebook: true,
            );
            ongoingOrder = null;
            if (!isChatViewOpen) {
              Get.until((route) => route.isFirst);
            }
            if (apiResponse.allGood) {
              AlertService().showLoading();
              try {
                snackShown = false;
                availableDriver = null;
                availableDriver = await taxiRequest.findAvailableDriver(
                  types: vehicleTypes,
                  pickup: pickupAddress,
                  dropoff: dropoffAddress,
                  vehicleTypeId: selectedVehicle!.id!,
                );
              } catch (_) {
                availableDriver = null;
              }
              AlertService().stopLoading(forceStop: true);
              if (availableDriver?.driver != null &&
                  availableDriver!.kmDistance != 0) {
                if ((availableDriver?.pickupKm ?? 0.0) <
                    (selectedVehicle?.pickupKmLimit ?? 0.0)) {
                  placeNewOrder();
                } else {
                  startPickupCountDown();
                  AlertService().showAppAlert(
                    title: "Driver is Distant",
                    content:
                        'Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(0) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up.\nThe new fare will be "₱${((availableDriver?.pickupChargeFee?.ceil() ?? 0) + total!).toStringAsFixed(0)}"',
                    hideCancel: false,
                    confirmText: "Accept",
                    confirmColor: Colors.red,
                    confirmAction: () {
                      if (pickupSecs != 0) {
                        ScaffoldMessenger.of(
                          Get.context!,
                        ).clearSnackBars();
                        ScaffoldMessenger.of(
                          Get.context!,
                        ).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red,
                            content: Text(
                              "Take time to read. Please wait for $pickupSecs second${pickupSecs == 1 ? "" : "s"}!",
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      } else {
                        Get.back();
                        placeNewOrder();
                      }
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
            } else {
              throw apiResponse.message;
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
      },
      cancelAction: () async {
        Get.back();
      },
      confirmAction: () async {
        if (rebookSecs != 0) {
          ScaffoldMessenger.of(
            Get.context!,
          ).clearSnackBars();
          ScaffoldMessenger.of(
            Get.context!,
          ).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "Please wait for $rebookSecs second${rebookSecs == 1 ? "" : "s"}!",
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
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
                cHeaders = null;
                snackShown = true;
                notifyListeners();
                clearGMapDetails();
                ongoingOrder = null;

                clearGMapDetails();
                AlertService().showAppAlert(
                  dismissible: false,
                  asset: AppLotties.error,
                  title: "Booking Cancelled",
                  content: "Your booking has been cancelled",
                  confirmAction: () async {
                    if (!isChatViewOpen) {
                      Get.until((route) => route.isFirst);
                    }
                    if (pickupAddress != null &&
                            dropoffAddress != null &&
                            ongoingOrder == null ||
                        ongoingOrder?.status == "cancelled") {
                      isPreparing = true;
                      await drawDropPolyLines(
                        "pickup-dropoff",
                        pickupAddress!.latLng,
                        dropoffAddress!.latLng,
                        null,
                      );
                      await fetchVehicleTypesPricing();
                      isPreparing = false;
                    }
                  },
                );
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

  stopAllListeners() {
    orderUpdateStream?.cancel();
    partnerUpdateStream?.cancel();
  }

  closeOrder() async {
    LoadViewModel().getLoadBalance();
    selectedVehicle = null;
    dropoffAddress = null;
    pickupAddress = null;
    ongoingOrder = null;
    lastCenter = null;
    lastStatus = null;
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
              if ((orderSyncedAt != "${event.data()?["syncedAt"]}" &&
                      "delivered" != "${event.data()?["status"]}") ||
                  (ongoingOrder?.status != "${event.data()?["status"]}" &&
                      "delivered" != "${event.data()?["status"]}")) {
                await getOngoingOrder(forceStop: forceStop);
              } else {
                if ("delivered" == "${event.data()?["status"]}") {
                  await clearGMapDetails();
                }
              }
              if ("cancelled" == "${event.data()?["status"]}" ||
                  "delivered" == "${event.data()?["status"]}") {
                ongoingOrder?.status = "${event.data()?["status"]}";
                notifyListeners();
              }
              userSeen = isBool(event.data()?["userSeen"]);
              dvrMessage = "${event.data()?["driverMessage"]}";
              StorageService.prefs?.setString(
                "orderSyncedAt",
                "${event.data()?["syncedAt"]}",
              );
            } catch (_) {}
            loadUIByOngoingOrderStatus(forceStop: forceStop);
            syncDriverLocation(forceStop: forceStop);
          },
        );
      },
    );
  }

  loadUIByOngoingOrderStatus({bool forceStop = false}) async {
    if (ongoingOrder != null) {
      if (ongoingOrder?.driver == null) {
        AlertService().showLoading();
        await Future.delayed(
          const Duration(seconds: 5),
        );
        await getOngoingOrder(
          showSnack: true,
          forceStop: forceStop,
        );
        AlertService().stopLoading(forceStop: forceStop);
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
            if (lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                ongoingOrder!.driverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "preparing":
            if (lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                ongoingOrder!.driverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
          case "ready":
            if (lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.taxiOrder!.pickupLatLng,
                ongoingOrder!.driverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "enroute":
            if (lastStatus != ongoingOrder?.status) {
              lastStatus = ongoingOrder?.status;
              notifyListeners();
              await drawDropPolyLines(
                "pickup-dropoff",
                ongoingOrder?.taxiOrder?.pickupLatLng ?? pickupAddress!.latLng,
                ongoingOrder?.taxiOrder?.dropoffLatLng ??
                    dropoffAddress!.latLng,
                ongoingOrder?.driverLatLng,
              );
              _centerOngoingOrderForStatusChange();
            }
            break;
          case "delivered":
            cHeaders = null;
            notifyListeners();
            if (lastStatus != "delivered") {
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
            cHeaders = null;
            notifyListeners();
            clearGMapDetails();
            ongoingOrder = null;
            loadUIByOngoingOrderStatus();
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
          bookingId = 0;
          snackShown = true;
          notifyListeners();
          clearGMapDetails();
          stopAllListeners();
          if (lastOrder?.reason != "rebook") {
            if (!isChatViewOpen) {
              Get.until((route) => route.isFirst);
            }
            clearGMapDetails();
            AlertService().showAppAlert(
              dismissible: false,
              title:
                  "Booking ${lastOrder?.reason == "pass" ? "Passed" : "Cancelled"}",
              asset: lastOrder?.reason == "pass"
                  ? AppLotties.success
                  : AppLotties.error,
              content:
                  "Your booking has been ${lastOrder?.reason == "pass" ? "passed" : "cancelled"}",
              confirmAction: () async {
                if (!isChatViewOpen) {
                  Get.until((route) => route.isFirst);
                }
                if (pickupAddress != null &&
                        dropoffAddress != null &&
                        ongoingOrder == null ||
                    ongoingOrder?.status == "cancelled") {
                  isPreparing = true;
                  await drawDropPolyLines(
                    "pickup-dropoff",
                    pickupAddress!.latLng,
                    dropoffAddress!.latLng,
                    null,
                  );
                  await fetchVehicleTypesPricing();
                  isPreparing = false;
                }
              },
            );
          }
        }
      }
    }
  }

  syncDriverLocation({bool forceStop = false}) {
    if (ongoingOrder != null && AuthService.isLoggedIn()) {
      globalTimer?.cancel();
      globalTimer = Timer.periodic(
        Duration(
          seconds:
              AppStrings.homeSettingsObject?["ongoing_trip_sync_seconds"] ?? 5,
        ),
        (Timer timer) async {
          if (ongoingOrder != null && AuthService.isLoggedIn()) {
            try {
              ApiResponse apiResponse =
                  await taxiRequest.syncDriverLocationRequest();
              loadUIByOngoingOrderStatus(forceStop: forceStop);
              if (apiResponse.allGood) {
                ongoingOrder?.driver?.lat = apiResponse.body['lat'];
                ongoingOrder?.driver?.lng = apiResponse.body['long'];
                driverPositionRotation = apiResponse.body['rotation'] ?? 0;
                updateDriverMarkerPosition(
                  ongoingOrder!.driver!.latLng,
                  rotationDegrees: driverPositionRotation,
                );
              } else {
                globalTimer?.cancel();
              }
            } catch (_) {}
          } else {
            globalTimer?.cancel();
          }
        },
      );
    } else {
      globalTimer?.cancel();
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
        user = event.data();
        syncProviderPaymentMode();
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
              notifyListeners();
            }
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

  String get providerDisplayPaymentMode {
    final paymentMode =
        "${partner?["payment_mode"] ?? user?["payment_mode"] ?? ""}"
            .toLowerCase();
    return paymentMode == "cash" ? "cash" : "load";
  }

  chatDriver() {
    notifyListeners();
    fbStore.collection("orders").doc(ongoingOrder?.code).update(
      {
        "userSeen": true,
      },
    );
    userSeen = true;
    notifyListeners();
    Map<String, PeerUser> peers = {
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
    final chatEntity = ChatEntity(
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
    Navigator.push(
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
  }

  startRebookTimer() {
    if (rebookCountdownTimer != null && rebookCountdownTimer!.isActive) {
      return;
    }
    rebookCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (rebookSecs > 0) {
          rebookSecs -= 1;
          notifyListeners();
        } else {
          timer.cancel();
        }
      },
    );
  }

  void startPickupCountDown() {
    pickupSecs = defaultPickupSeconds;
    notifyListeners();
    if (pickupCountdownTimer != null && pickupCountdownTimer!.isActive) {
      return;
    }
    pickupCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (pickupSecs > 0) {
          pickupSecs -= 1;
          notifyListeners();
        } else {
          timer.cancel();
        }
      },
    );
  }
}
