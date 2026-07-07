// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:math';
import 'dart:async';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/services/geocoder.service.dart';

class GMapViewModel extends BaseViewModel {
  static const Duration _minimumLoadingIndicatorDuration =
      Duration(milliseconds: 350);
  static const Duration _defaultMapMoveDebounceDuration =
      Duration(milliseconds: 3000);
  static const double _webSinglePointFocusZoom = 15;
  static const double _cameraCenterTolerance = 0.00002;
  static const Duration _mobileInitialMapMoveDebounceDuration =
      Duration(milliseconds: 150);
  static const Duration _mobilePolylineAnimationStepDuration =
      Duration(milliseconds: 16);
  static const int _mobilePolylineAnimationFrameCount = 32;
  AppMapController? _map;
  Timer? _debounce;
  int _cameraMoveGeneration = 0;
  int _routeDrawGeneration = 0;
  int _polylineAnimationGeneration = 0;
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
  double _routeBoundsTopInset = 0;
  EdgeInsets get routeBoundsPadding => EdgeInsets.fromLTRB(
        80,
        _routeBoundsTopInset + 80,
        80,
        80,
      );
  Duration get initialMapCameraMoveDebounceDuration => kIsWeb
      ? _defaultMapMoveDebounceDuration
      : _mobileInitialMapMoveDebounceDuration;

