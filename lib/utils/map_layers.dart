import 'package:flutter/material.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;

class MapMarkerData {
  final String id;
  final gmaps.LatLng position;
  final String imageUrl;
  final double width;
  final double height;
  final double rotationDegrees;
  final int zIndex;
  final bool? flat;
  final Offset? anchor;

  const MapMarkerData({
    required this.id,
    required this.position,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.rotationDegrees = 0,
    this.zIndex = 0,
    this.flat,
    this.anchor,
  });

  MapMarkerData copyWith({
    gmaps.LatLng? position,
    double? rotationDegrees,
    int? zIndex,
    bool? flat,
    Offset? anchor,
  }) {
    return MapMarkerData(
      id: id,
      position: position ?? this.position,
      imageUrl: imageUrl,
      width: width,
      height: height,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      zIndex: zIndex ?? this.zIndex,
      flat: flat ?? this.flat,
      anchor: anchor ?? this.anchor,
    );
  }
}

class MapPolylineData {
  final List<gmaps.LatLng> points;
  final Color color;
  final double strokeWidth;

  const MapPolylineData({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}
