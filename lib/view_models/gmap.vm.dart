// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:get/get.dart';
import 'dart:js_util' as js_util;
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
  List<gmaps.Marker>? markers = [];
  List<gmaps.Polyline>? polylines = [];
  TaxiRequest taxiRequest = TaxiRequest();
  GeocoderService geocoderService = GeocoderService();
  ValueNotifier<Address?> selectedAddress = ValueNotifier(null);

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    selectedAddress.dispose();
    _map?.controls.clear();
    _map = null;
    super.dispose();
  }

  void setMap(gmaps.Map map) async {
    _map = map;
    debugPrint("Map set");
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      mapCameraMove(_map?.center);
      debugPrint("Map init");
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
      selectedAddress.value = null;
      notifyListeners();
    }
    locUnavailable = false;
    _debounce?.cancel();
    notifyListeners();
    _debounce = Timer(
      const Duration(seconds: 2),
      () async {
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
              double.parse("${target?.lat ?? 9.7638}"),
              double.parse("${target?.lng ?? 118.7473}"),
            ),
          );
          final Address address = addresses.first;
          isLoading = false;
          await addressSelected(address, animate: true);
        } catch (e) {
          clearGMapDetails();
          isLoading = false;
          selectedAddress.value = Address(
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
      selectedAddress.value = address;
      pickupAddress = address;
      if (_map != null) {
        num currentZoom = _map!.zoom;
        if (animate) {
          _map!.panTo(
            gmaps.LatLng(
              address.coordinates.latitude,
              address.coordinates.longitude,
            ),
          );
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

  Future<void> drawDropPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng dropoffLatLng,
    gmaps.LatLng? driverLatLng,
  ) async {
    if (_map == null) return;
    markers?.forEach((m) => m.map = null);
    markers = [];
    polylines?.forEach((p) => p.map = null);
    polylines = [];
    markers?.addAll(
      [
        gmaps.Marker(
          gmaps.MarkerOptions(
            position: pickupLatLng,
            map: _map,
            // icon: js_util.jsify(
            //   {
            //     'url': 'https://ppctoda.com/storage/3394/photo.jpg',
            //     'scaledSize': js_util.jsify({'width': 50, 'height': 50}),
            //   },
            // ),
          ),
        ),
        gmaps.Marker(
          gmaps.MarkerOptions(
            position: dropoffLatLng,
            map: _map,
            // icon: js_util.jsify(
            //   {
            //     'url': 'https://ppctoda.com/storage/3395/photo.jpg',
            //     'scaledSize': js_util.jsify({'width': 50, 'height': 50}),
            //   },
            // ),
          ),
        ),
        if (driverLatLng != null)
          gmaps.Marker(
            gmaps.MarkerOptions(
              position: driverLatLng,
              map: _map,
              // icon: js_util.jsify(
              //   {
              //     'url': 'https://ppctoda.com/storage/3393/photo.jpg',
              //     'scaledSize': js_util.jsify({'width': 50, 'height': 50}),
              //   },
              // ),
            ),
          ),
      ],
    );
    try {
      final result = await geocoderService.getPolyline(
        gmaps.LatLng(pickupAddress!.latLng.lat, pickupAddress!.latLng.lng),
        gmaps.LatLng(dropoffAddress!.latLng.lat, dropoffAddress!.latLng.lng),
        purpose,
      );
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        List<gmaps.LatLng> polylinePoints = points;
        final pathJs = js_util.jsify(polylinePoints);
        final polyline = gmaps.Polyline(
          gmaps.PolylineOptions()
            ..path = pathJs
            ..strokeColor = "#42A5F5"
            ..strokeOpacity = 1
            ..strokeWeight = 8
            ..map = _map,
        );
        polylines?.add(polyline);
        num minLat = polylinePoints.first.lat;
        num minLng = polylinePoints.first.lng;
        num maxLat = polylinePoints.last.lat;
        num maxLng = polylinePoints.last.lng;
        final allPoints = [
          ...polylinePoints,
          if (driverLatLng != null) driverLatLng
        ];
        for (var point in allPoints) {
          if (point.lat < minLat) minLat = point.lat;
          if (point.lat > maxLat) maxLat = point.lat;
          if (point.lng < minLng) minLng = point.lng;
          if (point.lng > maxLng) maxLng = point.lng;
        }
        const offset = 0.001;
        if ((maxLat - minLat).abs() < offset) {
          maxLat += offset;
          minLat -= offset;
        }
        if ((maxLng - minLng).abs() < offset) {
          maxLng += offset;
          minLng -= offset;
        }
        final sw = gmaps.LatLng(minLat, minLng);
        final ne = gmaps.LatLng(maxLat, maxLng);
        final bounds = gmaps.LatLngBounds(sw, ne);
        _map!.fitBounds(bounds);
      } else {
        debugPrint("No polyline points received from backend");
      }
    } catch (e) {
      debugPrint("Error drawing polyline: $e");
    }
  }

  clearGMapDetails() {
    markers?.forEach((m) => m.map = null);
    markers = [];
    polylines?.forEach((p) => p.map = null);
    polylines = [];
  }
}
