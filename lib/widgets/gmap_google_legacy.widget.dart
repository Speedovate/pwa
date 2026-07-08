// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart' as gmaps;
import 'package:pwa/services/map.service.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/map_layers.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;

class GoogleMapWidget extends StatefulWidget {
  final app_maps.LatLng center;
  final double initialZoom;
  final EdgeInsets padding;
  final bool enableGestures;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final void Function(gmaps.Map map)? onMapCreated;
  final VoidCallback? onCameraMoveStart;
  final void Function(gmaps.LatLng)? onCameraMove;
  final VoidCallback? onLoadError;
  final VoidCallback? onTap;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.initialZoom = 16,
    this.padding = EdgeInsets.zero,
    this.enableGestures = true,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onCameraMoveStart,
    this.onCameraMove,
    this.onLoadError,
    this.onTap,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  static const Duration _centerChangeIdleDuration = Duration(milliseconds: 180);
  late final String viewId;
  gmaps.Map? _map;
  StreamSubscription? _dragStartSub;
  StreamSubscription? _centerChangedSub;
  StreamSubscription? _idleSub;
  StreamSubscription<html.Event>? _mouseDownSub;
  StreamSubscription<html.Event>? _touchStartSub;
  StreamSubscription<html.Event>? _mouseUpSub;
  StreamSubscription<html.Event>? _touchEndSub;
  StreamSubscription? _clickSub;
  Timer? _centerIdleTimer;
  bool _mapInitialized = false;
  bool _isViewRegistered = false;
  bool _hasLoadError = false;
  bool _cameraMoveStartSent = false;
  bool _suppressCameraCallbacks = false;
  gmaps.LatLng? _latestCenter;
  final Map<String, gmaps.Marker> _renderedMarkers = {};
  final List<gmaps.Polyline> _renderedPolylines = [];
  List<MapPolylineData> _renderedPolylineData = [];

  @override
  void initState() {
    super.initState();
    viewId = 'map-div-${DateTime.now().microsecondsSinceEpoch}';
    _ensureHideGmapUiStyle();
    _initializeMap();
  }