  void updateRouteBoundsTopInset(double topInset) {
    _routeBoundsTopInset = max(0, topInset);
  }

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
    _routeDrawGeneration++;
    _polylineAnimationGeneration++;
    _debounce?.cancel();
    _debounce = null;
    _isCameraMovePending = false;
    isLoading = false;
    if (showMapLoadingIndicator.value != false) {
      showMapLoadingIndicator.value = false;
    }
    _syncMapUiNotifiers();
  }

  Future<void> _setPolylineWithOptionalAnimation({
    required List<gmaps.LatLng> points,
    required Color color,
    required double strokeWidth,
    bool animate = false,
  }) async {
    final animationGeneration = ++_polylineAnimationGeneration;
    if (!animate || kIsWeb || points.length <= 2) {
      polylines = [
        MapPolylineData(
          points: points,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ];
      return;
    }

    polylines = [];
    notifyListeners();

    for (var frame = 1; frame <= _mobilePolylineAnimationFrameCount; frame++) {
      if (animationGeneration != _polylineAnimationGeneration) {
        return;
      }
      final progress = frame / _mobilePolylineAnimationFrameCount;
      final visiblePoints = _visiblePolylinePointsForProgress(
        points,
        progress,
      );
      polylines = [
        MapPolylineData(
          points: visiblePoints,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ];
      notifyListeners();
      if (frame < _mobilePolylineAnimationFrameCount) {
        await Future<void>.delayed(_mobilePolylineAnimationStepDuration);
      }
    }
  }

  List<gmaps.LatLng> _visiblePolylinePointsForProgress(
    List<gmaps.LatLng> points,
    double progress,
  ) {
    if (points.length <= 1) {
      return List<gmaps.LatLng>.from(points);
    }

    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return points.take(1).toList();
    }
    if (clampedProgress >= 1) {
      return List<gmaps.LatLng>.from(points);
    }

    final segmentLengths = <double>[];
    var totalLength = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].lat - points[i - 1].lat;
      final dy = points[i].lng - points[i - 1].lng;
      final length = sqrt((dx * dx) + (dy * dy));
      segmentLengths.add(length);
      totalLength += length;
    }

    if (totalLength == 0) {
      final endIndex =
          (1 + ((points.length - 1) * clampedProgress)).floor().clamp(
                2,
                points.length,
              );
      return points.take(endIndex).toList();
    }

    final targetLength = totalLength * clampedProgress;
    var traversedLength = 0.0;
    final visiblePoints = <gmaps.LatLng>[points.first];

    for (var i = 1; i < points.length; i++) {
      final previousPoint = points[i - 1];
      final nextPoint = points[i];
      final segmentLength = segmentLengths[i - 1];
      final nextTraversedLength = traversedLength + segmentLength;

      if (targetLength >= nextTraversedLength) {
        visiblePoints.add(nextPoint);
        traversedLength = nextTraversedLength;
        continue;
      }

      final remainingLength = targetLength - traversedLength;
      final ratio = segmentLength == 0 ? 0.0 : remainingLength / segmentLength;
      visiblePoints.add(
        gmaps.LatLng(
          previousPoint.lat + ((nextPoint.lat - previousPoint.lat) * ratio),
          previousPoint.lng + ((nextPoint.lng - previousPoint.lng) * ratio),
        ),
      );
      break;
    }

    return visiblePoints.length < 2 ? points.take(2).toList() : visiblePoints;
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
        if (pickupAddress != null) {
          isInitializing = false;
          syncPickupDisplayFromAddress();
          _syncMapUiNotifiers();
          notifyListeners();
          return;
        }
        _syncMapUiNotifiers();
        mapCameraMove(
          "setMap",
          mapCenter,
          debounceDuration: initialMapCameraMoveDebounceDuration,
        );
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
    mapCameraMove(
      "setMap",
      mapCenter,
      debounceDuration: initialMapCameraMoveDebounceDuration,
    );
  }

  bool get isIgnoringCameraMove {
    final ignoreUntil = _ignoreCameraMoveUntil;
    return ignoreUntil != null && DateTime.now().isBefore(ignoreUntil);
  }

  void ignoreCameraMovesFor(Duration duration) {
    _ignoreCameraMoveUntil = DateTime.now().add(duration);
  }

  bool _isMapCenteredOn(gmaps.LatLng target) {
    final center = _map?.center;
    if (center == null) {
      return false;
    }
    return (center.lat - target.lat).abs() <= _cameraCenterTolerance &&
        (center.lng - target.lng).abs() <= _cameraCenterTolerance;
  }

  bool _isMapZoomedTo(double zoom) {
    final currentZoom = _map?.zoom;
    if (currentZoom == null) {
      return false;
    }
    return (currentZoom - zoom).abs() <= 0.05;
  }

  Future<gmaps.LatLng?> zoomToCurrentLocation({double zoom = 16}) async {
    final target = await getMyLatLng();
    if (_map != null && target != null) {
      if (_isMapCenteredOn(target)) {
        return target;
      }
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

  Future<void> reseedPickupFromCurrentLocation({double zoom = 16}) async {
    final target = await zoomToCurrentLocation(zoom: zoom);
    if (target == null) {
      return;
    }

    try {
      final addresses = await geocoderService.findAddressesFromCoordinates(
        Coordinates(
          target.lat,
          target.lng,
        ),
      );
      final address = addresses.isNotEmpty
          ? Address(
              addressLine: addresses.first.addressLine,
              countryName: addresses.first.countryName,
              countryCode: addresses.first.countryCode,
              featureName: addresses.first.featureName,
              postalCode: addresses.first.postalCode,
              adminArea: addresses.first.adminArea,
              subAdminArea: addresses.first.subAdminArea,
              locality: addresses.first.locality,
              subLocality: addresses.first.subLocality,
              thoroughfare: addresses.first.thoroughfare,
              subThoroughfare: addresses.first.subThoroughfare,
              gMapPlaceId: addresses.first.gMapPlaceId,
              coordinates: Coordinates(
                target.lat,
                target.lng,
              ),
            )
          : Address(
              coordinates: Coordinates(
                target.lat,
                target.lng,
              ),
            );
      await addressSelected(address);
    } catch (_) {
      await addressSelected(
        Address(
          coordinates: Coordinates(
            target.lat,
            target.lng,
          ),
        ),
      );
    }
  }

  bool fitCurrentRouteBounds({
    EdgeInsets? padding,
    bool animated = true,
    bool allowSinglePointFit = true,
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

    final uniquePoints = <String, gmaps.LatLng>{};
    for (final point in routePoints) {
      uniquePoints["${point.lat},${point.lng}"] = point;
    }
    final targetPoints = uniquePoints.values.toList();
    if (targetPoints.isEmpty) {
      return false;
    }

    final hasOnlyPickupSelection = targetPoints.length == 1 &&
        pickupAddress != null &&
        dropoffAddress == null &&
        polylines.isEmpty &&
        markers.isEmpty;
    if (kIsWeb && hasOnlyPickupSelection) {
      return false;
    }

    if (targetPoints.length == 1 && !allowSinglePointFit) {
      return false;
    }

    ignoreCameraMovesFor(
      const Duration(milliseconds: 1200),
    );
    if (targetPoints.length == 1) {
      const targetZoom = kIsWeb ? _webSinglePointFocusZoom : 16.0;
      if (_isMapCenteredOn(targetPoints.first) && _isMapZoomedTo(targetZoom)) {
        return true;
      }
      _map!.recenter(
        targetPoints.first,
        zoom: targetZoom,
      );
      return true;
    }
    _map!.fitToCoordinates(
      targetPoints,
      padding: padding ?? routeBoundsPadding,
      animated: animated,
    );
    return true;
  }

  Future<void> recenterHomeMap({
    gmaps.LatLng? fallbackTarget,
    bool allowSinglePointFit = true,
  }) async {
    if (_map == null) {
      return;
    }

    if (fitCurrentRouteBounds(
      allowSinglePointFit: allowSinglePointFit,
    )) {
      return;
    }

    final target = fallbackTarget ?? await getMyLatLng();
    if (target == null) {
      return;
    }

    const targetZoom = kIsWeb ? _webSinglePointFocusZoom : 16.0;
    if (_isMapCenteredOn(target)) {
      if (!_isMapZoomedTo(targetZoom)) {
        ignoreCameraMovesFor(
          const Duration(milliseconds: 800),
        );
        _map!.recenter(
          target,
          zoom: targetZoom,
        );
      }
      return;
    }

    ignoreCameraMovesFor(
      const Duration(milliseconds: 800),
    );
    if (fallbackTarget != null) {
      zoomToLocation(
        fallbackTarget,
        zoom: kIsWeb ? _webSinglePointFocusZoom : 16,
      );
    } else {
      _map!.recenter(
        target,
        zoom: 16,
      );
    }
    await mapCameraMove(
      "myLocation",
      target,
      debounceDuration: Duration.zero,
    );
  }

  zoomToLocation(
    gmaps.LatLng target, {
    double zoom = 16,
    bool animate = true,
  }) async {
    if (_map != null) {
      if (animate) {
        _map!.recenter(
          target,
          zoom: zoom,
        );
      } else {
        _map!.move(
          target,
          zoom,
        );
      }
    }
  }

  zoomIn() async {
    if (_map != null) {
      ignoreCameraMovesFor(
        const Duration(milliseconds: 800),
      );
      final currentZoom = _map!.zoom;
      _map!.recenter(
        _map!.center,
        zoom: (currentZoom + 1).clamp(2, 21),
      );
    }
  }

  zoomOut() async {
    if (_map != null) {
      ignoreCameraMovesFor(
        const Duration(milliseconds: 800),
      );
      final currentZoom = _map!.zoom;
      _map!.recenter(
        _map!.center,
        zoom: (currentZoom - 1).clamp(2, 21),
      );
    }
  }

  mapCameraMove(
    String function,
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
    bool animateSelectedAddress = true,
    Duration debounceDuration = _defaultMapMoveDebounceDuration,
    Completer<void>? completion,
  }) async {
    final shouldCancelInitialCameraMove = shouldSkipInitialMapCameraMove &&
        (function == "setMap" || function == "onCameraMove");
    if (target == null || _isResolvingCameraMove) {
      completion?.complete();
      return;
    }
    if (shouldCancelInitialCameraMove) {
      isInitializing = false;
      _isCameraMovePending = false;
      _syncMapUiNotifiers();
      completion?.complete();
      return;
    }
    final generation = ++_cameraMoveGeneration;
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
        if (shouldSkipInitialMapCameraMove &&
            (function == "setMap" || function == "onCameraMove")) {
          isInitializing = false;
          _isCameraMovePending = false;
          _syncMapUiNotifiers();
          completion?.complete();
          return;
        }
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
            showError(
              (apiResponse?.message.contains("service") ?? false)
                  ? "Please try another location"
                  : e.toString().toLowerCase().contains("dio")
                      ? "There was an error while processing"
                          " your request. Please try again later"
                      : e.toString().toLowerCase().contains("bad")
                          ? "There was a problem with your location "
                              "detection or your internet connection"
                          : e,
            );
          }
          if (gVehicleTypes.isEmpty) {
            try {
              gVehicleTypes = await taxiRequest.vehicleTypesRequest();
              if (generation != _cameraMoveGeneration) {
                return;
              }
              shouldNotify = true;
            } catch (e) {
              // Vehicle types can retry on the next map move.
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
          // Fall back to the provided place summary when details fail.
        }
      }
      selectedAddress.value = resolvedAddress;
      pickupAddress = resolvedAddress;
      if (clearPickupDisplay.value != false) {
        clearPickupDisplay.value = false;
      }
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
      _syncMapUiNotifiers();
      notifyListeners();
    } catch (e) {
      // Ignore temporary map-selection failures.
    }
  }

  drawPickPolyLines(
      String purpose, gmaps.LatLng pickupLatLng, gmaps.LatLng driverLatLng,
      {bool animatePolyline = false}) async {
    if (_map == null) return;
    final routeDrawGeneration = ++_routeDrawGeneration;
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
      if (routeDrawGeneration != _routeDrawGeneration || _map == null) {
        return;
      }
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        await _setPolylineWithOptionalAnimation(
          points: points,
          color: const Color(0xFF42A5F5),
          strokeWidth: 8,
          animate: animatePolyline,
        );
        if (routeDrawGeneration != _routeDrawGeneration || _map == null) {
          return;
        }
        final allPoints = [driverLatLng, ...points, pickupLatLng];
        if (shouldAutoFitMapToRoute) {
          ignoreCameraMovesFor(
            const Duration(milliseconds: 1200),
          );
          _map!.fitToCoordinates(
            allPoints,
            padding: routeBoundsPadding,
          );
        }
      } else {}
    } catch (e) {
      // Ignore temporary polyline failures.
    }
    notifyListeners();
  }

  Future<void> drawDropPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng dropoffLatLng,
    gmaps.LatLng? driverLatLng, {
    bool animatePolyline = false,
    bool autoFitMap = true,
    bool autoFitAnimated = true,
  }) async {
    if (_map == null) return;
    final routeDrawGeneration = ++_routeDrawGeneration;
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
      if (routeDrawGeneration != _routeDrawGeneration || _map == null) {
        return;
      }
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        await _setPolylineWithOptionalAnimation(
          points: points,
          color: const Color(0xFF42A5F5),
          strokeWidth: 8,
          animate: animatePolyline,
        );
        if (routeDrawGeneration != _routeDrawGeneration || _map == null) {
          return;
        }
        final allPoints = [pickupLatLng, ...points, dropoffLatLng];
        if (autoFitMap && shouldAutoFitMapToRoute) {
          ignoreCameraMovesFor(
            const Duration(milliseconds: 1200),
          );
          _map!.fitToCoordinates(
            allPoints,
            padding: routeBoundsPadding,
            animated: autoFitAnimated,
          );
        }
      } else {}
    } catch (e) {
      // Ignore temporary polyline failures.
    }
    notifyListeners();
  }

  clearGMapDetails() {
    _routeDrawGeneration++;
    _polylineAnimationGeneration++;
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
