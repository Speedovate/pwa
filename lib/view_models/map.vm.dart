import 'dart:async';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  Timer? _manualSelectionGuard;
  bool _isResolvingCameraMove = false;
  DateTime? _ignoreCameraMoveUntil;
  int _selectionGeneration = 0;
  bool isHolding = false;
  bool isLoading = false;
  bool skipCamera = false;
  TaxiRequest taxiRequest = TaxiRequest();
  FocusNode searchFocusNode = FocusNode();
  gmaps.LatLng? lastCenter;
  GeocoderService geocoderService = GeocoderService();
  TextEditingController searchTEC = TextEditingController();
  ValueNotifier<Address?> selectedAddress = ValueNotifier(null);

  void _clearSearchAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (disposed) return;
      searchTEC.clear();
    });
  }

  void _setSelectedAddressSafely(Address? address) {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer = schedulerPhase == SchedulerPhase.transientCallbacks ||
        schedulerPhase == SchedulerPhase.midFrameMicrotasks ||
        schedulerPhase == SchedulerPhase.persistentCallbacks;
    if (shouldDefer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (disposed) return;
        selectedAddress.value = address;
      });
      return;
    }
    selectedAddress.value = address;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _manualSelectionGuard?.cancel();
    _manualSelectionGuard = null;
    searchFocusNode.dispose();
    searchTEC.dispose();
    selectedAddress.dispose();
    _map = null;
    super.dispose();
  }

  void _beginManualSelectionGuard() {
    _manualSelectionGuard?.cancel();
    skipCamera = true;
    isLoading = false;
    _debounce?.cancel();
    _debounce = null;
    _selectionGeneration++;
    notifyListeners();
  }

  void _endManualSelectionGuard({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _manualSelectionGuard?.cancel();
    _manualSelectionGuard = Timer(delay, () {
      if (disposed) {
        return;
      }
      skipCamera = false;
      notifyListeners();
    });
  }

  initialise({required bool isPickup}) {
    if (isPickup && pickupAddress != null) {
      _setSelectedAddressSafely(pickupAddress);
    } else if (!isPickup && pickupAddress != null && dropoffAddress == null) {
      _setSelectedAddressSafely(pickupAddress);
    } else if (!isPickup && dropoffAddress != null) {
      _setSelectedAddressSafely(dropoffAddress);
    }
  }

  void setMap({
    required bool isPickup,
    required AppMapController map,
  }) async {
    _map = map;
    lastCenter = map.center;
    debugPrint("Map set - MapViewModel");
    final fallbackCenter = initLatLng ?? defaultLatLng;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (disposed || _map != map) {
        return;
      }
      try {
        final shouldResolveCurrentLocation = isPickup && pickupAddress == null;
        if (shouldResolveCurrentLocation) {
          final target = await zoomToCurrentLocation(
            zoom: map.zoom,
          );
          if (disposed || _map != map) {
            return;
          }
          await mapCameraMove(
            target ?? fallbackCenter,
            isPickup: isPickup,
            debounceDuration: Duration.zero,
          );
          return;
        }

        final initialAddress = isPickup
            ? pickupAddress!
            : dropoffAddress ??
                pickupAddress ??
                Address(
                  addressLine:
                      dropoffAddress?.addressLine ?? pickupAddress?.addressLine,
                  coordinates: Coordinates(
                    double.parse(
                        "${dropoffAddress?.latLng.lat ?? pickupAddress?.latLng.lat ?? fallbackCenter.lat}"),
                    double.parse(
                        "${dropoffAddress?.latLng.lng ?? pickupAddress?.latLng.lng ?? fallbackCenter.lng}"),
                  ),
                );
        _setSelectedAddressSafely(initialAddress);
        _clearSearchAfterBuild();
        final initialCenter = initialAddress.latLng;
        lastCenter = initialCenter;
        _ignoreCameraMoveUntil = DateTime.now().add(
          const Duration(milliseconds: 800),
        );
        map.move(
          initialCenter,
          map.zoom,
        );
      } catch (e) {
        await mapCameraMove(
          fallbackCenter,
          isPickup: isPickup,
        );
      }
    });
  }

  AppMapController? get map => _map;

  gmaps.LatLng? get mapCenter => _map?.center;

  Future<gmaps.LatLng?> zoomToCurrentLocation({double zoom = 16}) async {
    var target = await getMyLatLng(
      forceFresh: true,
    );
    if (target == null) {
      await Future.delayed(
        const Duration(milliseconds: 1200),
      );
      target = await getMyLatLng(
        forceFresh: true,
      );
    }
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
    final requestGeneration = _selectionGeneration;
    if (!skipSelectedAddress) {
      _setSelectedAddressSafely(null);
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
          if (requestGeneration != _selectionGeneration) {
            return;
          }
          await addressSelected(
            address,
            animate: true,
            isPickup: isPickup,
            shouldAdvanceGeneration: false,
          );
        } catch (e) {
          if (requestGeneration != _selectionGeneration) {
            return;
          }
          _setSelectedAddressSafely(Address(
            coordinates: Coordinates(
              double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
              double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
            ),
          ));
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
    bool shouldAdvanceGeneration = true,
  }) async {
    _debounce?.cancel();
    if (shouldAdvanceGeneration) {
      _selectionGeneration++;
    }
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
      _setSelectedAddressSafely(resolvedAddress);
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

  Future<void> selectSpotAddress(
    Address address, {
    required bool isPickup,
  }) async {
    _beginManualSelectionGuard();
    try {
      await addressSelected(
        address,
        animate: true,
        isPickup: isPickup,
        shouldAdvanceGeneration: false,
      );
    } finally {
      _endManualSelectionGuard();
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
