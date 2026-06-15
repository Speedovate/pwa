// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  static void _notifDebug(String message) {
    debugPrint(
        '[PPC_NOTIF_DEBUG] ${DateTime.now().toIso8601String()} $message');
  }

  static String _cleanNotificationText(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static String _parseNotificationBody(String body) {
    final parsed = body.replaceAll(
      RegExp(r'ride booking', caseSensitive: false),
      'booking',
    );
    _notifDebug('web parse body raw=$body parsed=$parsed');
    return parsed;
  }

  static String _parseNotificationTitle(String title) {
    final normalizedTitle =
        title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedTitle.contains('ride status update')) {
      _notifDebug('web parse title matched ride status update raw=$title');
      return 'Booking Update';
    }
    _notifDebug('web parse title unchanged raw=$title');
    return title.trim();
  }

  static Future<void> initialize() async {
    _notifDebug(
      'web initialize start supported=${isWebPushLikelySupported()} '
      'loggedIn=${AuthService.isLoggedIn()} review=${AuthService.inReviewMode()}',
    );
    if (!isWebPushLikelySupported()) {
      _notifDebug('web initialize skipped unsupported');
      return;
    }
    await _registerServiceWorker();
    _attachForegroundListener();
    _attachTokenRefreshListener();
    await syncTokenWithServer(requestPermission: false);
    _notifDebug('web initialize complete');
  }

  static Future<void> requestNotificationPermissionsIfNeeded() async {
    _notifDebug(
      'web request permission start supported=${isWebPushLikelySupported()}',
    );
    if (!isWebPushLikelySupported()) {
      _notifDebug('web request permission skipped unsupported');
      return;
    }
    await syncTokenWithServer(
      requestPermission: true,
      forceSync: true,
    );
  }

  static Future<void> syncTokenWithServer({
    bool requestPermission = false,
    bool forceSync = false,
  }) async {
    if (!isWebPushLikelySupported()) {
      _notifDebug('web sync token skipped unsupported');
      return;
    }
    try {
      _notifDebug(
        'web sync token start requestPermission=$requestPermission '
        'forceSync=$forceSync loggedIn=${AuthService.isLoggedIn()}',
      );
      final permission = await _resolvePermission(
        requestPermission: requestPermission,
      );
      _notifDebug('web notification permission=$permission');
      if (permission != 'granted') {
        _notifDebug('web sync token stop permission=$permission');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _vapidKey,
      );
      if (token == null || token.isEmpty) {
        _notifDebug('web sync token stop missing fcm token');
        return;
      }

      fcmToken = token;
      _notifDebug('web fcm token ready length=${token.length}');
      final topicSignature = _topicSignature();
      if (!forceSync && !_shouldSync(token, topicSignature)) {
        _notifDebug('web sync token skipped unchanged topics=$topicSignature');
        return;
      }
      _notifDebug('web sync token will subscribe topics=$topicSignature');
      final syncedToServer = await subscribeToServer();
      if (!syncedToServer) {
        _notifDebug('web sync token stop server subscribe failed');
        return;
      }
      await _rememberSyncedState(token, topicSignature);
      _notifDebug('web sync token complete topics=$topicSignature');
    } catch (e) {
      _notifDebug('web sync token failed error=$e');
      // Keep web push sync non-blocking.
    }
  }

  static void _attachForegroundListener() {
    _notifDebug(
        'web foreground listener attaching existing=${_messageSubscription != null}');
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        _notifDebug(
          'web receive foreground messageId=${message.messageId} '
          'sentTime=${message.sentTime} data=${message.data}',
        );
        final rawTitle = _cleanNotificationText(
          message.data['title'] ?? message.notification?.title,
        );
        final title = _parseNotificationTitle(rawTitle);
        final rawBody = _cleanNotificationText(
          message.data['body'] ?? message.notification?.body,
        );
        final body = _parseNotificationBody(rawBody);
        _notifDebug(
          'web parse result messageId=${message.messageId} '
          'title=$title body=$body',
        );
        if (title.isEmpty && body.isEmpty) {
          _notifDebug('web notification skipped empty title/body');
          return;
        }
        _notifDebug('web create notification title=$title body=$body');
        html.Notification(
          title,
          body: body,
          icon: '/icons/webiconsmall.png',
        );
      },
    );
  }

  static void _attachTokenRefreshListener() {
    _notifDebug(
      'web token refresh listener attaching existing=${_tokenRefreshSubscription != null}',
    );
    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        if (token.isEmpty) {
          _notifDebug('web token refresh empty token');
          return;
        }
        _notifDebug('web token refresh length=${token.length}');
        fcmToken = token;
        await syncTokenWithServer(forceSync: true);
      },
      onError: (Object error) {
        _notifDebug('web token refresh listener error=$error');
        // Token refresh failures are ignored until next sync attempt.
      },
    );
  }

  static Future<void> _registerServiceWorker() async {
    if (!isWebPushLikelySupported()) {
      _notifDebug('web service worker register skipped unsupported');
      return;
    }
    if (html.window.navigator.serviceWorker == null) {
      _notifDebug('web service worker register skipped unavailable');
      return;
    }
    try {
      await html.window.navigator.serviceWorker!.register(_serviceWorkerPath);
      _notifDebug('web service worker registered path=$_serviceWorkerPath');
    } catch (e) {
      _notifDebug('web service worker register failed error=$e');
      // Service worker registration is best-effort only.
    }
  }

  static Future<String> _resolvePermission({
    required bool requestPermission,
  }) async {
    final current = html.Notification.permission ?? 'default';
    _notifDebug(
      'web resolve permission current=$current requestPermission=$requestPermission',
    );
    if (!requestPermission || current == 'granted' || current == 'denied') {
      return current;
    }
    final requested = await html.Notification.requestPermission();
    _notifDebug('web requested permission result=$requested');
    return requested;
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
}
