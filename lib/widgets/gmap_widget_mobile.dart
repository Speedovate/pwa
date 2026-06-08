import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;

class GoogleMapWidget extends StatefulWidget {
  final app_maps.LatLng center;
  final bool enableGestures;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final void Function(AppMapController map)? onMapCreated;
  final VoidCallback? onCameraMoveStart;
  final void Function(app_maps.LatLng)? onCameraMove;
  final VoidCallback? onTap;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.enableGestures = true,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onCameraMoveStart,
    this.onCameraMove,
    this.onTap,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  static const String _pickupMarkerAssetKey = '__pickup_marker__';
  static const String _dropoffMarkerAssetKey = '__dropoff_marker__';
  final Map<String, gmaps.BitmapDescriptor> _markerIconCache = {};
  final Map<String, Future<void>> _markerLoads = {};
  _MobileGoogleMapController? _appController;
  bool _cameraMoveStarted = false;
  app_maps.LatLng? _latestCenter;

  @override
  void initState() {
    super.initState();
    _primeMarkerIcons(widget.markers);
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _primeMarkerIcons(widget.markers);
  }

  void _primeMarkerIcons(List<MapMarkerData> markers) {
    for (final marker in markers) {
      final iconKey = _iconCacheKey(marker);
      if (_markerIconCache.containsKey(iconKey) ||
          _markerLoads.containsKey(iconKey)) {
        continue;
      }
      _markerLoads[iconKey] = _loadMarkerIcon(marker, iconKey);
    }
  }

  String _iconCacheKey(MapMarkerData marker) {
    switch (marker.id) {
      case 'pickupMarker':
        return _pickupMarkerAssetKey;
      case 'dropoffMarker':
        return _dropoffMarkerAssetKey;
      default:
        return marker.imageUrl;
    }
  }

  Future<void> _loadMarkerIcon(
    MapMarkerData marker,
    String iconKey,
  ) async {
    try {
      final descriptor = switch (marker.id) {
        'pickupMarker' => await _createPinMarkerDescriptor(
            color: const Color(0xFF007BFF),
            size: marker.width,
          ),
        'dropoffMarker' => await _createPinMarkerDescriptor(
            color: Colors.red,
            size: marker.width,
          ),
        _ => await _loadNetworkMarkerDescriptor(marker),
      };
      _markerIconCache[iconKey] = descriptor;
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Default marker is an acceptable fallback on mobile if a remote icon fails.
    } finally {
      _markerLoads.remove(iconKey);
    }
  }

  Future<gmaps.BitmapDescriptor> _loadNetworkMarkerDescriptor(
    MapMarkerData marker,
  ) async {
    final bundle = NetworkAssetBundle(Uri.parse(marker.imageUrl));
    final byteData = await bundle.load(marker.imageUrl);
    final resized = await _resizeMarkerBytes(
      byteData.buffer.asUint8List(),
      width: marker.width.round().clamp(24, 256),
      height: marker.height.round().clamp(24, 256),
    );
    return gmaps.BitmapDescriptor.bytes(resized);
  }

