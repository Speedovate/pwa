import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/models/chat_entity.model.dart';
import 'package:pwa/models/peer_user.model.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/view_models/gmap.vm.dart';
import 'package:pwa/view_models/load.vm.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/api_response.model.dart';

class HomeViewModel extends GMapViewModel {
  bool? userSeen;
  String? dvrMessage;
  String? lastStatus;
  double rating = 5.0;
  int vehicleIndex = 0;
  Timer? debounceTimer;
  int paymentMethodId = 1;
  bool showReport = false;
  bool isPreparing = false;
  VehicleType? selectedVehicle;
  Map<String, dynamic>? cHeaders;
  double driverPositionRotation = 0;
  ValueNotifier<Order>? ongoingOrder;
  List<VehicleType> vehicleTypes = [];
  StreamSubscription? userUpdateStream;
  StreamSubscription? orderUpdateStream;
  TextEditingController reviewTEC = TextEditingController();

  initialise() async {
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ??
        !AuthService.isLoggedIn();
    notifyListeners();
    if (AuthService.isLoggedIn()) {
      LoadViewModel().getLoadBalance();
    }
    notifyListeners();
  }

  changeSelectedVehicle(VehicleType vehicleType) {
    if (vehicleTypes.isNotEmpty) {
      selectedVehicle = vehicleTypes.firstWhere(
        (vType) => vType.name == vehicleType.name,
      );
    }
  }

