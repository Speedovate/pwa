import 'package:flutter/material.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;

abstract class AppMapController {
  app_maps.LatLng get center;
  double get zoom;

  void move(app_maps.LatLng target, double zoom);

  void recenter(
    app_maps.LatLng target, {
    double? zoom,
  });

  void fitToCoordinates(
    List<app_maps.LatLng> coordinates, {
    EdgeInsets padding = const EdgeInsets.all(48),
    bool animated = true,
  });
}
