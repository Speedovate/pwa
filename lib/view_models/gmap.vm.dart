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
  bool isInitializing = false;
  List<WebMarker> markers = [];
  List<gmaps.Polyline>? polylines = [];
  TaxiRequest taxiRequest = TaxiRequest();
  ValueNotifier<gmaps.LatLng>? lastCenter;
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

  setMap(gmaps.Map map) {
    _map = map;
    isInitializing = true;
    mapCameraMove("setMap", _map?.center);
  }

  gmaps.Map? get map => _map;

  zoomToCurrentLocation({double zoom = 16}) async {
    if (_map != null) {
      final target = initLatLng;
      _map!.panTo(target!);
      _map!.zoom = zoom;
    }
  }

  zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom + 1).clamp(2, 21);
    }
  }

  zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom - 1).clamp(2, 21);
    }
  }

  mapCameraMove(
    String function,
    gmaps.LatLng? target, {
    bool skipSelectedAddress = false,
  }) async {
    debugPrint("Map move - $function");
    if (!skipSelectedAddress) {
      selectedAddress.value = null;
    }
    locUnavailable = false;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () async {
        if (!skipSelectedAddress) {
          selectedAddress.value = null;
          isLoading = true;
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
          isInitializing = false;
          await addressSelected(address, animate: true);
        } catch (e) {
          clearGMapDetails();
          isLoading = false;
          isInitializing = false;
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

  addressSelected(
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

  drawPickPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng driverLatLng,
  ) async {
    if (_map == null) return;
    for (var m in markers) {
      m.marker.map = null;
    }
    markers.clear();
    polylines?.forEach((p) => p.map = null);
    polylines?.clear();
    final pickupMarker = gmaps.Marker(
      gmaps.MarkerOptions(
        map: _map,
        position: pickupLatLng,
        title: "Pickup Location",
      )..icon = gmaps.Icon(
          url: 'https://storage.googleapis.com/ppc_toda_app/pickup.png',
          scaledSize: gmaps.Size(50, 50),
        ),
    );
    markers.add(WebMarker(id: "pickupMarker", marker: pickupMarker));
    final driverMarker = gmaps.Marker(
      gmaps.MarkerOptions(
        map: _map,
        position: driverLatLng,
        title: "Driver Location",
      )..icon = gmaps.Icon(
          url: 'https://storage.googleapis.com/ppc_toda_app/driver.png',
          scaledSize: gmaps.Size(35, 35),
        ),
    );
    markers.add(WebMarker(id: "driverMarker", marker: driverMarker));
    try {
      final result = await geocoderService.getPolyline(
        driverLatLng,
        pickupLatLng,
        purpose,
      );
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        final pathJs = js_util.jsify(points);
        final polyline = gmaps.Polyline(
          gmaps.PolylineOptions()
            ..path = pathJs
            ..strokeColor = "#42A5F5"
            ..strokeOpacity = 1
            ..strokeWeight = 6
            ..map = _map,
        );
        polylines?.add(polyline);
        final allPoints = [driverLatLng, ...points, pickupLatLng];
        num minLat = allPoints.first.lat;
        num minLng = allPoints.first.lng;
        num maxLat = allPoints.last.lat;
        num maxLng = allPoints.last.lng;
        for (var point in allPoints) {
          if (point.lat < minLat) minLat = point.lat;
          if (point.lat > maxLat) maxLat = point.lat;
          if (point.lng < minLng) minLng = point.lng;
          if (point.lng > maxLng) maxLng = point.lng;
        }
        const offset = 0.002;
        if ((maxLat - minLat).abs() < offset) {
          maxLat += offset;
          minLat -= offset;
        }
        if ((maxLng - minLng).abs() < offset) {
          maxLng += offset;
          minLng -= offset;
        }
        final bounds = gmaps.LatLngBounds(
          gmaps.LatLng(minLat, minLng),
          gmaps.LatLng(maxLat, maxLng),
        );
        _map!.fitBounds(bounds);
      } else {
        debugPrint("No polyline points received from backend");
      }
    } catch (e) {
      debugPrint("Error drawing pick polyline: $e");
    }
  }

  drawDropPolyLines(
    String purpose,
    gmaps.LatLng pickupLatLng,
    gmaps.LatLng dropoffLatLng,
    gmaps.LatLng? driverLatLng,
  ) async {
    if (_map == null) return;
    for (var m in markers) {
      m.marker.map = null;
    }
    markers.clear();
    polylines?.forEach((p) => p.map = null);
    polylines?.clear();
    final pickupMarker = gmaps.Marker(
      gmaps.MarkerOptions(
        map: _map,
        position: pickupLatLng,
        title: "Pickup Location",
      )..icon = gmaps.Icon(
          url: 'https://storage.googleapis.com/ppc_toda_app/pickup.png',
          scaledSize: gmaps.Size(50, 50),
        ),
    );
    markers.add(WebMarker(id: "pickupMarker", marker: pickupMarker));
    final dropoffMarker = gmaps.Marker(
      gmaps.MarkerOptions(
        map: _map,
        position: dropoffLatLng,
        title: "Dropoff Location",
      )..icon = gmaps.Icon(
          url: 'https://storage.googleapis.com/ppc_toda_app/dropoff.png',
          scaledSize: gmaps.Size(50, 50),
        ),
    );
    markers.add(WebMarker(id: "dropoffMarker", marker: dropoffMarker));
    if (driverLatLng != null) {
      final driverMarker = gmaps.Marker(
        gmaps.MarkerOptions(
          map: _map,
          position: driverLatLng,
          title: "Driver Location",
        )..icon = gmaps.Icon(
            url: 'https://storage.googleapis.com/ppc_toda_app/driver.png',
            scaledSize: gmaps.Size(35, 35),
          ),
      );
      markers.add(WebMarker(id: "driverMarker", marker: driverMarker));
    }
    try {
      final result = await geocoderService.getPolyline(
        pickupLatLng,
        dropoffLatLng,
        purpose,
      );
      if (result.isNotEmpty) {
        final points = result.map((p) => gmaps.LatLng(p[0], p[1])).toList();
        final pathJs = js_util.jsify(points);
        final polyline = gmaps.Polyline(
          gmaps.PolylineOptions()
            ..path = pathJs
            ..strokeColor = "#42A5F5"
            ..strokeOpacity = 1
            ..strokeWeight = 8
            ..map = _map,
        );
        polylines?.add(polyline);
        final allPoints = [pickupLatLng, ...points, dropoffLatLng];
        num minLat = allPoints.first.lat;
        num minLng = allPoints.first.lng;
        num maxLat = allPoints.last.lat;
        num maxLng = allPoints.last.lng;
        for (var point in allPoints) {
          if (point.lat < minLat) minLat = point.lat;
          if (point.lat > maxLat) maxLat = point.lat;
          if (point.lng < minLng) minLng = point.lng;
          if (point.lng > maxLng) maxLng = point.lng;
        }
        const offset = 0.002;
        if ((maxLat - minLat).abs() < offset) {
          maxLat += offset;
          minLat -= offset;
        }
        if ((maxLng - minLng).abs() < offset) {
          maxLng += offset;
          minLng -= offset;
        }
        final bounds = gmaps.LatLngBounds(
          gmaps.LatLng(minLat, minLng),
          gmaps.LatLng(maxLat, maxLng),
        );
        _map!.fitBounds(bounds);
      } else {
        debugPrint("No polyline points received from backend");
      }
    } catch (e) {
      debugPrint("Error drawing drop polyline: $e");
    }
  }

  clearGMapDetails() {
    for (var m in markers) {
      m.marker.map = null;
    }
    markers.clear();
    polylines?.forEach((p) => p.map = null);
    polylines = [];
  }

  updateDriverMarkerPosition(gmaps.LatLng position) {
    if (_map == null) return;
    WebMarker? existing;
    try {
      existing = markers.firstWhere((m) => m.id == 'driverMarker');
    } catch (e) {
      existing = null;
    }
    if (existing == null) {
      final marker = gmaps.Marker(
        gmaps.MarkerOptions(
          map: _map,
          position: position,
          title: "Driver Location",
        )..icon = gmaps.Icon(
            url: 'https://storage.googleapis.com/ppc_toda_app/driver.png',
            scaledSize: gmaps.Size(35, 35),
          ),
      );
      markers.add(WebMarker(id: 'driverMarker', marker: marker));
    } else {
      existing.marker.position = position;
    }
  }
}

class WebMarker {
  final String id;
  final gmaps.Marker marker;

  WebMarker({required this.id, required this.marker});
}
