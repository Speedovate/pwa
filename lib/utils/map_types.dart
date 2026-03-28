import 'package:google_maps/google_maps.dart' as google_maps;
import 'package:latlong2/latlong.dart' as leaflet;

class LatLng extends leaflet.LatLng {
  const LatLng(super.lat, super.lng);

  double get lat => latitude;
  double get lng => longitude;
}

extension LeafletLatLngX on leaflet.LatLng {
  LatLng toAppLatLng() => LatLng(latitude, longitude);
}

extension AppLatLngLeafletX on LatLng {
  leaflet.LatLng toLeafletLatLng() => leaflet.LatLng(lat, lng);

  google_maps.LatLng toGoogleLatLng() => google_maps.LatLng(lat, lng);
}

extension GoogleLatLngX on google_maps.LatLng {
  LatLng toAppLatLng() => LatLng(lat.toDouble(), lng.toDouble());
}
