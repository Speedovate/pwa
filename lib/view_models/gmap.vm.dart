import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/services/geocoder.service.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GMapViewModel extends BaseViewModel {
  gmaps.Map? _map;
  Timer? _debounce;
  bool isLoading = false;
  Address? selectedAddress;
  TaxiRequest taxiRequest = TaxiRequest();
  GeocoderService geocoderService = GeocoderService();

  void setMap(gmaps.Map map) async {
    _map = map;
    print("Camera set");
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      mapCameraMove(_map?.center);
      print("Camera init");
      notifyListeners();
    });
  }

  gmaps.Map? get map => _map;

  Future<void> zoomToCurrentLocation({double zoom = 16}) async {
    if (_map != null) {
      final target = initLatLng;
      _map!.panTo(target!);
      _map!.zoom = zoom;
      notifyListeners();
    }
  }

  Future<void> zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom + 1).clamp(2, 21);
      notifyListeners();
    }
  }

  Future<void> zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom - 1).clamp(2, 21);
      notifyListeners();
    }
  }

  Future<void> mapCameraMove(
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
  }) async {
    if (!skipSelectedAddress) {
      selectedAddress = null;
      notifyListeners();
    }
    locUnavailable = false;
    _debounce?.cancel();
    notifyListeners();
    _debounce = Timer(
      const Duration(milliseconds: 1500),
      () async {
        if (!skipSelectedAddress) {
          selectedAddress = null;
          isLoading = true;
          notifyListeners();
        }
        setBusyForObject(selectedAddress, true);
        // showDialog(
        //   barrierDismissible: false,
        //   context: Get.overlayContext!,
        //   barrierColor: Colors.transparent,
        //   builder: (context) {
        //     return const SizedBox();
        //   },
        // );
        try {
          List<Address> addresses =
              await geocoderService.findAddressesFromCoordinates(
            Coordinates(
              double.parse("${target?.lat ?? 9.7638}"),
              double.parse("${target?.lng ?? 118.7473}"),
            ),
          );
          final Address address = addresses.first;
          isLoading = false;
          await addressSelected(address, animate: true);
        } catch (e) {
          isLoading = false;
          // clearGMapDetails();
          selectedAddress = Address(
            coordinates: Coordinates(
              double.parse("${myLatLng?.lat ?? 9.7638}"),
              double.parse("${myLatLng?.lng ?? 118.7473}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.locationAvailableRequest(
            double.parse("${target?.lat ?? 9.7638}"),
            double.parse("${target?.lng ?? 118.7473}"),
          );
          if (!apiResponse.allGood) {
            locUnavailable = true;
            notifyListeners();
          }
          ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
          ScaffoldMessenger.of(
            Get.overlayContext!,
          ).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                apiResponse.message.contains("service")
                    ? "Please try another location"
                    : e.toString().toLowerCase().contains("dio")
                        ? "There was an error while processing"
                            " your request. Please try again later"
                        : e.toString().toLowerCase().contains("bad")
                            ? "There was a problem with your location "
                                "detection or your internet connection"
                            : e.toString(),
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
        if (gVehicleTypes.isEmpty) {
          try {
            gVehicleTypes = await taxiRequest.vehicleTypesRequest();
            debugPrint(
              "gmap vehicleTypesRequest success",
            );
          } catch (e) {
            debugPrint(
              "gmap vehicleTypesRequest error 1: $e",
            );
          }
        }
        if (pickupAddress != null && dropoffAddress != null) {
          // await drawDropPolyLines(
          //   "pickup-dropoff",
          //   null,
          //   pickupAddress!.latLng,
          //   dropoffAddress!.latLng,
          // );
          // await HomeViewModel().fetchVehicleTypesPricing();
        }
        setBusyForObject(selectedAddress, false);
      },
    );
  }

  Future<void> addressSelected(
    Address address, {
    bool animate = false,
  }) async {
    setBusyForObject(selectedAddress, true);

    try {
      if (address.gMapPlaceId != null) {
        address = await geocoderService.fetchPlaceDetails(address);
      }

      selectedAddress = address;
      pickupAddress = address;

      if (_map != null) {
        num currentZoom = _map!.zoom;

        if (animate) {
          _map!.panTo(gmaps.LatLng(
            address.coordinates.latitude,
            address.coordinates.longitude,
          ));
        } else {
          _map!.center = gmaps.LatLng(
            address.coordinates.latitude,
            address.coordinates.longitude,
          );
        }

        _map!.zoom = currentZoom;
      }
    } catch (e) {
      debugPrint("Error in addressSelected: $e");
    } finally {
      setBusyForObject(selectedAddress, false);
    }
  }
}
