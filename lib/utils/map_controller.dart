import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps/google_maps.dart' as google_maps;
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
  });
}

class LeafletMapController implements AppMapController {
  LeafletMapController(this.raw);

  final fmap.MapController raw;

  @override
  app_maps.LatLng get center => raw.camera.center.toAppLatLng();

  @override
  double get zoom => raw.camera.zoom;

  @override
  void move(app_maps.LatLng target, double zoom) {
    raw.move(target.toLeafletLatLng(), zoom);
  }

  @override
  void recenter(
    app_maps.LatLng target, {
    double? zoom,
  }) {
    raw.move(target.toLeafletLatLng(), zoom ?? raw.camera.zoom);
  }

  @override
  void fitToCoordinates(
    List<app_maps.LatLng> coordinates, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    raw.fitCamera(
      fmap.CameraFit.coordinates(
        coordinates: coordinates.map((point) => point.toLeafletLatLng()).toList(),
        padding: padding,
      ),
    );
  }
}

class GoogleMapController implements AppMapController {
  GoogleMapController(this.raw);

  final google_maps.Map raw;

  @override
  app_maps.LatLng get center => raw.center.toAppLatLng();

  @override
  double get zoom => raw.zoom.toDouble();

  @override
  void move(app_maps.LatLng target, double zoom) {
    raw.center = target.toGoogleLatLng();
    raw.zoom = zoom;
  }

  @override
  void recenter(
    app_maps.LatLng target, {
    double? zoom,
  }) {
    raw.panTo(target.toGoogleLatLng());
    if (zoom != null) {
      raw.zoom = zoom;
    }
  }

  @override
  void fitToCoordinates(
    List<app_maps.LatLng> coordinates, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    if (coordinates.isEmpty) {
      return;
    }
    final bounds = google_maps.LatLngBounds.empty();
    for (final coordinate in coordinates) {
      bounds.extend(coordinate.toGoogleLatLng());
    }
    raw.fitBounds(
      bounds,
      padding.left.round().toJS,
    );
  }
}
