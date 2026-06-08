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
      return _googleMapsReadyFuture!;
    }
    if (!shouldAttemptGoogleMaps) {
      return Future<bool>.value(false);
    }
    if (isGoogleMapsLoaded) {
      return Future<bool>.value(true);
    }

    final existing = html.document.getElementById('google-maps-js');
    if (existing is! html.ScriptElement) {
      return Future<bool>.value(false);
    }

    final completer = Completer<bool>();
    _googleMapsReadyFuture = completer.future;

    existing.onLoad.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(isGoogleMapsLoaded);
      }
    }).catchError((Object error) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    existing.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    Future<void>(() async {
      for (var attempt = 0; attempt < 60 && !completer.isCompleted; attempt++) {
        if (isGoogleMapsLoaded) {
          completer.complete(true);
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return _googleMapsReadyFuture!;
  }

  static Future<void> warmUpPreferredMapEngine() async {
    await ensureGoogleMapsReady();
  }
}