  Future<Uint8List> _resizeMarkerBytes(
    Uint8List sourceBytes, {
    required int width,
    required int height,
  }) async {
    final codec = await ui.instantiateImageCodec(
      sourceBytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<gmaps.BitmapDescriptor> _createPinMarkerDescriptor({
    required Color color,
    required double size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final iconSize = size.clamp(36.0, 72.0);
    final canvasSize = iconSize + 20.0;
    final painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on_sharp.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: Icons.location_on_sharp.fontFamily,
        package: Icons.location_on_sharp.fontPackage,
        color: color,
      ),
    );
    painter.layout();
    final dx = (canvasSize - painter.width) / 2;
    final dy = (canvasSize - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
    final image = await recorder.endRecording().toImage(
          canvasSize.ceil(),
          canvasSize.ceil(),
        );
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return gmaps.BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    return widget.markers.map<gmaps.Marker>((marker) {
      final iconKey = _iconCacheKey(marker);
      final isPinMarker =
          marker.id == 'pickupMarker' || marker.id == 'dropoffMarker';
      return gmaps.Marker(
        markerId: gmaps.MarkerId(marker.id),
        position: gmaps.LatLng(marker.position.lat, marker.position.lng),
        rotation: marker.rotationDegrees,
        zIndex: marker.zIndex.toDouble(),
        flat: !isPinMarker,
        anchor: isPinMarker ? const Offset(0.5, 1.0) : const Offset(0.5, 0.5),
        icon: _markerIconCache[iconKey] ?? gmaps.BitmapDescriptor.defaultMarker,
      );
    }).toSet();
  }

  Set<gmaps.Polyline> _buildPolylines() {
    return widget.polylines.map((polyline) {
      return gmaps.Polyline(
        polylineId: gmaps.PolylineId(
          polyline.points.map((point) => '${point.lat},${point.lng}').join('|'),
        ),
        points: polyline.points
            .map((point) => gmaps.LatLng(point.lat, point.lng))
            .toList(),
        color: polyline.color,
        width: math.max(1, polyline.strokeWidth.round()),
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        jointType: gmaps.JointType.round,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(widget.center.lat, widget.center.lng),
        zoom: 16,
      ),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: widget.enableGestures,
      rotateGesturesEnabled: widget.enableGestures,
      zoomGesturesEnabled: widget.enableGestures,
      scrollGesturesEnabled: widget.enableGestures,
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      onMapCreated: (controller) {
        _appController = _MobileGoogleMapController(
          raw: controller,
          initialCenter: widget.center,
          initialZoom: 16,
        );
        widget.onMapCreated?.call(_appController!);
      },
      onCameraMoveStarted: () {
        if (_cameraMoveStarted) {
          return;
        }
        _cameraMoveStarted = true;
        widget.onCameraMoveStart?.call();
      },
      onCameraMove: (position) {
        _appController?.updateCameraPosition(position);
        _latestCenter = app_maps.LatLng(
          position.target.latitude,
          position.target.longitude,
        );
      },
      onTap: (_) {
        widget.onTap?.call();
      },
      onCameraIdle: () {
        final latestCenter = _latestCenter ?? _appController?.center;
        _cameraMoveStarted = false;
        if (latestCenter != null) {
          widget.onCameraMove?.call(latestCenter);
        }
      },
    );
  }
}

class _MobileGoogleMapController implements AppMapController {
  _MobileGoogleMapController({
    required this.raw,
    required app_maps.LatLng initialCenter,
    required double initialZoom,
  })  : _center = initialCenter,
        _zoom = initialZoom;

  final gmaps.GoogleMapController raw;
  app_maps.LatLng _center;
  double _zoom;

  void updateCameraPosition(gmaps.CameraPosition position) {
    _center = app_maps.LatLng(
      position.target.latitude,
      position.target.longitude,
    );
    _zoom = position.zoom;
  }

  @override
  app_maps.LatLng get center => _center;

  @override
  double get zoom => _zoom;

  @override
  void move(app_maps.LatLng target, double zoom) {
    _center = target;
    _zoom = zoom;
    raw.moveCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(target.lat, target.lng),
          zoom: zoom,
        ),
      ),
    );
  }

  @override
  void recenter(
    app_maps.LatLng target, {
    double? zoom,
  }) {
    _center = target;
    if (zoom != null) {
      _zoom = zoom;
    }
    raw.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(target.lat, target.lng),
          zoom: zoom ?? _zoom,
        ),
      ),
    );
  }

  @override
  void fitToCoordinates(
    List<app_maps.LatLng> coordinates, {
    EdgeInsets padding = const EdgeInsets.all(48),
    bool animated = true,
  }) {
    if (coordinates.isEmpty) {
      return;
    }

    var minLat = coordinates.first.lat;
    var maxLat = coordinates.first.lat;
    var minLng = coordinates.first.lng;
    var maxLng = coordinates.first.lng;

    for (final coordinate in coordinates.skip(1)) {
      minLat = math.min(minLat, coordinate.lat);
      maxLat = math.max(maxLat, coordinate.lat);
      minLng = math.min(minLng, coordinate.lng);
      maxLng = math.max(maxLng, coordinate.lng);
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final boundsPadding = lngSpan >= latSpan
        ? math.max(padding.left, padding.right)
        : math.max(padding.top, padding.bottom);
    final update = gmaps.CameraUpdate.newLatLngBounds(
      gmaps.LatLngBounds(
        southwest: gmaps.LatLng(minLat, minLng),
        northeast: gmaps.LatLng(maxLat, maxLng),
      ),
      boundsPadding,
    );
    if (animated) {
      raw.animateCamera(update);
    } else {
      raw.moveCamera(update);
    }
  }
}
