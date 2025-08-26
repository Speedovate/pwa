import 'dart:async';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/view_models/gmap.vm.dart';
import 'package:pwa/view_models/load.vm.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/vehicle_type.model.dart';

class HomeViewModel extends GMapViewModel {
  bool? userSeen;
  String? dvrMessage;
  String? lastStatus;
  Order? ongoingOrder;
  double rating = 5.0;
  int vehicleIndex = 0;
  Timer? debounceTimer;
  int paymentMethodId = 1;
  bool showReport = false;
  bool isPreparing = false;
  VehicleType? selectedVehicle;
  Map<String, dynamic>? cHeaders;
  List<VehicleType> vehicleTypes = [];
  StreamSubscription? userUpdateStream;
  StreamSubscription? orderUpdateStream;
  TextEditingController reviewTEC = TextEditingController();

  Future<void> initialise() async {
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

  Future<void> fetchVehicleTypesPricing() async {
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
}
