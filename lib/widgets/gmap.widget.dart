// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:pwa/view_models/home.vm.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

class GoogleMapWidget extends StatefulWidget {
  final gmaps.LatLng center;
  final HomeViewModel viewModel;
  final bool enableGestures;

  const GoogleMapWidget({
    super.key,
    required this.center,
    required this.viewModel,
    this.enableGestures = true,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  late final String viewId;
  gmaps.Map? _map;

  @override
  void initState() {
    super.initState();
    viewId = 'map-div-${DateTime.now().microsecondsSinceEpoch}';
    _ensureHideGmapUiStyle();
    ui.platformViewRegistry.registerViewFactory(viewId, (int _) {
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

      final styles = [
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

      js_util.setProperty(_map!, 'styles', styles);
      widget.viewModel.setMap(_map!);

      return mapDiv;
    });
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableGestures != widget.enableGestures && _map != null) {
      js_util.setProperty(
          _map!, 'gestureHandling', widget.enableGestures ? 'greedy' : 'none');
    }
  }

  void _ensureHideGmapUiStyle() {
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
