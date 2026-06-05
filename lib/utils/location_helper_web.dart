// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;

Future<gmaps.LatLng?> getMyLatLng({
  bool forceFresh = false,
  bool requestPermission = true,
}) async {
  final useFastTimeout =
      !forceFresh && hasRealLocationFix && lastKnownRealLatLng != null;
  try {
    lastGeolocationErrorMessage = null;
    final position = await _requestCurrentPosition(
      enableHighAccuracy: true,
      timeout: useFastTimeout ? const Duration(seconds: 5) : null,
      maximumAge: useFastTimeout ? const Duration(seconds: 30) : Duration.zero,
    );
    return _storeRealLatLng(position);
  } catch (e) {
    final permissionDenied = await _isGeolocationDenied();
    if (!permissionDenied) {
      try {
        final relaxedPosition = await _requestCurrentPosition(
          enableHighAccuracy: false,
          timeout: const Duration(seconds: 10),
          maximumAge: const Duration(seconds: 30),
        );
        lastGeolocationErrorMessage = null;
        return _storeRealLatLng(relaxedPosition);
      } catch (retryError) {
        lastGeolocationErrorMessage = _describeGeolocationError(retryError);
      }
    }
    final existingLocation =
        _nonDefaultLatLng(lastKnownRealLatLng) ?? _nonDefaultLatLng(initLatLng);
    initLatLng = existingLocation ?? defaultLatLng;
    lastGeolocationErrorMessage ??= _describeGeolocationError(e);
    return initLatLng;
  }
}

Future<html.Geoposition> _requestCurrentPosition({
  required bool enableHighAccuracy,
  required Duration? timeout,
  required Duration maximumAge,
}) {
  return html.window.navigator.geolocation.getCurrentPosition(
    enableHighAccuracy: enableHighAccuracy,
    timeout: timeout,
    maximumAge: maximumAge,
  );
}

gmaps.LatLng _storeRealLatLng(html.Geoposition position) {
  final lat = position.coords?.latitude;
  final lng = position.coords?.longitude;
  if (lat == null || lng == null) {
    throw 'Location coordinates are unavailable';
  }
  final nextLatLng = gmaps.LatLng(
    lat.toDouble(),
    lng.toDouble(),
  );
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

String _describeGeolocationError(Object error) {
  try {
    final jsError = error as JSObject;
    final code = jsError.getProperty<JSAny?>('code'.toJS)?.dartify();
    final message = jsError.getProperty<JSAny?>('message'.toJS)?.dartify();
    final normalizedCode = '$code';
    final readableCode = switch (normalizedCode) {
      '1' => 'PERMISSION_DENIED',
      '2' => 'POSITION_UNAVAILABLE',
      '3' => 'TIMEOUT',
      _ => 'UNKNOWN_ERROR',
    };
    return '$readableCode: $message';
  } catch (_) {
    return '$error';
  }
}

Future<bool> _isGeolocationDenied() async {
  try {
    final permissions = globalContext
        .getProperty<JSObject>('navigator'.toJS)
        .getProperty<JSObject?>('permissions'.toJS);
    if (permissions == null) {
      return false;
    }
    final queryPromise = permissions.callMethod<JSPromise<JSObject?>>(
      'query'.toJS,
      {
        'name': 'geolocation',
      }.jsify(),
    );
    final status = await queryPromise.toDart;
    final state = status?.getProperty<JSString?>('state'.toJS)?.toDart;
    return '$state' == 'denied';
  } catch (_) {
    return false;
  }
}
