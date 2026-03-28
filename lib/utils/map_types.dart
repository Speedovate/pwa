import 'package:latlong2/latlong.dart' as leaflet;

class LatLng extends leaflet.LatLng {
  const LatLng(super.lat, super.lng);

  double get lat => latitude;
  double get lng => longitude;
}

extension LeafletLatLngX on leaflet.LatLng {
  LatLng toAppLatLng() => LatLng(latitude, longitude);
}
