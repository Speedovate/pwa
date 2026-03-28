import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/models/address.model.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/services/geocoder.service.dart';

class MapViewModel extends BaseViewModel {
  AppMapController? _map;
  Timer? _debounce;
  bool _isResolvingCameraMove = false;
  DateTime? _ignoreCameraMoveUntil;
  bool isHolding = false;
  bool isLoading = false;
  bool skipCamera = false;
  TaxiRequest taxiRequest = TaxiRequest();
  FocusNode searchFocusNode = FocusNode();
  gmaps.LatLng? lastCenter;
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
    required AppMapController map,
  }) async {
    _map = map;
    lastCenter = map.center;
    debugPrint("Map set - MapViewModel");
    try {
      selectedAddress.value = isPickup
          ? pickupAddress ??
              Address(
                addressLine: pickupAddress!.addressLine,
                coordinates: Coordinates(
                  double.parse(
                      "${pickupAddress?.latLng.lat ?? initLatLng?.lng}"),
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
                      "${dropoffAddress?.latLng.lat ?? pickupAddress?.latLng.lat ?? initLatLng?.lng}"),
                  double.parse(
                      "${dropoffAddress?.latLng.lng ?? pickupAddress?.latLng.lng ?? initLatLng?.lng}"),
                ),
              );
      map.move(
        selectedAddress.value!.latLng,
        map.zoom,
      );
    } catch (e) {
      mapCameraMove(
        initLatLng,
        isPickup: isPickup,
      );
    }
  }

  AppMapController? get map => _map;

  gmaps.LatLng? get mapCenter => _map?.center;

  Future<gmaps.LatLng?> zoomToCurrentLocation({double zoom = 16}) async {
    final target = await getMyLatLng();
    if (_map != null && target != null) {
      _ignoreCameraMoveUntil = DateTime.now().add(
        const Duration(milliseconds: 800),
      );
      _map!.move(target, zoom);
    }
    return target;
  }

  zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.zoom;
      _map!.move(_map!.center, (currentZoom + 1).clamp(2, 21));
    }
  }

  zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.zoom;
      _map!.move(_map!.center, (currentZoom - 1).clamp(2, 21));
    }
  }

  mapCameraMove(
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
    required bool isPickup,
    Duration debounceDuration = const Duration(milliseconds: 3000),
  }) async {
    if (target == null || _isResolvingCameraMove) {
      return;
    }
    mapUnavailable = false;
    _debounce?.cancel();
    if (!skipSelectedAddress) {
      selectedAddress.value = null;
      isLoading = true;
      notifyListeners();
    }
    _debounce = Timer(
      debounceDuration,
      () async {
        if (_isResolvingCameraMove) {
          return;
        }
        _isResolvingCameraMove = true;
        setBusyForObject(selectedAddress.value, true);
        try {
          List<Address> addresses =
              await geocoderService.findAddressesFromCoordinates(
            Coordinates(
              double.parse("${target.lat}"),
              double.parse("${target.lng}"),
            ),
          );
          final Address address = Address(
            addressLine: addresses.first.addressLine,
            countryName: addresses.first.countryName,
            countryCode: addresses.first.countryCode,
            featureName: addresses.first.featureName,
            postalCode: addresses.first.postalCode,
            adminArea: addresses.first.adminArea,
            subAdminArea: addresses.first.subAdminArea,
            subLocality: addresses.first.subLocality,
            thoroughfare: addresses.first.thoroughfare,
            subThoroughfare: addresses.first.subThoroughfare,
            gMapPlaceId: addresses.first.gMapPlaceId,
            coordinates: Coordinates(
              double.parse("${target.lat}"),
              double.parse("${target.lng}"),
            ),
          );
          await addressSelected(
            address,
            animate: true,
            isPickup: isPickup,
          );
        } catch (e) {
          selectedAddress.value = Address(
            coordinates: Coordinates(
              double.parse("${initLatLng?.lat ?? 9.7638}"),
              double.parse("${initLatLng?.lng ?? 118.7473}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.locationAvailableRequest(
            double.parse("${target.lat}"),
            double.parse("${target.lng}"),
          );
          if (!apiResponse.allGood) {
            mapUnavailable = true;
          }
          ScaffoldMessenger.of(Get.context!).clearSnackBars();
          ScaffoldMessenger.of(Get.context!).showSnackBar(
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
        isLoading = false;
        notifyListeners();
        _isResolvingCameraMove = false;
      },
    );
  }

  addressSelected(
    Address address, {
    bool animate = false,
    required bool isPickup,
  }) async {
    setBusyForObject(selectedAddress.value, true);
    try {
      var resolvedAddress = address;
      if (address.gMapPlaceId != null) {
        try {
          resolvedAddress = await geocoderService.fetchPlaceDetails(address);
        } catch (e) {
          debugPrint("Error in fetchPlaceDetails: $e");
        }
      }
      selectedAddress.value = resolvedAddress;
      if (isPickup) {
        pickupAddress = resolvedAddress;
      } else {
        dropoffAddress = resolvedAddress;
      }
      if (_map != null) {
        final currentZoom = _map!.zoom;
        final nextCenter = gmaps.LatLng(
          resolvedAddress.coordinates.latitude,
          resolvedAddress.coordinates.longitude,
        );
        lastCenter = nextCenter;
        if (animate) {
          _ignoreCameraMoveUntil = DateTime.now().add(
            const Duration(milliseconds: 800),
          );
        }
        _map!.move(nextCenter, currentZoom);
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

  bool shouldProcessCameraMove(gmaps.LatLng center) {
    final ignoreUntil = _ignoreCameraMoveUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) {
      lastCenter = center;
      return false;
    }
    if (_sameLatLng(lastCenter, center)) {
      return false;
    }
    lastCenter = center;
    return true;
  }

  bool _sameLatLng(gmaps.LatLng? a, gmaps.LatLng? b) {
    if (a == null || b == null) return false;
    return a.lat == b.lat && a.lng == b.lng;
  }
}
