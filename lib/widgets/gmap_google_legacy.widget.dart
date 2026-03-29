// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart' as gmaps;
import 'package:pwa/services/map.service.dart';
import 'package:pwa/utils/map_types.dart' as app_maps;

class GoogleMapWidget extends StatefulWidget {
  final app_maps.LatLng center;
  final bool enableGestures;
  final void Function(gmaps.Map map)? onMapCreated;
  final VoidCallback? onCameraMoveStart;
  final void Function(gmaps.LatLng)? onCameraMove;
  final VoidCallback? onLoadError;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.enableGestures = true,
    this.onMapCreated,
    this.onCameraMoveStart,
    this.onCameraMove,
    this.onLoadError,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  late final String viewId;
  gmaps.Map? _map;
  StreamSubscription? _dragStartSub;
  StreamSubscription? _idleSub;
  bool _mapInitialized = false;
  bool _isViewRegistered = false;
  bool _hasLoadError = false;

  static const List<Map<String, dynamic>> _defaultStyles = [
    {
      "featureType": "poi",
      "stylers": [
        {"visibility": "off"}
      ]
    },
    {
      "featureType": "transit",
      "stylers": [
        {"visibility": "off"}
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.icon",
      "stylers": [
        {"visibility": "off"}
      ]
    },
    {
      "featureType": "administrative",
      "stylers": [
        {"visibility": "off"}
      ]
    },
    {
      "featureType": "landscape",
      "stylers": [
        {"color": "#f2f2f2"}
      ]
    },
    {
      "featureType": "water",
      "stylers": [
        {"color": "#c9c9c9"}
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    viewId = 'map-div-${DateTime.now().microsecondsSinceEpoch}';
    _ensureHideGmapUiStyle();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      final ready = await MapService.ensureGoogleMapsReady();
      if (!ready) {
        _handleLoadError();
        return;
      }
      ui.platformViewRegistry.registerViewFactory(
        viewId,
        (int _) {
          final mapDiv = html.DivElement()
            ..id = viewId
            ..style.width = '100%'
            ..style.height = '100%';
          final mapOptions = gmaps.MapOptions()
            ..zoom = 16
            ..center = gmaps.LatLng(widget.center.lat, widget.center.lng)
            ..clickableIcons = false
            ..disableDefaultUI = true
            ..gestureHandling = widget.enableGestures ? 'greedy' : 'none'
            ..disableDoubleClickZoom = true
            ..mapTypeId = gmaps.MapTypeId.ROADMAP;
          _map = gmaps.Map(mapDiv as dynamic, mapOptions);
          js_util.setProperty(_map!, 'styles', _defaultStyles);
          widget.onMapCreated?.call(_map!);
          _dragStartSub = _map!.onDragstart.listen(
            (_) {
              if (!mounted) {
                return;
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                widget.onCameraMoveStart?.call();
              });
            },
          );
          _idleSub = _map!.onIdle.listen(
            (_) {
              final center = _map?.center;
              if (center == null || !mounted) {
                return;
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                widget.onCameraMove?.call(center);
              });
            },
          );
          _mapInitialized = true;
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
      if (oldWidget.enableGestures != widget.enableGestures) {
        js_util.setProperty(_map!, 'gestureHandling',
            widget.enableGestures ? 'greedy' : 'none');
      }
      if (!_latLngEquals(oldWidget.center, widget.center)) {
        _map!.panTo(gmaps.LatLng(widget.center.lat, widget.center.lng));
      }
    }
  }

  bool _latLngEquals(app_maps.LatLng a, app_maps.LatLng b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  @override
  void dispose() {
    _dragStartSub?.cancel();
    _idleSub?.cancel();
    super.dispose();
  }

   _ensureHideGmapUiStyle() {
    const styleId = 'gmap-hide-ui';
    if (html.document.getElementById(styleId) != null) return;
    final styleEl = html.StyleElement()
      ..id = styleId
      ..appendText('''
        .gm-style-cc,
        .gmnoprint,
        .gm-style a,
        .gm-style-mtc,
        .gm-fullscreen-control,
        .gm-svpc {
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
