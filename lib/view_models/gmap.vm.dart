// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/services/geocoder.service.dart';

class GMapViewModel extends BaseViewModel {
  static const Duration _minimumLoadingIndicatorDuration =
      Duration(milliseconds: 350);
  AppMapController? _map;
  Timer? _debounce;
  int _cameraMoveGeneration = 0;
  bool _isResolvingCameraMove = false;
  bool _isCameraMovePending = false;
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
  ValueNotifier<double?> totalAmountNotifier = ValueNotifier(0.0);
  ValueNotifier<bool> clearPickupDisplay = ValueNotifier(false);
  ValueNotifier<bool> showBottomUi = ValueNotifier(false);
  ValueNotifier<bool> showMapLoadingIndicator = ValueNotifier(false);
  ValueNotifier<bool> showPartnerButtons = ValueNotifier(false);
  bool get isMapInteractionLocked => isLoading || _isResolvingCameraMove;
  bool get isCameraMovePending => _isCameraMovePending;
  bool _hasActivatedBottomUi = false;
  bool get hasActivatedBottomUi => _hasActivatedBottomUi;
  bool get shouldSkipInitialMapCameraMove => false;
  bool get shouldAutoFitMapToRoute => true;

  List<MapMarkerData> _markersWithDriverOnTop(List<MapMarkerData> nextMarkers) {
    final sorted = [...nextMarkers];
    sorted.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  void _syncMapUiNotifiers() {
    if (showBottomUi.value != _hasActivatedBottomUi) {
      showBottomUi.value = _hasActivatedBottomUi;
    }
    final nextLoading = isLoading ||
        isInitializing ||
        (!_hasActivatedBottomUi && _isCameraMovePending);
    if (showMapLoadingIndicator.value != nextLoading) {
      showMapLoadingIndicator.value = nextLoading;
    }
    final nextPartners = _hasActivatedBottomUi &&
        !_isCameraMovePending &&
        !isLoading &&
        !isInitializing;
    if (showPartnerButtons.value != nextPartners) {
      showPartnerButtons.value = nextPartners;
    }
  }

  void beginCameraMove() {
    if (_isResolvingCameraMove) {
      return;
    }
    _debounce?.cancel();
    _debounce = null;
    isLoading = false;
    if (showPartnerButtons.value != false) {
      showPartnerButtons.value = false;
    }
    final shouldPreservePickup = dropoffAddress != null;
    if (clearPickupDisplay.value != !shouldPreservePickup) {
      clearPickupDisplay.value = !shouldPreservePickup;
    }
    selectedAddress.value = null;
    if (!shouldPreservePickup) {
      pickupAddress = null;
    }
    isInitializing = false;
    _isCameraMovePending = true;
    _syncMapUiNotifiers();
  }

  void syncPickupDisplayFromAddress() {
    if (pickupAddress == null) {
      return;
    }
    selectedAddress.value = pickupAddress;
    restorePickupDisplay();
  }

  void restorePickupDisplay() {
    if (clearPickupDisplay.value != false) {
      clearPickupDisplay.value = false;
    }
    _hasActivatedBottomUi = true;
    _syncMapUiNotifiers();
  }

  void clearPickupDisplayState() {
    selectedAddress.value = null;
    if (clearPickupDisplay.value != false) {
      clearPickupDisplay.value = false;
    }
    _syncMapUiNotifiers();
  }

  void cancelPendingCameraMove() {
    _cameraMoveGeneration++;
    _debounce?.cancel();
    _debounce = null;
    _isCameraMovePending = false;
    isLoading = false;
    if (showMapLoadingIndicator.value != false) {
      showMapLoadingIndicator.value = false;
    }
    _syncMapUiNotifiers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    selectedAddress.dispose();
    totalAmountNotifier.dispose();
    clearPickupDisplay.dispose();
    showBottomUi.dispose();
    showMapLoadingIndicator.dispose();
    showPartnerButtons.dispose();
    _map = null;
    super.dispose();
  }

  void syncTotalAmountNotifier() {
    if (totalAmountNotifier.value == total) {
      return;
    }
    totalAmountNotifier.value = total;
  }

  setMap(AppMapController map) {
    _map = map;
    lastCenter = map.center;
    isInitializing = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (shouldSkipInitialMapCameraMove) {
          isInitializing = false;
          _syncMapUiNotifiers();
          return;
        }
        _syncMapUiNotifiers();
        mapCameraMove("setMap", mapCenter);
      },
    );
  }

  AppMapController? get map => _map;

  gmaps.LatLng? get mapCenter => _map?.center;

  void startInitialMapCameraMoveIfNeeded() {
    if (_map == null) {
      return;
    }
    isInitializing = true;
    _syncMapUiNotifiers();
    mapCameraMove("setMap", mapCenter);
  }

  bool get isIgnoringCameraMove {
    final ignoreUntil = _ignoreCameraMoveUntil;
    return ignoreUntil != null && DateTime.now().isBefore(ignoreUntil);
  }

  void ignoreCameraMovesFor(Duration duration) {
    _ignoreCameraMoveUntil = DateTime.now().add(duration);
  }

  Future<gmaps.LatLng?> zoomToCurrentLocation({double zoom = 16}) async {
    final target = await getMyLatLng();
    if (_map != null && target != null) {
      _ignoreCameraMoveUntil = DateTime.now().add(
        const Duration(milliseconds: 800),
      );
      _map!.recenter(
        target,
        zoom: zoom,
      );
    }
    return target;
  }

  bool fitCurrentRouteBounds({
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    if (_map == null) {
      return false;
    }

    final routePoints = <gmaps.LatLng>[
      if (pickupAddress != null) pickupAddress!.latLng,
      ...polylines.expand((polyline) => polyline.points),
      if (dropoffAddress != null) dropoffAddress!.latLng,
      ...markers.map((marker) => marker.position),
    ];

    if (routePoints.isEmpty) {
      return false;
    }

    ignoreCameraMovesFor(
      const Duration(milliseconds: 1200),
    );
    _map!.fitToCoordinates(
      routePoints,
      padding: padding,
    );
    return true;
  }

  Future<void> recenterHomeMap() async {
    if (_map == null) {
      return;
    }

    if (fitCurrentRouteBounds()) {
      return;
    }

    final target = await zoomToCurrentLocation();
    if (target != null) {
      await mapCameraMove(
        "myLocation",
        target,
        debounceDuration: Duration.zero,
      );
    }
  }

  zoomToLocation(
    gmaps.LatLng target, {
    double zoom = 16,
  }) async {
    if (_map != null) {
      _map!.recenter(
        target,
        zoom: zoom,
      );
    }
  }

  zoomIn() async {
    if (_map != null) {
      ignoreCameraMovesFor(
        const Duration(milliseconds: 800),
      );
      final currentZoom = _map!.zoom;
      _map!.move(_map!.center, (currentZoom + 1).clamp(2, 21));
    }
  }

  zoomOut() async {
    if (_map != null) {
      ignoreCameraMovesFor(
        const Duration(milliseconds: 800),
      );
      final currentZoom = _map!.zoom;
      _map!.move(_map!.center, (currentZoom - 1).clamp(2, 21));
    }
  }

  mapCameraMove(
    String function,
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
    bool animateSelectedAddress = true,
    Duration debounceDuration = const Duration(milliseconds: 3000),
    Completer<void>? completion,
  }) async {
    if (target == null || _isResolvingCameraMove) {
      completion?.complete();
      return;
    }
    final generation = ++_cameraMoveGeneration;
    debugPrint("Map move - $function");
    final previousAddress = selectedAddress.value;
    if (!skipSelectedAddress) {
      beginCameraMove();
    }
    locUnavailable = false;
    _debounce?.cancel();
    _debounce = Timer(
      debounceDuration,
      () async {
        var shouldNotify = false;
        DateTime? loadingStartedAt;
        if (generation != _cameraMoveGeneration) {
          completion?.complete();
          return;
        }
        if (_isResolvingCameraMove) {
          completion?.complete();
          return;
        }
        _isResolvingCameraMove = true;
        if (!skipSelectedAddress) {
          isLoading = true;
          _isCameraMovePending = false;
          loadingStartedAt = DateTime.now();
          if (showMapLoadingIndicator.value != true) {
            showMapLoadingIndicator.value = true;
          }
        }
        _syncMapUiNotifiers();
        try {
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
            if (generation != _cameraMoveGeneration) {
              return;
            }
            isInitializing = false;
            await addressSelected(
              address,
              animate: animateSelectedAddress,
            );
          } catch (e) {
            if (generation != _cameraMoveGeneration) {
              return;
            }
            isInitializing = false;
            final fallbackAddress = previousAddress ??
                Address(
                  addressLine: "Current location",
                  coordinates: Coordinates(
                    double.parse("${target.lat}"),
                    double.parse("${target.lng}"),
                  ),
                );
            if (clearPickupDisplay.value != false) {
              clearPickupDisplay.value = false;
            }
            selectedAddress.value = fallbackAddress;
            pickupAddress = fallbackAddress;
            _hasActivatedBottomUi = true;
            ApiResponse? apiResponse;
            try {
              apiResponse = await taxiRequest.locationAvailableRequest(
                double.parse("${target.lat}"),
                double.parse("${target.lng}"),
              );
              if (!apiResponse.allGood) {
                locUnavailable = true;
                shouldNotify = true;
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
          }
          if (gVehicleTypes.isEmpty) {
            try {
              gVehicleTypes = await taxiRequest.vehicleTypesRequest();
              if (generation != _cameraMoveGeneration) {
                return;
              }
              shouldNotify = true;
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
          if (generation == _cameraMoveGeneration) {
            if (loadingStartedAt != null) {
              final elapsed = DateTime.now().difference(loadingStartedAt);
              if (elapsed < _minimumLoadingIndicatorDuration) {
                await Future.delayed(
                  _minimumLoadingIndicatorDuration - elapsed,
                );
              }
            }
            isLoading = false;
            _isCameraMovePending = false;
            _isResolvingCameraMove = false;
            if (showMapLoadingIndicator.value != false) {
              showMapLoadingIndicator.value = false;
            }
            _syncMapUiNotifiers();
            if (shouldNotify) {
              notifyListeners();
            }
          }
          completion?.complete();
        }
      },
    );
  }

  addressSelected(
    Address address, {
    bool animate = false,
  }) async {
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
      if (clearPickupDisplay.value != false) {
        clearPickupDisplay.value = false;
      }
      pickupAddress = resolvedAddress;
      _hasActivatedBottomUi = true;
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
        imageUrl: 'https://assets.ppc-toda.com/pickup.png',
        width: 50,
        height: 50,
      ).copyWith(position: pickupLatLng),
      const MapMarkerData(
        id: "driverMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl: 'https://assets.ppc-toda.com/driver.png',
        width: 35,
        height: 35,
        zIndex: 1000,
      ).copyWith(position: driverLatLng),
    ];
    markers = _markersWithDriverOnTop(markers);
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
        if (shouldAutoFitMapToRoute) {
          ignoreCameraMovesFor(
            const Duration(milliseconds: 1200),
          );
          _map!.fitToCoordinates(
            allPoints,
            padding: const EdgeInsets.fromLTRB(75, 90, 75, 90),
          );
        }
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
        imageUrl: 'https://assets.ppc-toda.com/pickup.png',
        width: 50,
        height: 50,
      ).copyWith(position: pickupLatLng),
      const MapMarkerData(
        id: "dropoffMarker",
        position: gmaps.LatLng(0, 0),
        imageUrl: 'https://assets.ppc-toda.com/dropoff.png',
        width: 50,
        height: 50,
      ).copyWith(position: dropoffLatLng),
    ];
    if (driverLatLng != null) {
      markers.add(
        const MapMarkerData(
          id: "driverMarker",
          position: gmaps.LatLng(0, 0),
          imageUrl: 'https://assets.ppc-toda.com/driver.png',
          width: 35,
          height: 35,
          zIndex: 1000,
        ).copyWith(position: driverLatLng),
      );
    }
    markers = _markersWithDriverOnTop(markers);
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
        if (shouldAutoFitMapToRoute) {
          ignoreCameraMovesFor(
            const Duration(milliseconds: 1200),
          );
          _map!.fitToCoordinates(
            allPoints,
            padding: const EdgeInsets.fromLTRB(75, 90, 75, 90),
          );
        }
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
          imageUrl: 'https://assets.ppc-toda.com/driver.png',
          width: 35,
          height: 35,
          rotationDegrees: rotationDegrees,
          zIndex: 1000,
        ),
      );
    } else {
      markers[index] = markers[index].copyWith(
        position: position,
        rotationDegrees: rotationDegrees,
        zIndex: 1000,
      );
    }
    markers = _markersWithDriverOnTop(markers);
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