  fetchVehicleTypesPricing() async {
    setBusyForObject(vehicleTypes, true);
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
      await changeSelectedVehicle(
        vehicleTypes.firstWhere(
          (vehicleType) => vehicleType.slug == "tricycle",
          orElse: () => vehicleTypes.first,
        ),
      );
    }
    setBusyForObject(vehicleTypes, false);
  }

  getOngoingOrder({
    bool refresh = false,
    bool showSnack = false,
  }) async {
    setBusyForObject(ongoingOrder, true);
    if (refresh) {
      lastStatus = null;
      notifyListeners();
    }
    try {
      final order = await taxiRequest.ongoingOrderRequest();
      ongoingOrder?.value = order!;
      print("pwet "+jsonEncode(ongoingOrder?.value));
      notifyListeners();
      if (ongoingOrder?.value != null) {
        if (ongoingOrder?.value.status == "pending" ||
            ongoingOrder?.value.status == "preparing") {
          lastStatus = null;
          notifyListeners();
        }
        await startHandlingOngoingOrder();
        await loadUIByOngoingOrderStatus();
        if (rebookSecs == 0 && bookingId != ongoingOrder?.value.id) {
          rebookSecs = 30;
          startRebookTimer();
          notifyListeners();
        }
        bookingId = ongoingOrder?.value.id ?? 0;
        notifyListeners();
      }
    } catch (_) {
      ongoingOrder = null;
      await loadUIByOngoingOrderStatus();
    }
    notifyListeners();
    if (ongoingOrder == null) {
      if (showSnack) {
        ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.overlayContext!,
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
      }
    } else {
      Get.until((route) => route.isFirst);
    }
    notifyListeners();
    setBusyForObject(ongoingOrder, false);
  }

  processNewOrder() async {
    if (pickupAddress == null) {
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            locUnavailable
                ? "Please try another location"
                : "Please select a vehicle type",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      if (AuthService.inReviewMode()) {
        showDialog(
          context: Get.overlayContext!,
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
                        fontSize: 18,
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
                      "PPC TODA is searching for tricycle drivers near you. If this takes too long, there might be no available tricycle drivers near your current area.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    SizedBox(
                      height: 38,
                      child: Material(
                        color: Colors.red.shade100,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        child: Ink(
                          child: InkWell(
                            onTap: () {
                              cancelOrder();
                            },
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            focusColor: const Color(0xFF030744).withOpacity(
                              0.1,
                            ),
                            hoverColor: const Color(0xFF030744).withOpacity(
                              0.1,
                            ),
                            splashColor: const Color(0xFF030744).withOpacity(
                              0.1,
                            ),
                            highlightColor: const Color(0xFF030744).withOpacity(
                              0.1,
                            ),
                            child: const Center(
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  height: 1,
                                  fontSize: 15,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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
        AlertService().stopLoading();
        if (availableDriver?.driver != null &&
            availableDriver!.kmDistance != 0) {
          if ((availableDriver?.pickupKm ?? 0.0) <
              (selectedVehicle?.pickupKmLimit ?? 0.0)) {
            placeNewOrder();
          } else {
            AlertService().showAppAlert(
              title: "Driver is Distant",
              content:
                  "Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(1) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up",
              hideCancel: false,
              confirmText: "Accept",
              confirmColor: Colors.red,
              confirmAction: () {
                Get.back();
                placeNewOrder();
              },
            );
          }
        } else {
          ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
          ScaffoldMessenger.of(
            Get.overlayContext!,
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
        }
      }
    }
  }

  placeNewOrder() async {
    dynamic params = {
      "is_pautos": false,
      "is_delivery": false,
      "has_luggage": false,
      "is_mov_reached": false,
      "includes_ride_cover": false,
      "includes_shower_cap": false,
      "tip": 0,
      "discount": 0,
      "total_budget": 0,
      "marked_up_budget": 0,
      "note": "",
      "coupon_code": "",
      "pickup_date": "",
      "pickup_time": "",
      "payment_method": "",
      "items_to_purchase": "",
      "special_instructions": "",
      "store_location_details": "",
      "total": selectedVehicle?.total,
      "sub_total": selectedVehicle?.total,
      "payment_method_id": paymentMethodId,
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
      "driver_accept_latitude":
          isBool(AppStrings.homeSettingsObject?["enable_prc"] ?? true)
              ? availableDriver?.driver?.lat
              : null,
      "driver_accept_longitude":
          isBool(AppStrings.homeSettingsObject?["enable_prc"] ?? true)
              ? availableDriver?.driver?.lng
              : null,
    };
    AlertService().showLoading();
    try {
      ApiResponse apiResponse = await taxiRequest.placeNewOrderRequest(
        params: params,
      );
      AlertService().stopLoading();
      if (apiResponse.allGood) {
        cHeaders = null;
        notifyListeners();
        await getOngoingOrder();
      } else {
        ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.overlayContext!,
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
      AlertService().stopLoading();
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
            Get.overlayContext!,
          ).clearSnackBars();
          ScaffoldMessenger.of(
            Get.overlayContext!,
          ).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "Please try again after $rebookSecs second${rebookSecs == 1 ? "" : "s"}!",
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
              id: ongoingOrder!.value.id!,
              reason: "rebook",
              rebook: true,
            );
            ongoingOrder = null;
            Get.until((route) => route.isFirst);
            if (apiResponse.allGood) {
              AlertService().showLoading();
              try {
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
              AlertService().stopLoading();
              if (availableDriver?.driver != null &&
                  availableDriver!.kmDistance != 0) {
                if ((availableDriver?.pickupKm ?? 0.0) <
                    (selectedVehicle?.pickupKmLimit ?? 0.0)) {
                  placeNewOrder();
                } else {
                  AlertService().showAppAlert(
                    title: "Driver is Distant",
                    content:
                        "Ka-TODA, the nearest driver is\n${availableDriver?.pickupKm?.toStringAsFixed(1) ?? 0} km away. An additional fare of\n₱${availableDriver?.pickupChargeFee?.ceil().toStringAsFixed(0)} will apply for picking you up",
                    hideCancel: false,
                    confirmText: "Accept",
                    confirmColor: Colors.red,
                    confirmAction: () {
                      Get.back();
                      placeNewOrder();
                    },
                  );
                }
              } else {
                ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
                ScaffoldMessenger.of(
                  Get.overlayContext!,
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
              }
            } else {
              throw apiResponse.message;
            }
          } catch (e) {
            Get.until((route) => route.isFirst);
            ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
            ScaffoldMessenger.of(Get.overlayContext!).showSnackBar(
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
            Get.overlayContext!,
          ).clearSnackBars();
          ScaffoldMessenger.of(
            Get.overlayContext!,
          ).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                "Please try again after $rebookSecs second${rebookSecs == 1 ? "" : "s"}!",
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
                id: ongoingOrder!.value.id!,
                reason: "cancelled by passenger",
                rebook: false,
              );
              Get.until((route) => route.isFirst);
              if (apiResponse.allGood) {
                cHeaders = null;
                notifyListeners();
                clearGMapDetails();
                ongoingOrder = null;
                AlertService().showAppAlert(
                  dismissible: false,
                  asset: AppLotties.error,
                  title: "Booking Cancelled",
                  content: "Your booking has been cancelled",
                  confirmAction: () {
                    Get.until((route) => route.isFirst);
                  },
                );
              } else {
                if (apiResponse.message.contains("cancel")) {
                  closeOrder();
                  clearGMapDetails();
                } else {
                  throw apiResponse.message;
                }
              }
            } catch (e) {
              Get.until((route) => route.isFirst);
              ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
              ScaffoldMessenger.of(Get.overlayContext!).showSnackBar(
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
    cHeaders = null;
    notifyListeners();
    LoadViewModel().getLoadBalance();
    await clearGMapDetails();
    selectedVehicle = null;
    dropoffAddress = null;
    pickupAddress = null;
    ongoingOrder = null;
    lastCenter = null;
    lastStatus = null;
    vehicleTypes = [];
    reviewTEC.clear();
    mapCameraMove(
      initLatLng,
      skipSelectedAddress: true,
    );
    getOngoingOrder();
    notifyListeners();
    Get.forceAppUpdate();
  }

  startHandlingOngoingOrder() async {
    if (debounceTimer != null && debounceTimer!.isActive) {
      debounceTimer?.cancel();
    }
    debounceTimer = Timer(
      const Duration(seconds: 2),
      () async {
        orderUpdateStream = fbStore
            .collection("orders")
            .doc("${ongoingOrder?.value.code}")
            .snapshots()
            .listen(
          (event) async {
            String orderSyncedAt = StorageService.prefs?.getString(
                  "orderSyncedAt",
                ) ??
                "Not Yet Synced";
            if (event.data()?["headers"] == null) {
              var headers = await HttpService().getHeaders();
              try {
                await fbStore
                    .collection("orders")
                    .doc("${ongoingOrder?.value.code}")
                    .update(
                  {
                    "headers": headers,
                  },
                );
              } catch (_) {}
            } else {
              cHeaders = event.data()?["headers"];
              notifyListeners();
            }
            try {
              if ((orderSyncedAt != "${event.data()?["syncedAt"]}" &&
                      "delivered" != "${event.data()?["status"]}") ||
                  (ongoingOrder?.value.status != "${event.data()?["status"]}" &&
                      "delivered" != "${event.data()?["status"]}")) {
                await getOngoingOrder();
              } else {
                if ("delivered" == "${event.data()?["status"]}") {
                  await clearGMapDetails();
                }
              }
              if ("cancelled" == "${event.data()?["status"]}" ||
                  "delivered" == "${event.data()?["status"]}") {
                ongoingOrder?.value.status = "${event.data()?["status"]}";
                notifyListeners();
              }
              userSeen = isBool(event.data()?["userSeen"]);
              dvrMessage = "${event.data()?["driverMessage"]}";
              StorageService.prefs?.setString(
                "orderSyncedAt",
                "${event.data()?["syncedAt"]}",
              );
            } catch (_) {}
            loadUIByOngoingOrderStatus();
            syncDriverLocation();
            notifyListeners();
          },
        );
      },
    );
  }

  loadUIByOngoingOrderStatus() async {
    if (ongoingOrder != null) {
      if (ongoingOrder?.value.driver == null) {
        Get.until((route) => route.isFirst);
        AlertService().showLoading();
        await Future.delayed(const Duration(seconds: 5));
        await getOngoingOrder(showSnack: true);
        AlertService().stopLoading();
      } else {
        pickupAddress = Address(
          addressLine: ongoingOrder?.value.taxiOrder?.pickupAddress,
          coordinates: Coordinates(
            ongoingOrder?.value.taxiOrder?.pickupLatitude ?? 0.0,
            ongoingOrder?.value.taxiOrder?.pickupLongitude ?? 0.0,
          ),
        );
        dropoffAddress = Address(
          addressLine: ongoingOrder?.value.taxiOrder?.dropoffAddress,
          coordinates: Coordinates(
            ongoingOrder?.value.taxiOrder?.dropoffLatitude ?? 0.0,
            ongoingOrder?.value.taxiOrder?.dropoffLongitude ?? 0.0,
          ),
        );
        switch (ongoingOrder?.value.status) {
          case "pending":
            if (lastStatus != ongoingOrder?.value.status) {
              lastStatus = ongoingOrder?.value.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.value.taxiOrder!.pickupLatLng,
                ongoingOrder!.value.driverLatLng,
              );
            }
            break;
          case "preparing":
            if (lastStatus != ongoingOrder?.value.status) {
              lastStatus = ongoingOrder?.value.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.value.taxiOrder!.pickupLatLng,
                ongoingOrder!.value.driverLatLng,
              );
            }
          case "ready":
            if (lastStatus != ongoingOrder?.value.status) {
              lastStatus = ongoingOrder?.value.status;
              notifyListeners();
              await drawPickPolyLines(
                "driver-pickup",
                ongoingOrder!.value.taxiOrder!.pickupLatLng,
                ongoingOrder!.value.driverLatLng,
              );
            }
            break;
          case "enroute":
            if (lastStatus != ongoingOrder?.value.status) {
              lastStatus = ongoingOrder?.value.status;
              notifyListeners();
              await drawDropPolyLines(
                "pickup-dropoff",
                ongoingOrder!.value.driverLatLng,
                pickupAddress!.latLng,
                dropoffAddress!.latLng,
              );
            }
            break;
          case "delivered":
            cHeaders = null;
            notifyListeners();
            if (lastStatus != "delivered") {
              ongoingOrder?.value = (await taxiRequest.lastOrderRequest())!;
              lastStatus = ongoingOrder?.value.status;
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
          notifyListeners();
          clearGMapDetails();
          stopAllListeners();
          if (lastOrder?.reason != "rebook") {
            Get.until((route) => route.isFirst);
            AlertService().showAppAlert(
              dismissible: false,
              title:
                  "Booking ${lastOrder?.reason == "pass" ? "Passed" : "Cancelled"}",
              asset: lastOrder?.reason == "pass"
                  ? AppLotties.success
                  : AppLotties.error,
              content:
                  "Your booking has been ${lastOrder?.reason == "pass" ? "passed" : "cancelled"}",
              confirmAction: () {
                Get.until((route) => route.isFirst);
              },
            );
          }
        }
      }
    }
  }

  syncDriverLocation() {
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
              loadUIByOngoingOrderStatus();
              if (apiResponse.allGood) {
                ongoingOrder?.value.driver?.lat = apiResponse.body['lat'];
                ongoingOrder?.value.driver?.lng = apiResponse.body['long'];
                driverPositionRotation = apiResponse.body['rotation'] ?? 0;
                updateDriverMarkerPosition(
                  ongoingOrder!.value.driver!.latLng,
                );
                notifyListeners();
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

  chatDriver() {
    notifyListeners();
    fbStore.collection("orders").doc(ongoingOrder?.value.code).update(
      {
        "userSeen": true,
      },
    );
    Map<String, PeerUser> peers = {
      '${ongoingOrder?.value.user?.id}': PeerUser(
        id: '${ongoingOrder?.value.user?.id}',
        name: '${ongoingOrder?.value.user?.name}',
        image: '${ongoingOrder?.value.user?.photo}',
      ),
      '${ongoingOrder?.value.driver?.id}': PeerUser(
        id: "${ongoingOrder?.value.driver?.id}",
        name: '${ongoingOrder?.value.driver?.name}',
        image: '${ongoingOrder?.value.driver?.photo}',
      ),
    };
    final chatEntity = ChatEntity(
      onMessageSent: (message, chatEntity) {
        fbStore.collection("orders").doc(ongoingOrder?.value.code).update(
          {
            "driverSeen": false,
            "userMessage": message,
          },
        );
        // ChatService.sendChatMessage(
        //   message,
        //   chatEntity,
        // );
      },
      mainUser: peers['${ongoingOrder?.value.user?.id}'],
      peers: peers,
      path: 'orders/${ongoingOrder?.value.code}/customerDriver/chats',
      title: "Chat with driver",
    );
    // Get.to(
    //   () => ChatView(
    //     chatEntity,
    //     ongoingOrder!,
    //   ),
    // );
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
}
