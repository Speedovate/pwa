import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:pwa/services/map.service.dart';
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;
import 'package:pwa/widgets/gmap_google_legacy.widget.dart'
    as legacy_google;

class GoogleMapWidget extends StatefulWidget {
  final app_maps.LatLng center;
  final bool enableGestures;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final void Function(AppMapController map)? onMapCreated;
  final VoidCallback? onCameraMoveStart;
  final void Function(app_maps.LatLng)? onCameraMove;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.enableGestures = true,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onCameraMoveStart,
    this.onCameraMove,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  final fmap.MapController _leafletMapController = fmap.MapController();
  bool _leafletMapReady = false;
  bool? _useGoogleMaps;

  @override
  void initState() {
    super.initState();
    _useGoogleMaps = MapService.initialEngineDecision;
    if (_useGoogleMaps == null) {
      _resolveEngine();
    }
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useGoogleMaps == false && _leafletMapReady) {
      if (!_latLngEquals(oldWidget.center, widget.center)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _leafletMapController.move(
            widget.center.toLeafletLatLng(),
            _leafletMapController.camera.zoom,
          );
        });
      }
    }
  }

  @override
  void dispose() => super.dispose();

  Future<void> _resolveEngine() async {
    if (!MapService.shouldUseGoogleMapsByDefault) {
      if (mounted) {
        setState(() {
          _useGoogleMaps = false;
        });
      }
      return;
    }

    final ready = await MapService.ensureGoogleMapsReady();
    if (!mounted) {
      return;
    }
    setState(() {
      _useGoogleMaps = ready;
    });
  }

  bool _latLngEquals(app_maps.LatLng a, app_maps.LatLng b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  bool _isLeafletUserMoveSource(fmap.MapEventSource source) {
    return source != fmap.MapEventSource.mapController;
  }

  void _handleLeafletMapEvent(fmap.MapEvent event) {
    if (!_leafletMapReady || !widget.enableGestures) {
      return;
    }

    if (event is fmap.MapEventMoveStart &&
        _isLeafletUserMoveSource(event.source)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onCameraMoveStart?.call();
      });
      return;
    }

    if (event is fmap.MapEventMoveEnd && _isLeafletUserMoveSource(event.source)) {
      final center = event.camera.center.toAppLatLng();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onCameraMove?.call(center);
      });
    }
  }

  Widget _buildLeafletMap() {
    return fmap.FlutterMap(
      mapController: _leafletMapController,
      options: fmap.MapOptions(
        initialCenter: widget.center.toLeafletLatLng(),
        initialZoom: 16,
        interactionOptions: fmap.InteractionOptions(
          flags: widget.enableGestures
              ? fmap.InteractiveFlag.all
              : fmap.InteractiveFlag.none,
        ),
        onMapReady: () {
          if (_leafletMapReady) {
            return;
          }
          _leafletMapReady = true;
          widget.onMapCreated?.call(
            LeafletMapController(_leafletMapController),
          );
        },
        onMapEvent: _handleLeafletMapEvent,
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ppctoda.pwa',
        ),
        if (widget.polylines.isNotEmpty)
          fmap.PolylineLayer(
            polylines: widget.polylines
                .map(
                  (polyline) => fmap.Polyline(
                    points: polyline.points.map((point) => point.toLeafletLatLng()).toList(),
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
                    point: marker.position.toLeafletLatLng(),
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
                          filterQuality: FilterQuality.low,
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

  @override
  Widget build(BuildContext context) {
    if (_useGoogleMaps == true) {
      return legacy_google.GoogleMapWidget(
        key: const ValueKey('legacy-google-map'),
        center: widget.center.toGoogleLatLng(),
        enableGestures: widget.enableGestures,
        onMapCreated: (map) {
          widget.onMapCreated?.call(
            GoogleMapController(map),
          );
        },
        onCameraMoveStart: widget.onCameraMoveStart,
        onCameraMove: (center) {
          widget.onCameraMove?.call(
            center.toAppLatLng(),
          );
        },
      );
    }
    if (_useGoogleMaps == null) {
      return const SizedBox.expand();
    }
    return _buildLeafletMap();
  }
}
