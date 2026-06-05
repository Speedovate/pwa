// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:pwa/utils/browser_utils.dart';

class MapService {
  static Future<bool>? _googleMapsReadyFuture;
  static bool get _isHuaweiBrowser => isHuaweiLikeBrowser();
  static bool get shouldAttemptGoogleMaps => !_isHuaweiBrowser;
  static bool get isLeafletFallbackPreferred => !shouldAttemptGoogleMaps;

  static void debugLog(String message) {
  }

  static bool? get initialEngineDecision {
    if (isGoogleMapsLoaded) {
      return true;
    }
    if (_isHuaweiBrowser) {
      return false;
    }
    return null;
  }

  static bool get isGoogleMapsLoaded {
    try {
      final google = globalContext.getProperty<JSObject?>('google'.toJS);
      return google != null && google.hasProperty('maps'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureGoogleMapsReady() async {
    if (_googleMapsReadyFuture != null) {
      debugLog('Reusing existing Google Maps readiness future');
      return _googleMapsReadyFuture!;
    }
    if (!shouldAttemptGoogleMaps) {
      debugLog('Skipping Google Maps readiness because browser is Huawei-like');
      return Future<bool>.value(false);
    }
    if (isGoogleMapsLoaded) {
      debugLog('Google Maps JS already loaded');
      return Future<bool>.value(true);
    }

    final existing = html.document.getElementById('google-maps-js');
    if (existing is! html.ScriptElement) {
      debugLog('Google Maps script tag missing in index.html');
      return Future<bool>.value(false);
    }

    debugLog('Waiting for preloaded Google Maps script');
    final completer = Completer<bool>();
    _googleMapsReadyFuture = completer.future;

    existing.onLoad.first.then((_) {
      debugLog('Preloaded Google Maps script loaded');
      if (!completer.isCompleted) {
        completer.complete(isGoogleMapsLoaded);
      }
    }).catchError((Object error) {
      debugLog('Preloaded Google Maps script load future error: $error');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    existing.onError.first.then((_) {
      if (!completer.isCompleted) {
        debugLog('Preloaded Google Maps script emitted error');
        completer.complete(false);
      }
    });

    Future<void>(() async {
      for (var attempt = 0; attempt < 60 && !completer.isCompleted; attempt++) {
        if (isGoogleMapsLoaded) {
          debugLog('Google Maps JS became ready while waiting');
          completer.complete(true);
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!completer.isCompleted) {
        debugLog('Timed out waiting for preloaded Google Maps script');
        completer.complete(false);
      }
    });

    return _googleMapsReadyFuture!;
  }

  static Future<void> warmUpPreferredMapEngine() async {
    await ensureGoogleMapsReady();
  }
}
