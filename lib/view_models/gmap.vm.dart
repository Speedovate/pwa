import 'package:stacked/stacked.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GMapViewModel extends BaseViewModel {
  gmaps.Map? _map;

  void setMap(gmaps.Map map) {
    _map = map;
  }

  gmaps.Map? get map => _map;
}
