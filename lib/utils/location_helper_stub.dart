import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;

Future<gmaps.LatLng?> getMyLatLng({
  bool forceFresh = false,
  bool requestPermission = true,
}) async {
  try {
    lastGeolocationErrorMessage = null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw 'PERMISSION_DENIED: Location access was denied';
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: _locationSettings(forceFresh: forceFresh),
    );
    return _storeRealLatLng(position.latitude, position.longitude);
  } catch (e) {
    final existingLocation =
        _nonDefaultLatLng(lastKnownRealLatLng) ?? _nonDefaultLatLng(initLatLng);
    initLatLng = existingLocation ?? defaultLatLng;
    lastGeolocationErrorMessage = '$e';
    return initLatLng;
  }
}

gmaps.LatLng _storeRealLatLng(double lat, double lng) {
  final nextLatLng = gmaps.LatLng(lat, lng);
  initLatLng = nextLatLng;
  lastKnownRealLatLng = nextLatLng;
  hasRealLocationFix = true;
  return nextLatLng;
}

gmaps.LatLng? _nonDefaultLatLng(gmaps.LatLng? value) {
  if (value == null) {
    return null;
  }
  if (value.lat == defaultLatLng.lat && value.lng == defaultLatLng.lng) {
    return null;
  }
  return value;
}

LocationSettings _locationSettings({
  required bool forceFresh,
}) {
  final timeLimit =
      forceFresh ? const Duration(seconds: 15) : const Duration(seconds: 8);
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );
    default:
      return LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );
  }
}
