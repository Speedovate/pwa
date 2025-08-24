import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
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

  Future<void> zoomToCurrentLocation({double zoom = 16}) async {
    if (_map != null) {
      final target = initLatLng ?? gmaps.LatLng(9.7638, 118.7473);
      _map!.panTo(target);
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
}
