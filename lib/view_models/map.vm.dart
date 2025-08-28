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

class MapViewModel extends BaseViewModel {
  gmaps.Map? _map;
  Timer? _debounce;
  bool isLoading = false;
  TaxiRequest taxiRequest = TaxiRequest();
  FocusNode searchFocusNode = FocusNode();
  ValueNotifier<gmaps.LatLng>? lastCenter;
  GeocoderService geocoderService = GeocoderService();
  TextEditingController searchTEC = TextEditingController();
  ValueNotifier<Address?> selectedAddress = ValueNotifier(null);

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    searchFocusNode.dispose();
    searchTEC.dispose();
    selectedAddress.dispose();
    _map?.controls.clear();
    _map = null;
    super.dispose();
  }

  initialise({required bool isPickup}) {
    if (isPickup && pickupAddress != null) {
      selectedAddress.value = pickupAddress;
    } else if (!isPickup && pickupAddress != null && dropoffAddress == null) {
      selectedAddress.value = pickupAddress;
    } else if (!isPickup && dropoffAddress != null) {
      selectedAddress.value = dropoffAddress;
    }
  }

  void setMap({
    required bool isPickup,
    required gmaps.Map map,
  }) async {
    _map = map;
    debugPrint("Map set");
    try {
      selectedAddress.value = isPickup
          ? pickupAddress ??
              Address(
                addressLine: pickupAddress!.addressLine,
                coordinates: Coordinates(
                  double.parse(
                      "${pickupAddress?.latLng.lat ?? initLatLng?.lat}"),
                  double.parse(
                      "${pickupAddress?.latLng.lng ?? initLatLng?.lng}"),
                ),
              )
          : dropoffAddress ??
              Address(
                addressLine:
                    dropoffAddress?.addressLine ?? pickupAddress!.addressLine,
                coordinates: Coordinates(
                  double.parse(
                      "${dropoffAddress?.latLng.lat ?? pickupAddress?.latLng.lat ?? initLatLng?.lat}"),
                  double.parse(
                      "${dropoffAddress?.latLng.lng ?? pickupAddress?.latLng.lng ?? initLatLng?.lng}"),
                ),
              );
      map.center = selectedAddress.value!.latLng;
    } catch (e) {
      mapCameraMove(
        initLatLng,
        isPickup: isPickup,
      );
    }
  }

  gmaps.Map? get map => _map;

  Future<void> zoomToCurrentLocation({double zoom = 16}) async {
    if (_map != null) {
      final target = initLatLng;
      _map!.panTo(target!);
      _map!.zoom = zoom;
    }
  }

  Future<void> zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom + 1).clamp(2, 21);
    }
  }

  Future<void> zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom - 1).clamp(2, 21);
    }
  }

  Future<void> mapCameraMove(
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
    required bool isPickup,
  }) async {
    if (!skipSelectedAddress) {
      selectedAddress.value = null;
    }
    mapUnavailable = false;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () async {
        if (!skipSelectedAddress) {
          selectedAddress.value = null;
          isLoading = true;
        }
        setBusyForObject(selectedAddress.value, true);
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
          await addressSelected(
            address,
            animate: true,
            isPickup: isPickup,
          );
        } catch (e) {
          isLoading = false;
          selectedAddress.value = Address(
            coordinates: Coordinates(
              double.parse("${initLatLng?.lat ?? 9.7638}"),
              double.parse("${initLatLng?.lng ?? 118.7473}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.locationAvailableRequest(
            double.parse("${target?.lat ?? 9.7638}"),
            double.parse("${target?.lng ?? 118.7473}"),
          );
          if (!apiResponse.allGood) {
            mapUnavailable = true;
          }
          ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
          ScaffoldMessenger.of(Get.overlayContext!).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                apiResponse.message.contains("service")
                    ? "Please try another location"
                    : e.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (gVehicleTypes.isEmpty) {
          try {
            gVehicleTypes = await taxiRequest.vehicleTypesRequest();
            debugPrint("gmap vehicleTypesRequest success");
          } catch (e) {
            debugPrint("gmap vehicleTypesRequest error: $e");
          }
        }

        setBusyForObject(selectedAddress.value, false);
      },
    );
  }

  Future<void> addressSelected(
    Address address, {
    bool animate = false,
    required bool isPickup,
  }) async {
    setBusyForObject(selectedAddress.value, true);
    try {
      if (address.gMapPlaceId != null) {
        address = await geocoderService.fetchPlaceDetails(address);
      }
      selectedAddress.value = address;
      if (isPickup) {
        pickupAddress = address;
      } else {
        dropoffAddress = address;
      }
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
      setBusyForObject(selectedAddress.value, false);
    }
  }

  Future<List<Address>> fetchPlaces(String keyword) async {
    return await geocoderService.findAddressesFromQuery(keyword);
  }
}
