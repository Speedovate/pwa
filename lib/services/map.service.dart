// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/utils/functions.dart';

class MapService {
  static Future<bool>? _googleMapsReadyFuture;
  static bool get _isIOSBrowser => isIOSLikeBrowser();
  static bool get _hasGoogleMapsApiKey =>
      AppStrings.googleMapApiKey.trim().isNotEmpty;
  static bool get _hasLoadedAppSettings => AppStrings.appSettingsObject != null;

  static bool get shouldUseGoogleMapsByDefault =>
      !_isIOSBrowser && _hasGoogleMapsApiKey;

  static bool get isLeafletFallbackPreferred => !shouldUseGoogleMapsByDefault;

  static bool? get initialEngineDecision {
    if (isGoogleMapsLoaded) {
      return true;
    }
    if (_isIOSBrowser) {
      return false;
    }
    if (!_hasLoadedAppSettings) {
      return null;
    }
    if (!_hasGoogleMapsApiKey) {
      return false;
    }
    return null;
  }

  static bool get isGoogleMapsLoaded {
    try {
      final google = js_util.getProperty(html.window, 'google');
      return google != null && js_util.hasProperty(google, 'maps');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureGoogleMapsReady() async {
    await AppStrings.getAppSettingsFromStorage();
    if (_googleMapsReadyFuture != null) {
      return _googleMapsReadyFuture!;
    }
    if (!shouldUseGoogleMapsByDefault) {
      return Future<bool>.value(false);
    }
    if (isGoogleMapsLoaded) {
      return Future<bool>.value(true);
    }

    final completer = Completer<bool>();
    _googleMapsReadyFuture = completer.future;

    final existing = html.document.getElementById('google-maps-js');
    if (existing is html.ScriptElement) {
      if (isGoogleMapsLoaded) {
        completer.complete(true);
      } else {
        existing.onLoad.first.then((_) {
          completer.complete(isGoogleMapsLoaded);
        }).catchError((_) {
          completer.complete(false);
        });
        existing.onError.first.then((_) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });
      }
      return _googleMapsReadyFuture!;
    }

    final script = html.ScriptElement()
      ..id = 'google-maps-js'
      ..async = true
      ..defer = true
      ..src =
          'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(AppStrings.googleMapApiKey)}';

    script.onLoad.first.then((_) {
      completer.complete(isGoogleMapsLoaded);
    }).catchError((Object error) {
      debugPrint('Google Maps script load error: $error');
      completer.complete(false);
    });
    script.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    html.document.head?.append(script);
    return _googleMapsReadyFuture!;
  }

  static Future<void> warmUpPreferredMapEngine() async {
    await AppStrings.getAppSettingsFromStorage();
    await ensureGoogleMapsReady();
  }
}
