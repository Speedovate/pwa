// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GoogleMapWidget extends StatefulWidget {
  final gmaps.LatLng center;
  final bool enableGestures;
  final void Function(gmaps.Map map)? onMapCreated;
  final void Function(gmaps.LatLng)? onCameraMove;

  const GoogleMapWidget({
    super.key,
    required this.center,
    this.enableGestures = true,
    this.onMapCreated,
    this.onCameraMove,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  late final String viewId;
  gmaps.Map? _map;
  StreamSubscription? _centerChangedSub;
  bool _mapInitialized = false;

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
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int _) {
        final mapDiv = html.DivElement()
          ..id = viewId
          ..style.width = '100%'
          ..style.height = '100%';
        final mapOptions = gmaps.MapOptions()
          ..zoom = 16
          ..center = widget.center
          ..clickableIcons = false
          ..disableDefaultUI = true
          ..gestureHandling = widget.enableGestures ? 'greedy' : 'none'
          ..disableDoubleClickZoom = true
          ..mapTypeId = gmaps.MapTypeId.ROADMAP;
        _map = gmaps.Map(mapDiv as dynamic, mapOptions);
        js_util.setProperty(_map!, 'styles', _defaultStyles);
        widget.onMapCreated?.call(_map!);
        _centerChangedSub = _map!.onCenterChanged.listen(
          (_) {
            final center = _map?.center;
            if (center != null && mounted) widget.onCameraMove?.call(center);
          },
        );
        _mapInitialized = true;
        return mapDiv;
      },
    );
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
        _map!.panTo(widget.center);
      }
    }
  }

  bool _latLngEquals(gmaps.LatLng a, gmaps.LatLng b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  @override
  void dispose() {
    _centerChangedSub?.cancel();
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
    return HtmlElementView(viewType: viewId);
  }
}
