// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/services/geocoder.service.dart';

class GMapViewModel extends BaseViewModel {
  fmap.MapController? _map;
  Timer? _debounce;
  bool _isResolvingCameraMove = false;
  DateTime? _ignoreCameraMoveUntil;
  double? total = 0.0;
  double? subTotal = 0.0;
  double? discount = 0.0;
  bool isLoading = false;
  bool isInitializing = false;
  List<MapMarkerData> markers = [];
  List<MapPolylineData> polylines = [];
  TaxiRequest taxiRequest = TaxiRequest();
  gmaps.LatLng? lastCenter;
  GeocoderService geocoderService = GeocoderService();
  ValueNotifier<Address?> selectedAddress = ValueNotifier(null);

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    selectedAddress.dispose();
    _map = null;
    super.dispose();
  }

  setMap(fmap.MapController map) {
    _map = map;
    lastCenter = gmaps.LatLng(
      map.camera.center.latitude,
      map.camera.center.longitude,
    );
    isInitializing = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        mapCameraMove("setMap", mapCenter);
      },
    );
  }

  fmap.MapController? get map => _map;

  gmaps.LatLng? get mapCenter => _map == null
      ? null
      : gmaps.LatLng(
          _map!.camera.center.latitude,
          _map!.camera.center.longitude,
        );

  Future<gmaps.LatLng?> zoomToCurrentLocation({double zoom = 16}) async {
    final target = await getMyLatLng();
    if (_map != null && target != null) {
      _ignoreCameraMoveUntil = DateTime.now().add(
        const Duration(milliseconds: 800),
      );
      _map!.move(
        target,
        zoom,
      );
    }
    return target;
  }

  zoomToLocation(
    gmaps.LatLng target, {
    double zoom = 16,
  }) async {
    if (_map != null) {
      _map!.move(
        target,
        zoom,
      );
    }
  }

  zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.camera.zoom;
      _map!.move(
        _map!.camera.center,
        (currentZoom + 1).clamp(2, 21),
      );
    }
  }

  zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.camera.zoom;
      _map!.move(
        _map!.camera.center,
        (currentZoom - 1).clamp(2, 21),
      );
    }
  }

  mapCameraMove(
    String function,
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
    Duration debounceDuration = const Duration(milliseconds: 3000),
  }) async {
    if (target == null || _isResolvingCameraMove) {
      isLoading = false;
      isInitializing = false;
      return;
    }
    debugPrint("Map move - $function");
    final previousAddress = selectedAddress.value;
    if (!skipSelectedAddress) {
      selectedAddress.value = null;
      notifyListeners();
    }
    locUnavailable = false;
    _debounce?.cancel();
    _debounce = Timer(
      debounceDuration,
      () async {
        if (_isResolvingCameraMove) {
          return;
        }
        _isResolvingCameraMove = true;
        try {
          if (!skipSelectedAddress) {
            selectedAddress.value = null;
            isLoading = true;
            notifyListeners();
          }
          setBusyForObject(selectedAddress, true);
          try {
            List<Address> addresses =
                await geocoderService.findAddressesFromCoordinates(
              Coordinates(
                double.parse("${target.lat}"),
                double.parse("${target.lng}"),
              ),
            );
            if (addresses.isEmpty) {
              throw Exception("No address found");
            }
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
            isLoading = false;
            isInitializing = false;
            await addressSelected(address, animate: true);
            notifyListeners();
          } catch (e) {
            isLoading = false;
            isInitializing = false;
            final fallbackAddress = previousAddress ??
                Address(
                  addressLine: "Current location",
                  coordinates: Coordinates(
                    double.parse("${target.lat}"),
                    double.parse("${target.lng}"),
                  ),
                );
            selectedAddress.value = fallbackAddress;
            pickupAddress = fallbackAddress;
            ApiResponse? apiResponse;
            try {
              apiResponse = await taxiRequest.locationAvailableRequest(
                double.parse("${target.lat}"),
                double.parse("${target.lng}"),
              );
              if (!apiResponse.allGood) {
                locUnavailable = true;
              }
            } catch (_) {
              apiResponse = null;
            }
            ScaffoldMessenger.of(Get.context!).clearSnackBars();
            ScaffoldMessenger.of(
              Get.context!,
            ).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  (apiResponse?.message.contains("service") ?? false)
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
            notifyListeners();
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
        } finally {
          setBusyForObject(selectedAddress, false);
          _isResolvingCameraMove = false;
        }
      },
    );
  }

  addressSelected(
    Address address, {
    bool animate = false,
  }) async {
    setBusyForObject(selectedAddress, true);
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
      pickupAddress = resolvedAddress;
      if (_map != null) {
        final currentZoom = _map!.camera.zoom;
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
        _map!.move(
          nextCenter,
          currentZoom,
        );
      }
    } catch (e) {
      debugPrint("Error in addressSelected: $e");
    } finally {
      setBusyForObject(selectedAddress, false);
    }
  }

  drawPickPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng driverLatLng,
  ) async {
    if (_map == null) return;
    markers = [
      const MapMarkerData(
        id: "pickupMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl:
            'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/pickup.png',
        width: 50,
        height: 50,
      ).copyWith(position: pickupLatLng),
      const MapMarkerData(
        id: "driverMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl:
            'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/driver.png',
        width: 35,
        height: 35,
      ).copyWith(position: driverLatLng),
    ];
    polylines = [];
    try {
      final result = await geocoderService.getPolyline(
        driverLatLng,
        pickupLatLng,
        purpose,
      );
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        polylines = [
          MapPolylineData(
            points: points,
            color: const Color(0xFF42A5F5),
            strokeWidth: 6,
          ),
        ];
        final allPoints = [driverLatLng, ...points, pickupLatLng];
        _map!.fitCamera(
          fmap.CameraFit.coordinates(
            coordinates: allPoints,
            padding: const EdgeInsets.all(48),
          ),
        );
      } else {
        debugPrint("No polyline points received from backend");
      }
    } catch (e) {
      debugPrint("Error drawing pick polyline: $e");
    }
    notifyListeners();
  }

  drawDropPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng dropoffLatLng,
    gmaps.LatLng? driverLatLng,
  ) async {
    if (_map == null) return;
    markers = [
      const MapMarkerData(
        id: "pickupMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl:
            'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/pickup.png',
        width: 50,
        height: 50,
      ).copyWith(position: pickupLatLng),
      const MapMarkerData(
        id: "dropoffMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl:
            'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/dropoff.png',
        width: 50,
        height: 50,
      ).copyWith(position: dropoffLatLng),
    ];
    if (driverLatLng != null) {
      markers.add(
        const MapMarkerData(
          id: "driverMarker",
          position: gmaps.LatLng(0, 0),
          imageUrl:
              'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/driver.png',
          width: 35,
          height: 35,
        ).copyWith(position: driverLatLng),
      );
    }
    polylines = [];
    try {
      final result = await geocoderService.getPolyline(
        pickupLatLng,
        dropoffLatLng,
        purpose,
      );
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        polylines = [
          MapPolylineData(
            points: points,
            color: const Color(0xFF42A5F5),
            strokeWidth: 8,
          ),
        ];
        final allPoints = [pickupLatLng, ...points, dropoffLatLng];
        _map!.fitCamera(
          fmap.CameraFit.coordinates(
            coordinates: allPoints,
            padding: const EdgeInsets.all(48),
          ),
        );
      } else {
        debugPrint("No polyline points received from backend");
      }
    } catch (e) {
      debugPrint("Error drawing drop polyline: $e");
    }
    notifyListeners();
  }

  clearGMapDetails() {
    markers = [];
    polylines = [];
    notifyListeners();
  }

  updateDriverMarkerPosition(
    gmaps.LatLng position, {
    double rotationDegrees = 0,
  }) {
    final index = markers.indexWhere((m) => m.id == 'driverMarker');
    if (index == -1) {
      markers.add(
        MapMarkerData(
          id: 'driverMarker',
          position: position,
          imageUrl:
              'https://storage.googleapis.com/ppctoda_website/ppctoda_pwa/driver.png',
          width: 35,
          height: 35,
          rotationDegrees: rotationDegrees,
        ),
      );
    } else {
      markers[index] = markers[index].copyWith(
        position: position,
        rotationDegrees: rotationDegrees,
      );
    }
    notifyListeners();
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
