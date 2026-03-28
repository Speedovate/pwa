// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';

class PushService {
  static const String _serviceWorkerPath = '/firebase-messaging-sw.js';
  static const String _vapidKey =
      'BCJv0HXIqVrKjbGIYEjbhOgE1T7oct4lEnki_gN6cOKE36THwLL7k_RK4vf_saUkLPp2g-pL9bsCyAyIZnCG86Q';

  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> initialize() async {
    if (!isWebPushLikelySupported()) {
      debugPrint('Skipping web push initialization on unsupported browser');
      return;
    }
    await _registerServiceWorker();
    _attachForegroundListener();
    _attachTokenRefreshListener();
    await syncTokenWithServer(requestPermission: false);
  }

  static Future<void> syncTokenWithServer({
    bool requestPermission = false,
    bool forceSync = false,
  }) async {
    if (!isWebPushLikelySupported()) {
      debugPrint('Skipping web push sync on unsupported browser');
      return;
    }
    try {
      final permission = await _resolvePermission(
        requestPermission: requestPermission,
      );
      if (permission != 'granted') {
        debugPrint('Web push permission not granted');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _vapidKey,
      );
      if (token == null || token.isEmpty) {
        debugPrint('Web FCM token unavailable');
        return;
      }

      fcmToken = token;
      final topicSignature = _topicSignature();
      if (!forceSync && !_shouldSync(token, topicSignature)) {
        debugPrint('Skipping FCM sync: token and topics unchanged');
        return;
      }

      debugPrint('Web FCM token ready: ${_redactToken(token)}');
      await subscribeToServer();
      await _rememberSyncedState(token, topicSignature);
    } catch (e) {
      debugPrint('Web Push setup failed: $e');
    }
  }

  static void _attachForegroundListener() {
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        html.Notification(
          message.data['title'] ?? message.notification?.title ?? '',
          body: message.data['body'] ?? message.notification?.body ?? '',
          icon: '/icons/webiconsmall.png',
        );
      },
    );
  }

  static void _attachTokenRefreshListener() {
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen(
      (String token) async {
        if (token.isEmpty) {
          return;
        }
        fcmToken = token;
        debugPrint('Web FCM token refreshed');
        await syncTokenWithServer(forceSync: true);
      },
      onError: (Object error) {
        debugPrint('Web FCM token refresh failed: $error');
      },
    );
  }

  static Future<void> _registerServiceWorker() async {
    if (!isWebPushLikelySupported()) {
      return;
    }
    if (html.window.navigator.serviceWorker == null) {
      return;
    }
    try {
      await html.window.navigator.serviceWorker!.register(_serviceWorkerPath);
    } catch (e) {
      debugPrint('Service worker registration failed: $e');
    }
  }

  static Future<String> _resolvePermission({
    required bool requestPermission,
  }) async {
    final current = html.Notification.permission ?? 'default';
    if (!requestPermission || current == 'granted' || current == 'denied') {
      return current;
    }
    return await html.Notification.requestPermission();
  }

  static bool _shouldSync(String token, String topicSignature) {
    final prefs = StorageService.prefs;
    final lastToken = prefs?.getString(AppStrings.lastPushToken);
    final lastTopics = prefs?.getString(AppStrings.lastPushTopicSignature);
    return lastToken != token || lastTopics != topicSignature;
  }

  static Future<void> _rememberSyncedState(
    String token,
    String topicSignature,
  ) async {
    await StorageService.prefs?.setString(AppStrings.lastPushToken, token);
    await StorageService.prefs?.setString(
      AppStrings.lastPushTopicSignature,
      topicSignature,
    );
  }

  static String _topicSignature() {
    final topics = AuthService.isLoggedIn()
        ? (StorageService.prefs?.getStringList('topics') ?? [])
        : <String>['all'];
    final normalized = [...topics]..sort();
    return normalized.join(',');
  }

  static String _redactToken(String token) {
    if (token.length <= 12) {
      return token;
    }
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}
