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
  static const Duration _centerChangeIdleDuration =
      Duration(milliseconds: 180);
  late final String viewId;
  gmaps.Map? _map;
  StreamSubscription? _dragStartSub;
  StreamSubscription? _centerChangedSub;
  StreamSubscription? _idleSub;
  StreamSubscription<html.Event>? _mouseDownSub;
  StreamSubscription<html.Event>? _touchStartSub;
  StreamSubscription<html.Event>? _mouseUpSub;
  StreamSubscription<html.Event>? _touchEndSub;
  Timer? _centerIdleTimer;
  bool _mapInitialized = false;
  bool _isViewRegistered = false;
  bool _hasLoadError = false;
  bool _cameraMoveStartSent = false;
  bool _suppressCameraCallbacks = false;
  gmaps.LatLng? _latestCenter;

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
    MapService.debugLog('Legacy Google widget init: viewId=$viewId');
    _ensureHideGmapUiStyle();
    _initializeMap();
  }

  void _initializeMap() {
    () async {
      try {
        MapService.debugLog('Legacy Google widget waiting for Google Maps readiness');
        final ready = await MapService.ensureGoogleMapsReady();
        MapService.debugLog('Legacy Google widget readiness returned $ready');
        if (!ready) {
          _handleLoadError();
          return;
        }
        if (!mounted) {
          return;
        }
        MapService.debugLog('Legacy Google widget registering platform view');
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
                ..zoom = 16
                ..center = gmaps.LatLng(widget.center.lat, widget.center.lng)
                ..clickableIcons = false
                ..disableDefaultUI = true
                ..gestureHandling = widget.enableGestures ? 'greedy' : 'none'
                ..disableDoubleClickZoom = true
                ..mapTypeId = gmaps.MapTypeId.ROADMAP;
              _map = gmaps.Map(mapDiv as dynamic, mapOptions);
              MapService.debugLog('Legacy Google widget created gmaps.Map instance');
              js_util.setProperty(_map!, 'styles', _defaultStyles);
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
              _mapInitialized = true;
            } catch (error) {
              MapService.debugLog('Legacy Google widget map creation error: $error');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleLoadError();
              });
            }
            return mapDiv;
          },
        );
        _isViewRegistered = true;
        MapService.debugLog('Legacy Google widget platform view registered');
        if (mounted) {
          setState(() {});
        }
      } catch (error) {
        MapService.debugLog('Legacy Google widget initialize error: $error');
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
    _centerIdleTimer?.cancel();
    _centerIdleTimer = Timer(_centerChangeIdleDuration, () {
      _emitCameraMoveEnd(_latestCenter ?? _map?.center);
    });
  }

  void _emitCameraMoveEnd(gmaps.LatLng? center) {
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
    MapService.debugLog('Legacy Google widget handling load error');
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

  @override
  void dispose() {
    _centerIdleTimer?.cancel();
    _dragStartSub?.cancel();
    _centerChangedSub?.cancel();
    _idleSub?.cancel();
    _mouseDownSub?.cancel();
    _touchStartSub?.cancel();
    _mouseUpSub?.cancel();
    _touchEndSub?.cancel();
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
