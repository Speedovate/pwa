import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps/google_maps.dart' as google_maps;
import 'package:pwa/services/map.service.dart';
import 'package:pwa/utils/map_controller.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;
import 'package:pwa/widgets/gmap_google_legacy.widget.dart' as legacy_google;
import 'package:pwa/widgets/network_image.widget.dart';

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
  final fmap.MapController _leafletMapController = fmap.MapController();
  bool _leafletMapReady = false;
  late bool _useLeafletFallback;

  @override
  void initState() {
    super.initState();
    _useLeafletFallback = MapService.isLeafletFallbackPreferred;
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useLeafletFallback && _leafletMapReady) {
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

    if (event is fmap.MapEventMoveEnd &&
        _isLeafletUserMoveSource(event.source)) {
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
            _LeafletMapController(_leafletMapController),
          );
        },
        onTap: (_, __) {
          widget.onTap?.call();
        },
        onMapEvent: _handleLeafletMapEvent,
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ppctoda.customer',
        ),
        if (widget.polylines.isNotEmpty)
          fmap.PolylineLayer(
            polylines: widget.polylines
                .map(
                  (polyline) => fmap.Polyline(
                    points: polyline.points
                        .map((point) => point.toLeafletLatLng())
                        .toList(),
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
                        child: NetworkImageWidget(
                          imageUrl: marker.imageUrl,
                          memCacheWidth: 600,
                          width: marker.width,
                          height: marker.height,
                          fit: BoxFit.contain,
                          errorWidget: (context, imageUrl, error) {
                            return const SizedBox.shrink();
                          },
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
    if (!_useLeafletFallback) {
      return legacy_google.GoogleMapWidget(
        key: const ValueKey('legacy-google-map'),
        center: widget.center,
        enableGestures: widget.enableGestures,
        markers: widget.markers,
        polylines: widget.polylines,
        onMapCreated: (map) {
          widget.onMapCreated?.call(
            _WebGoogleMapController(map),
          );
        },
        onCameraMoveStart: widget.onCameraMoveStart,
        onCameraMove: (center) {
          widget.onCameraMove?.call(
            app_maps.LatLng(center.lat.toDouble(), center.lng.toDouble()),
          );
        },
        onTap: widget.onTap,
        onLoadError: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _useLeafletFallback = true;
          });
        },
      );
    }
    return _buildLeafletMap();
  }
}

class _LeafletMapController implements AppMapController {
  _LeafletMapController(this.raw);

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
    bool animated = true,
  }) {
    raw.fitCamera(
      fmap.CameraFit.coordinates(
        coordinates:
            coordinates.map((point) => point.toLeafletLatLng()).toList(),
        padding: padding,
      ),
    );
  }
}

class _WebGoogleMapController implements AppMapController {
  _WebGoogleMapController(this.raw);

  final google_maps.Map raw;

  @override
  app_maps.LatLng get center =>
      app_maps.LatLng(raw.center.lat.toDouble(), raw.center.lng.toDouble());

  @override
  double get zoom => raw.zoom.toDouble();

  @override
  void move(app_maps.LatLng target, double zoom) {
    raw.center = google_maps.LatLng(target.lat, target.lng);
    raw.zoom = zoom;
  }

  @override
  void recenter(
    app_maps.LatLng target, {
    double? zoom,
  }) {
    raw.panTo(google_maps.LatLng(target.lat, target.lng));
    if (zoom != null) {
      raw.zoom = zoom;
    }
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
    final bounds = google_maps.LatLngBounds.empty();
    for (final coordinate in coordinates) {
      bounds.extend(google_maps.LatLng(coordinate.lat, coordinate.lng));
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
    raw.fitBounds(
      bounds,
      boundsPadding.round().toJS,
    );
  }
}
