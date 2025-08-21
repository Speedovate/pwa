import 'dart:ui';
import 'package:stacked/stacked.dart';
import 'package:pwa/utils/functions.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GMapViewModel extends BaseViewModel {
  gmaps.Map? _map;

  void setMap(gmaps.Map map) {
    _map = map;
    _map?.onCenterChanged.listen((event) {
      final center = _map?.center;
      final zoom = _map?.zoom;
      print(
        "Camera move → Center: ${center?.lat}, ${center?.lng}, Zoom: $zoom",
      );
    });
    _map?.onIdle.listen((event) {
      final center = _map?.center;
      final zoom = _map?.zoom;
      print(
        "Camera idle → Center: ${center?.lat}, ${center?.lng}, Zoom: $zoom",
      );
    });
  }

  gmaps.Map? get map => _map;

  Future<void> zoomToCurrentLocation({
    double zoom = 16,
    int durationMs = 100,
  }) async {
    if (_map == null) return;
    final target = await getMyLatLng();
    final startLat = _map!.center.lat;
    final startLng = _map!.center.lng;
    final startZoom = _map!.zoom;
    final endLat = target.lat;
    final endLng = target.lng;
    final endZoom = zoom;
    final distance =
        ((endLat - startLat).abs() + (endLng - startLng).abs()) / 2;
    final steps = (50 + (distance * 200)).clamp(50, 150).toInt();
    final stepDuration = durationMs ~/ steps;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final lat = lerpDouble(startLat, endLat, t)!;
      final lng = lerpDouble(startLng, endLng, t)!;
      final currentZoom = lerpDouble(startZoom, endZoom, t)!;
      _map!.center = gmaps.LatLng(lat, lng);
      _map!.zoom = currentZoom;
      if (i % 2 == 0) notifyListeners();
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
    _map!.center = target;
    _map!.zoom = zoom;
    notifyListeners();
  }

  Future<void> zoomIn() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom + 1).clamp(0, 21);
      notifyListeners();
    }
  }

  Future<void> zoomOut() async {
    if (_map != null) {
      final currentZoom = _map!.zoom.toDouble();
      _map!.zoom = (currentZoom - 1).clamp(0, 21);
      notifyListeners();
    }
  }
}
