import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/firebase_options.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const String _androidNotificationIcon = 'ic_notification';

const AndroidNotificationChannel _basicNotificationChannel =
    AndroidNotificationChannel(
  'basic_channel',
  'Basic Notifications',
  description: 'General customer notifications',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('sound'),
);

const AndroidNotificationChannel _bookingNotificationChannel =
    AndroidNotificationChannel(
  'booking_channel',
  'Booking Notifications',
  description: 'Ride and booking updates',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('alert'),
);
const String _basicDarwinNotificationSound = 'sound.wav';
const String _bookingDarwinNotificationSound = 'alert.wav';
const String _notifDebugTag = 'PPC_NOTIF_DEBUG';
const Duration _notificationDedupeWindow = Duration(minutes: 5);
final Map<String, DateTime> _shownNotificationKeys = {};

void _notifDebug(String message) {
  debugPrint('[$_notifDebugTag] $message');
}

String _notificationDedupeKey(RemoteMessage message) {
  final messageId = message.messageId?.trim();
  if (messageId != null && messageId.isNotEmpty) {
    return 'id:$messageId';
  }

  final orderedData = Map<String, dynamic>.fromEntries(
    message.data.entries.toList()
      ..sort(
        (left, right) => left.key.compareTo(right.key),
      ),
  );
  return 'payload:${jsonEncode(orderedData)}|'
      '${message.notification?.title ?? ''}|'
      '${message.notification?.body ?? ''}';
}

bool _shouldSkipDuplicateNotification(RemoteMessage message) {
  final now = DateTime.now();
  _shownNotificationKeys.removeWhere(
    (_, shownAt) => now.difference(shownAt) > _notificationDedupeWindow,
  );

  final key = _notificationDedupeKey(message);
  if (_shownNotificationKeys.containsKey(key)) {
    _notifDebug('local notification skipped duplicate key=$key');
    return true;
  }
  _shownNotificationKeys[key] = now;
  return false;
}

String? _notificationTitleFromMessage(RemoteMessage message) {
  final rawTitle = message.data['title'] ?? message.notification?.title;
  final title = '$rawTitle'.trim();
  if (title.isEmpty) {
    return null;
  }
  return _parseNotificationTitle(title);
}

String _parseNotificationTitle(String title) {
  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedTitle.contains('ride status update')) {
    return 'Booking Update';
  }
  return title;
}

String? _notificationBodyFromMessage(RemoteMessage message) {
  final rawBody = message.data['body'] ?? message.notification?.body;
  final body = '$rawBody'.trim();
  return body.isEmpty ? null : _parseNotificationBody(body);
}

String _parseNotificationBody(String body) {
  return body.replaceAll(
    RegExp(r'ride booking', caseSensitive: false),
    'booking',
  );
}

bool _isRideStatusUpdate(RemoteMessage message) {
  final explicitChannel =
      '${message.data['channel_id'] ?? message.data['channel'] ?? ''}'
          .trim()
          .toLowerCase();
  if (explicitChannel == _bookingNotificationChannel.id) {
    return true;
  }
  if (explicitChannel == _basicNotificationChannel.id) {
    return false;
  }

  final title = '${message.data['title'] ?? message.notification?.title ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return title.contains('ride status update');
}

@pragma('vm:entry-point')
void _handleLocalNotificationResponse(NotificationResponse response) {}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _notifDebug(
    'background handler start messageId=${message.messageId} data=${message.data}',
  );
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  await StorageService.getPrefs();
  await PushService.showLocalNotification(message);
  _notifDebug('background handler complete messageId=${message.messageId}');
}

class PushService {
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static bool _localNotificationsInitialized = false;
  static bool _hasRequestedRuntimePermissions = false;

  static Future<void> initialize() async {
    _notifDebug(
      'initialize start platform=$defaultTargetPlatform '
      'review=${AuthService.inReviewMode()} loggedIn=${AuthService.isLoggedIn()}',
    );
    await _ensureLocalNotificationsInitialized();
    await _configureForegroundPresentation();
    _attachForegroundListener();
    _attachOpenListener();
    _attachTokenRefreshListener();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    unawaited(
      _warmUpMobileMessaging().catchError((Object _) {}),
    );
    unawaited(
      syncTokenWithServer(requestPermission: false).catchError((Object _) {}),
    );
    _notifDebug('initialize complete');
  }

