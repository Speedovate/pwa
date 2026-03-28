import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
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
  final void Function(app_maps.LatLng)? onCameraMove;

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
  final fmap.MapController _leafletMapController = fmap.MapController();
  Timer? _leafletCameraMoveDebounce;
  bool _leafletMapReady = false;
  bool? _useGoogleMaps;
  app_maps.LatLng? _pendingLeafletCameraMove;

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
  void dispose() {
    _leafletCameraMoveDebounce?.cancel();
    super.dispose();
  }

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

  void _dispatchLeafletCameraMove(app_maps.LatLng center) {
    _pendingLeafletCameraMove = center;
    _leafletCameraMoveDebounce?.cancel();
    _leafletCameraMoveDebounce = Timer(
      Duration(milliseconds: MapService.isLeafletFallbackPreferred ? 220 : 120),
      () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _pendingLeafletCameraMove == null) {
            return;
          }
          final nextCenter = _pendingLeafletCameraMove!;
          _pendingLeafletCameraMove = null;
          widget.onCameraMove?.call(nextCenter);
        });
      },
    );
  }

  Widget _buildLeafletMap() {
    final useRetinaTiles = MediaQuery.devicePixelRatioOf(context) > 1.25;
    final interactionFlags = widget.enableGestures
        ? (MapService.isLeafletFallbackPreferred
            ? fmap.InteractiveFlag.drag |
                fmap.InteractiveFlag.pinchZoom |
                fmap.InteractiveFlag.doubleTapZoom |
                fmap.InteractiveFlag.pinchMove |
                fmap.InteractiveFlag.flingAnimation
            : fmap.InteractiveFlag.all)
        : fmap.InteractiveFlag.none;

    return fmap.FlutterMap(
      mapController: _leafletMapController,
      options: fmap.MapOptions(
        initialCenter: widget.center.toLeafletLatLng(),
        initialZoom: 16,
        interactionOptions: fmap.InteractionOptions(
          flags: interactionFlags,
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
        onPositionChanged: (camera, hasGesture) {
          if (!hasGesture) {
            return;
          }
          _dispatchLeafletCameraMove(
            camera.center.toAppLatLng(),
          );
        },
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          retinaMode: useRetinaTiles,
          userAgentPackageName: 'com.ppctoda.pwa',
          tileProvider: CancellableNetworkTileProvider(),
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
                          filterQuality: FilterQuality.medium,
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
