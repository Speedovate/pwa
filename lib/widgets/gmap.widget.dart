import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;

class GoogleMapWidget extends StatefulWidget {
  final gmaps.LatLng center;
  final bool enableGestures;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final void Function(fmap.MapController map)? onMapCreated;
  final void Function(gmaps.LatLng)? onCameraMove;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.enableGestures = true,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onCameraMove,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  final fmap.MapController _mapController = fmap.MapController();
  bool _mapReady = false;
  gmaps.LatLng? _pendingCameraMove;

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) {
      return;
    }
    if (!_latLngEquals(oldWidget.center, widget.center)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mapController.move(widget.center, _mapController.camera.zoom);
      });
    }
  }

  bool _latLngEquals(gmaps.LatLng a, gmaps.LatLng b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  void _dispatchCameraMove(gmaps.LatLng center) {
    _pendingCameraMove = center;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingCameraMove == null) {
        return;
      }
      final nextCenter = _pendingCameraMove!;
      _pendingCameraMove = null;
      widget.onCameraMove?.call(nextCenter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final interactionFlags = widget.enableGestures
        ? fmap.InteractiveFlag.all
        : fmap.InteractiveFlag.none;

    return fmap.FlutterMap(
      mapController: _mapController,
      options: fmap.MapOptions(
        initialCenter: widget.center,
        initialZoom: 16,
        interactionOptions: fmap.InteractionOptions(
          flags: interactionFlags,
        ),
        onMapReady: () {
          if (_mapReady) {
            return;
          }
          _mapReady = true;
          widget.onMapCreated?.call(_mapController);
        },
        onPositionChanged: (camera, hasGesture) {
          if (!hasGesture) {
            return;
          }
          _dispatchCameraMove(
            camera.center.toAppLatLng(),
          );
        },
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.osm.ch/switzerland/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ppctoda.pwa',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        if (widget.polylines.isNotEmpty)
          fmap.PolylineLayer(
            polylines: widget.polylines
                .map(
                  (polyline) => fmap.Polyline(
                    points: polyline.points,
                    strokeWidth: polyline.strokeWidth,
                    color: polyline.color,
                  ),
                )
                .toList(),
          ),
        if (widget.markers.isNotEmpty)
          fmap.MarkerLayer(
            markers: widget.markers
                .map(
                  (marker) => fmap.Marker(
                    point: marker.position,
                    width: marker.width,
                    height: marker.height,
                    child: Center(
                      child: Transform.rotate(
                        angle: marker.rotationDegrees * math.pi / 180,
                        child: Image.network(
                          marker.imageUrl,
                          width: marker.width,
                          height: marker.height,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