  static Future<void> _configureForegroundPresentation() async {
    if (kIsWeb) {
      return;
    }

    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _notifDebug('foreground presentation configured');
    } catch (_) {}
  }

  static Future<void> _warmUpMobileMessaging() async {
    if (kIsWeb) {
      return;
    }
    await _waitForAPNSToken();
    _notifDebug('warm up subscribe topic=all');
    await AuthService().subscribeToTopic('all');
  }

  static Future<void> requestNotificationPermissionsIfNeeded() async {
    if (_hasRequestedRuntimePermissions) {
      return;
    }
    _hasRequestedRuntimePermissions = true;
    _notifDebug('request runtime notification permissions');
    await _requestDevicePermissions();
    await syncTokenWithServer(forceSync: true);
  }

  static Future<void> syncTokenWithServer({
    bool requestPermission = false,
    bool forceSync = false,
  }) async {
    try {
      _notifDebug(
        'sync token start requestPermission=$requestPermission '
        'forceSync=$forceSync platform=$defaultTargetPlatform '
        'review=${AuthService.inReviewMode()} loggedIn=${AuthService.isLoggedIn()}',
      );
      if (requestPermission) {
        await _requestDevicePermissions();
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          _notifDebug('sync token stop missing APNs token');
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        _notifDebug('sync token stop missing FCM token');
        return;
      }

      fcmToken = token;
      _notifDebug('fcm token ready length=${token.length}');
      final topicSignature = _topicSignature();
      if (!forceSync && !_shouldSync(token, topicSignature)) {
        _notifDebug('sync token skipped unchanged topics=$topicSignature');
        return;
      }
      final syncedToServer = await subscribeToServer();
      if (!syncedToServer) {
        _notifDebug('sync token stop server subscribe failed');
        return;
      }
      await _rememberSyncedState(token, topicSignature);
      _notifDebug('sync token complete topics=$topicSignature');
    } catch (_) {
      _notifDebug('sync token failed');
      // Keep push sync non-blocking.
    }
  }

  static Future<String?> _waitForAPNSToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getAPNSToken();
        if (token != null && token.isNotEmpty) {
          _notifDebug(
              'apns token ready attempt=$attempt length=${token.length}');
          return token;
        }
      } catch (_) {}
      _notifDebug('apns token waiting attempt=$attempt');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    _notifDebug('apns token unavailable after retries');
    return null;
  }

  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings(_androidNotificationIcon);
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleLocalNotificationResponse,
    );

    final androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_basicNotificationChannel);
    await androidPlugin?.createNotificationChannel(_bookingNotificationChannel);

    _localNotificationsInitialized = true;
    _notifDebug('local notifications initialized');
  }

  static Future<void> _requestDevicePermissions() async {
    var permissionDialogShown = false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _notifDebug(
        'firebase permission status=${settings.authorizationStatus}',
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied &&
          !AuthService.inReviewMode()) {
        permissionDialogShown = true;
        showPermissionSettingsDialog(
          permissionName: "Notifications",
          reason: 'Please allow notifications in Settings so we can send '
              'booking updates and important alerts.',
        );
      }
    } catch (_) {}

    try {
      final iosPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _notifDebug('local iOS notification permissions requested');
    } catch (_) {}

    try {
      final macPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      await macPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _notifDebug('local macOS notification permissions requested');
    } catch (_) {}

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final statusBefore = await Permission.notification.status;
      _notifDebug('android notification status before=$statusBefore');
      if (statusBefore.isDenied) {
        final statusAfter = await Permission.notification.request();
        _notifDebug('android notification status after=$statusAfter');
        if (!statusAfter.isGranted &&
            !permissionDialogShown &&
            !AuthService.inReviewMode()) {
          permissionDialogShown = true;
          showPermissionSettingsDialog(
            permissionName: "Notifications",
            reason: 'Please allow notifications in Settings so we can send '
                'booking updates and important alerts.',
          );
        }
      } else if (!permissionDialogShown &&
          statusBefore.isPermanentlyDenied &&
          !AuthService.inReviewMode()) {
        permissionDialogShown = true;
        showPermissionSettingsDialog(
          permissionName: "Notifications",
          reason: 'Please allow notifications in Settings so we can send '
              'booking updates and important alerts.',
        );
      }
    } catch (_) {}
  }

  static void _attachForegroundListener() {
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        _notifDebug(
          'foreground message messageId=${message.messageId} data=${message.data}',
        );
        await showLocalNotification(message);
      },
      onError: (Object _) {},
    );
  }

  static void _attachOpenListener() {
    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        _notifDebug(
          'notification opened messageId=${message.messageId} data=${message.data}',
        );
      },
      onError: (Object _) {},
    );
  }

  static void _attachTokenRefreshListener() {
    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        if (token.isEmpty) {
          _notifDebug('token refresh empty token');
          return;
        }
        _notifDebug('token refresh length=${token.length}');
        fcmToken = token;
        await syncTokenWithServer(forceSync: true);
      },
      onError: (Object _) {},
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    await _ensureLocalNotificationsInitialized();

    try {
      if (_shouldSkipDuplicateNotification(message)) {
        return;
      }

      final title = _notificationTitleFromMessage(message);
      final body = _notificationBodyFromMessage(message);
      if (title == null && body == null) {
        _notifDebug(
          'local notification skipped empty title/body messageId=${message.messageId}',
        );
        return;
      }

      final channel = _isRideStatusUpdate(message)
          ? _bookingNotificationChannel
          : _basicNotificationChannel;
      _notifDebug(
        'show local notification messageId=${message.messageId} '
        'channel=${channel.id} title=$title body=$body data=${message.data}',
      );

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        color: const Color(0xFF007BFF),
        icon: _androidNotificationIcon,
        sound: channel.sound,
        ticker: title,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
      );
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        sound: channel.id == _bookingNotificationChannel.id
            ? _bookingDarwinNotificationSound
            : _basicDarwinNotificationSound,
      );

      await _flutterLocalNotificationsPlugin.show(
        Random().nextInt(1000000),
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: jsonEncode(message.data),
      );
      _notifDebug('local notification shown channel=${channel.id}');
    } catch (_) {
      _notifDebug('local notification failed');
      // Foreground/background notification rendering is best-effort only.
    }
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
