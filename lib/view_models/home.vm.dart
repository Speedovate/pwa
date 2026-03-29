// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/chat.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/constants/strings.dart';
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
  bool showReport = false;
  bool isDisabled = false;
  bool isPreparing = false;
  bool blockCamera = false;
  bool showAnalytics = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? order;
  VehicleType? selectedVehicle;
  Map<String, dynamic>? cHeaders;
  double driverPositionRotation = 0;
  List<VehicleType> vehicleTypes = [];
  StreamSubscription? userUpdateStream;
  StreamSubscription? orderUpdateStream;
  AuthRequest authRequest = AuthRequest();
  TextEditingController reviewTEC = TextEditingController();
  Future<void>? _initialOngoingOrderFuture;
  bool isResolvingInitialOngoingOrder = false;

  @override
  bool get shouldSkipInitialMapCameraMove =>
      isResolvingInitialOngoingOrder || ongoingOrder != null;

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
      notifyListeners();
    }
  }

  initialise() async {
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ??
        !AuthService.isLoggedIn();
    isAd1Seen = StorageService.prefs?.getBool("is_ad_1_seen") ??
        !AuthService.isLoggedIn();
    if (isBool(AuthService.currentUser?.isProvider)) {
      paymentId = 8;
    }
    notifyListeners();
    if (AuthService.isLoggedIn()) {
      if (ongoingOrder == null) {
        ensureInitialOngoingOrderLoaded();
      }
      LoadViewModel().getLoadBalance();
      startListeningToUser();
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
    if (ongoingOrder != null &&
        ongoingOrder?.status != "cancelled" &&
        ongoingOrder?.status != "delivered" &&
        ongoingOrder?.taxiOrder?.pickupLatLng != null &&
        ongoingOrder?.taxiOrder?.dropoffLatLng != null) {
      isPreparing = true;
      notifyListeners();
      await drawDropPolyLines(
        "pickup-dropoff",
        ongoingOrder!.taxiOrder!.pickupLatLng,
        ongoingOrder!.taxiOrder!.dropoffLatLng,
        ongoingOrder?.driverLatLng,
      );
      isPreparing = false;
      notifyListeners();
      return;
    }

    if (pickupAddress != null &&
        dropoffAddress != null &&
        (ongoingOrder == null || ongoingOrder?.status == "cancelled")) {
      isPreparing = true;
      notifyListeners();
      await drawDropPolyLines(
        "pickup-dropoff",
        ongoingOrder?.taxiOrder?.pickupLatLng ?? pickupAddress!.latLng,
        ongoingOrder?.taxiOrder?.dropoffLatLng ?? dropoffAddress!.latLng,
        ongoingOrder?.driverLatLng,
      );
      await fetchVehicleTypesPricing();
      isPreparing = false;
      notifyListeners();
      return;
    }

    final target = await zoomToCurrentLocation();
    if (disposed || target == null) {
      return;
    }

    final completion = Completer<void>();
    await mapCameraMove(
      "myLocation",
      target,
      animateSelectedAddress: false,
      debounceDuration: Duration.zero,
      completion: completion,
    );
    await completion.future;
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

  calculateTotalAmount() {
    subTotal = selectedVehicle?.total ?? 0;
    if (isBool(AuthService.currentUser?.isProvider)) {
      if (providerRiderTypeId == 8) {
        discount = (5 / 100) * subTotal!;
      } else {
        discount = 0;
      }
    } else {
      discount = 0;
    }
    total = (subTotal ?? 0) - (discount ?? 0);
    if (isBool(AuthService.currentUser?.isProvider)) {
      if (providerRiderTypeId != 8) {
        total = total! + (user?["markup_amount"] ?? 0) + 20;
      } else {
        total = total! + 20;
      }
    }
    notifyListeners();
  }

  String get providerPaymentMode {
    final paymentMode = "${user?["payment_mode"] ?? ""}".toLowerCase();
    return paymentMode == "cash" ? "cash" : "load";
  }

  int get providerPaymentId => providerPaymentMode == "cash" ? 1 : 8;

  void syncProviderPaymentMode() {
    if (!isBool(AuthService.currentUser?.isProvider)) {
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
          rebookSecs = 40;
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
                        fontWeight: FontWeight.w500,
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
                  'Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(1) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up.\nThe new fare will be "₱${((availableDriver?.pickupChargeFee?.ceil() ?? 0) + total!).toStringAsFixed(0)}"',
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
                        'Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(1) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up.\nThe new fare will be "₱${((availableDriver?.pickupChargeFee?.ceil() ?? 0) + total!).toStringAsFixed(0)}"',
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
    reviewTEC.clear();
    getOngoingOrder();
    clearGMapDetails();
    clearPickupDisplayState();
    Get.forceAppUpdate();
    zoomToCurrentLocation();
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
                (user?["markup_amount"] ?? 0) != null &&
                isBool(AuthService.currentUser?.isProvider) &&
                event.data()?["markup_amount"] == null) {
              fbStore.collection("orders").doc(ongoingOrder?.code).update(
                {
                  "markup_amount": user?["markup_amount"],
                },
              );
            }
            if (ongoingOrder?.discount == 0 &&
                user?["markup_amount"] != null &&
                isBool(AuthService.currentUser?.isProvider) &&
                event.data()?["markup_amount"] == null) {
              fbStore.collection("orders").doc(ongoingOrder?.code).update(
                {
                  "markup_amount": user?["markup_amount"],
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

  reportDriver() async {
    if (reviewTEC.text == "" || reviewTEC.text == "null") {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please tell us what happened",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (reviewTEC.text.length <= 5) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please provide us the details",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      showReport = false;
      notifyListeners();
      AlertService().showAppAlert(
        title: "Report Driver",
        content: "Do you want to report driver?",
        cancelText: "No",
        confirmText: "Yes",
        hideCancel: false,
        confirmColor: Colors.red,
        confirmAction: () async {
          Get.back();
          AlertService().showLoading();
          try {
            ApiResponse apiResponse = await taxiRequest.reportDriverRequest(
              orderId: ongoingOrder?.id,
              message: reviewTEC.text,
            );
            reviewTEC.clear();
            AlertService().stopLoading(forceStop: true);
            if (apiResponse.allGood) {
              AlertService().showAppAlert(
                asset: AppLotties.success,
                title: "Report Submitted",
                content: "Driver has been reported",
              );
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
            showReport = true;
            notifyListeners();
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
        },
      );
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
              "today_amount": 0,
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
              "month_amount": 0,
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
            AuthService.currentUser = await authRequest.getUser();
            await AuthService().saveUserToStorage(
              jsonEncode(
                AuthService.currentUser,
              ),
            );
            await AuthService.getUserFromStorage();
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

  chatDriver() {
    notifyListeners();
    fbStore.collection("orders").doc(ongoingOrder?.code).update(
      {
        "userSeen": true,
      },
    );
    Map<String, PeerUser> peers = {
      '${ongoingOrder?.user?.id}': PeerUser(
        id: '${ongoingOrder?.user?.id}',
        name: '${ongoingOrder?.user?.name}',
        image: '${ongoingOrder?.user?.photo}',
      ),
      '${ongoingOrder?.driver?.id}': PeerUser(
        id: "${ongoingOrder?.driver?.id}",
        name: '${ongoingOrder?.driver?.name}',
        image: '${ongoingOrder?.driver?.photo}',
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
