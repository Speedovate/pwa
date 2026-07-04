import 'dart:async';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/firebase_options.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/utils/data.dart';

class StartupService {
  static Future<void>? _firebaseInitFuture;
  static Future<void>? _prefsInitFuture;
  static Future<void>? _cameraWarmupFuture;

  static Future<void> waitForFirebaseReady() {
    _firebaseInitFuture ??= () async {
      try {
        await Firebase.initializeApp(
          options: kIsWeb
              ? DefaultFirebaseOptions.web
              : DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        if (Firebase.apps.isEmpty) {
          rethrow;
        }
      }
    }();
    return _firebaseInitFuture!;
  }

  static Future<void> ensureFirebaseReady({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return waitForFirebaseReady().timeout(
      timeout,
      onTimeout: () {},
    );
  }

  static Future<void> ensurePrefsReady() {
    _prefsInitFuture ??= () async {
      await StorageService.getPrefs();
    }();
    return _prefsInitFuture!;
  }

  static Future<void> warmUpCameras({
    Duration timeout = const Duration(seconds: 2),
  }) {
    if (kIsWeb) {
      return Future.value();
    }
    _cameraWarmupFuture ??= () async {
      try {
        cameras = await availableCameras().timeout(timeout);
      } catch (_) {
        cameras = null;
      }
    }();
    return _cameraWarmupFuture!;
  }
}