  void _initializeMap() {
    () async {
      try {
        final ready = await MapService.ensureGoogleMapsReady();
        if (!ready) {
          _handleLoadError();
          return;
        }
        if (!mounted) {
          return;
        }
        ui.platformViewRegistry.registerViewFactory(
          viewId,
          (int _) {
            final mapDiv = html.DivElement()
              ..id = viewId
              ..style.width = '100%'
              ..style.height = '100%';
            _mouseDownSub = mapDiv.onMouseDown.listen((_) {
              _cameraMoveStartSent = false;
            });
            _touchStartSub = mapDiv.onTouchStart.listen((_) {
              _cameraMoveStartSent = false;
            });
            _mouseUpSub = mapDiv.onMouseUp.listen((_) {
              if (_cameraMoveStartSent) {
                _scheduleCenterIdleCallback();
              }
            });
            _touchEndSub = mapDiv.onTouchEnd.listen((_) {
              if (_cameraMoveStartSent) {
                _scheduleCenterIdleCallback();
              }
            });
            try {
              final mapOptions = gmaps.MapOptions()
                ..zoom = widget.initialZoom
                ..center = gmaps.LatLng(widget.center.lat, widget.center.lng)
                ..clickableIcons = false
                ..disableDefaultUI = true
                ..gestureHandling = widget.enableGestures ? 'greedy' : 'none'
                ..disableDoubleClickZoom = true
                ..mapTypeId = gmaps.MapTypeId.ROADMAP
                ..styles = const [];
              _map = gmaps.Map(mapDiv as dynamic, mapOptions);
              _syncOverlays();
              widget.onMapCreated?.call(_map!);
              _dragStartSub = _map!.onDragstart.listen(
                (_) {
                  _emitCameraMoveStart();
                },
              );
              _centerChangedSub = _map!.onCenterChanged.listen(
                (_) {
                  _latestCenter = _map?.center;
                  if (_suppressCameraCallbacks) {
                    return;
                  }
                  _emitCameraMoveStart();
                  _scheduleCenterIdleCallback();
                },
              );
              _idleSub = _map!.onIdle.listen(
                (_) {
                  _emitCameraMoveEnd(_map?.center);
                },
              );
              _clickSub = _map!.onClick.listen(
                (_) {
                  widget.onTap?.call();
                },
              );
              _mapInitialized = true;
            } catch (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleLoadError();
              });
            }
            return mapDiv;
          },
        );
        _isViewRegistered = true;
        if (mounted) {
          setState(() {});
        }
      } catch (_) {
        _handleLoadError();
      }
    }();
  }

  void _emitCameraMoveStart() {
    if (_cameraMoveStartSent || !mounted) {
      return;
    }
    _cameraMoveStartSent = true;
    widget.onCameraMoveStart?.call();
  }

  void _scheduleCenterIdleCallback() {
    final instanceId = nextTempTimerInstanceId("gmap_legacy.center_idle");
    tempTimerDebug(
      "gmap_legacy.center_idle",
      "schedule",
      details: {
        "instanceId": instanceId,
      },
    );
    _centerIdleTimer?.cancel();
    _centerIdleTimer = Timer(_centerChangeIdleDuration, () {
      tempTimerDebug(
        "gmap_legacy.center_idle",
        "fire",
        details: {
          "instanceId": instanceId,
        },
      );
      _emitCameraMoveEnd(_latestCenter ?? _map?.center);
    });
    if (_centerIdleTimer != null) {
      attachTempTimerInstanceId(_centerIdleTimer!, instanceId);
    }
  }

  void _emitCameraMoveEnd(gmaps.LatLng? center) {
    if (_centerIdleTimer != null) {
      tempTimerDebug(
        "gmap_legacy.center_idle",
        "cancel",
        details: {
          "instanceId": tempTimerInstanceId(_centerIdleTimer),
        },
      );
    }
    _centerIdleTimer?.cancel();
    _centerIdleTimer = null;
    _cameraMoveStartSent = false;
    if (center == null || !mounted) {
      return;
    }
    widget.onCameraMove?.call(center);
  }

  void _handleLoadError() {
    if (_hasLoadError) {
      return;
    }
    _hasLoadError = true;
    widget.onLoadError?.call();
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapInitialized && _map != null) {
      _syncOverlays();
      if (oldWidget.enableGestures != widget.enableGestures) {
        _map!.options = gmaps.MapOptions(
          gestureHandling: widget.enableGestures ? 'greedy' : 'none',
        );
      }
      if (!_latLngEquals(oldWidget.center, widget.center)) {
        _suppressCameraCallbacks = true;
        _map!.panTo(gmaps.LatLng(widget.center.lat, widget.center.lng));
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          _suppressCameraCallbacks = false;
        });
      }
    }
  }

  bool _latLngEquals(app_maps.LatLng a, app_maps.LatLng b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  bool _isPinMarker(MapMarkerData marker) {
    return marker.id == 'pickupMarker' || marker.id == 'dropoffMarker';
  }

  String _pinMarkerSvgUrl(MapMarkerData marker) {
    final color = marker.id == 'dropoffMarker' ? '#F44336' : '#007BFF';
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <path fill="$color" d="M32 4C21.5 4 13 12.5 13 23c0 14.3 19 37 19 37s19-22.7 19-37C51 12.5 42.5 4 32 4z"/>
  <circle cx="32" cy="23" r="8" fill="white" fill-opacity="0.95"/>
</svg>
''';
    return Uri.dataFromString(
      svg,
      mimeType: 'image/svg+xml',
    ).toString();
  }

  String _markerIconUrl(MapMarkerData marker) {
    if (_isPinMarker(marker)) {
      return _pinMarkerSvgUrl(marker);
    }
    return marker.imageUrl;
  }

  void _syncOverlays() {
    if (_map == null) {
      return;
    }
    final nextMarkerIds = widget.markers.map((marker) => marker.id).toSet();
    final removedMarkerIds = _renderedMarkers.keys
        .where((markerId) => !nextMarkerIds.contains(markerId))
        .toList();
    for (final markerId in removedMarkerIds) {
      _renderedMarkers.remove(markerId)?.map = null;
    }

    for (final marker in widget.markers) {
      final nextPosition = gmaps.LatLng(
        marker.position.lat,
        marker.position.lng,
      );
      final nextIcon = gmaps.Icon(
        url: _markerIconUrl(marker),
        scaledSize: gmaps.Size(marker.width, marker.height),
      );
      final renderedMarker = _renderedMarkers[marker.id];
      if (renderedMarker == null) {
        final markerOptions = gmaps.MarkerOptions()
          ..map = _map
          ..position = nextPosition
          ..title = marker.id;
        markerOptions.icon = nextIcon;
        markerOptions.zIndex = marker.zIndex.toDouble();
        _renderedMarkers[marker.id] = gmaps.Marker(markerOptions);
      } else {
        renderedMarker.position = nextPosition;
        renderedMarker.icon = nextIcon;
        renderedMarker.title = marker.id;
        renderedMarker.zIndex = marker.zIndex.toDouble();
        renderedMarker.map = _map;
      }
    }

    final shouldRebuildPolylines =
        _renderedPolylines.length != widget.polylines.length ||
            !_samePolylines(_renderedPolylineData, widget.polylines);
    if (shouldRebuildPolylines) {
      _clearRenderedPolylines();
      for (final polyline in widget.polylines) {
        final polylineOptions = gmaps.PolylineOptions()
          ..path = polyline.points
              .map((point) => gmaps.LatLng(point.lat, point.lng))
              .toList()
              .toJS
          ..strokeColor = _colorToGoogleHex(polyline.color)
          ..strokeOpacity = polyline.color.a
          ..strokeWeight = polyline.strokeWidth
          ..map = _map;
        _renderedPolylines.add(
          gmaps.Polyline(polylineOptions),
        );
      }
      _renderedPolylineData = widget.polylines
          .map(
            (polyline) => MapPolylineData(
              points: List<app_maps.LatLng>.from(polyline.points),
              color: polyline.color,
              strokeWidth: polyline.strokeWidth,
            ),
          )
          .toList();
    }
  }

  bool _samePolylines(
    List<MapPolylineData> currentPolylines,
    List<MapPolylineData> nextPolylines,
  ) {
    if (currentPolylines.length != nextPolylines.length) {
      return false;
    }
    for (var i = 0; i < nextPolylines.length; i++) {
      final current = currentPolylines[i];
      final next = nextPolylines[i];
      if (current.points.length != next.points.length) {
        return false;
      }
      for (var j = 0; j < next.points.length; j++) {
        if (current.points[j].lat != next.points[j].lat ||
            current.points[j].lng != next.points[j].lng) {
          return false;
        }
      }
      if (current.color != next.color ||
          current.strokeWidth != next.strokeWidth) {
        return false;
      }
    }
    return true;
  }

  String _colorToGoogleHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _clearRenderedMarkers() {
    for (final marker in _renderedMarkers.values) {
      marker.map = null;
    }
    _renderedMarkers.clear();
  }

  void _clearRenderedPolylines() {
    for (final polyline in _renderedPolylines) {
      polyline.map = null;
    }
    _renderedPolylines.clear();
    _renderedPolylineData = [];
  }

  @override
  void dispose() {
    _clearRenderedPolylines();
    _clearRenderedMarkers();
    if (_centerIdleTimer != null) {
      tempTimerDebug(
        "gmap_legacy.center_idle",
        "dispose_cancel",
        details: {
          "instanceId": tempTimerInstanceId(_centerIdleTimer),
        },
      );
    }
    _centerIdleTimer?.cancel();
    _centerIdleTimer = null;
    _dragStartSub?.cancel();
    _centerChangedSub?.cancel();
    _idleSub?.cancel();
    _mouseDownSub?.cancel();
    _touchStartSub?.cancel();
    _mouseUpSub?.cancel();
    _touchEndSub?.cancel();
    _clickSub?.cancel();
    super.dispose();
  }

  _ensureHideGmapUiStyle() {
    const styleId = 'gmap-hide-ui';
    if (html.document.getElementById(styleId) != null) return;
    final styleEl = html.StyleElement()
      ..id = styleId
      ..appendText('''
        .gm-style-cc,
        .gm-style-mtc,
        .gm-fullscreen-control,
        .gm-svpc,
        .gmnoprint,
        .gmnoscreen,
        .gm-style img[alt="Google"],
        .gm-style a[href^="https://maps.google.com"],
        .gm-style a[href^="https://www.google.com/maps"] {
          display: none !important;
          visibility: hidden !important;
          pointer-events: none !important;
        }
      ''');
    html.document.head?.append(styleEl);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasLoadError || !_isViewRegistered) {
      return const SizedBox.expand();
    }
    return HtmlElementView(viewType: viewId);
  }
}
