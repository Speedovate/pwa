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

String? _notificationTitleFromMessage(RemoteMessage message) {
  final rawTitle = message.data['title'] ?? message.notification?.title;
  final title = '$rawTitle'.trim();
  return title.isEmpty ? null : title;
}

String? _notificationBodyFromMessage(RemoteMessage message) {
  final rawBody = message.data['body'] ?? message.notification?.body;
  final body = '$rawBody'.trim();
  return body.isEmpty ? null : body;
}

bool _isRideStatusUpdate(RemoteMessage message) {
  final explicitChannel = '${message.data['channel_id'] ?? message.data['channel'] ?? ''}'
      .trim()
      .toLowerCase();
  if (explicitChannel == _bookingNotificationChannel.id) {
    return true;
  }
  if (explicitChannel == _basicNotificationChannel.id) {
    return false;
  }

  final title = (_notificationTitleFromMessage(message) ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return title.contains('ride status update');
}

@pragma('vm:entry-point')
void _handleLocalNotificationResponse(NotificationResponse response) {}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[PushDebug][BG:start] messageId=${message.messageId} data=${message.data} title=${message.notification?.title} body=${message.notification?.body}',
  );
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[PushDebug][BG:firebaseInit:error] $e');
  }
  await StorageService.getPrefs();
  await PushService.showLocalNotification(message);
}

class PushService {
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static bool _localNotificationsInitialized = false;
  static bool _hasRequestedRuntimePermissions = false;

  static Future<void> initialize() async {
    debugPrint('[PushDebug][Init:start]');
    await _ensureLocalNotificationsInitialized();
    await _warmUpMobileMessaging();
    _attachForegroundListener();
    _attachOpenListener();
    _attachTokenRefreshListener();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await syncTokenWithServer(requestPermission: false);
    debugPrint('[PushDebug][Init:done]');
  }

  static Future<void> _warmUpMobileMessaging() async {
    if (kIsWeb) {
      return;
    }
    try {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      debugPrint('[PushDebug][Warmup:apns] token=$apnsToken');
    } catch (e) {
      debugPrint('[PushDebug][Warmup:apns:error] $e');
    }
    debugPrint('[PushDebug][Warmup:subscribeAll:start]');
    await AuthService().subscribeToTopic('all');
    debugPrint('[PushDebug][Warmup:subscribeAll:done]');
  }

  static Future<void> requestNotificationPermissionsIfNeeded() async {
    if (_hasRequestedRuntimePermissions) {
      debugPrint('[PushDebug][Permissions:skip] already-requested');
      return;
    }
    _hasRequestedRuntimePermissions = true;
    debugPrint('[PushDebug][Permissions:start]');
    await _requestDevicePermissions();
    await syncTokenWithServer(forceSync: true);
    debugPrint('[PushDebug][Permissions:done]');
  }

  static Future<void> syncTokenWithServer({
    bool requestPermission = false,
    bool forceSync = false,
  }) async {
    try {
      debugPrint(
        '[PushDebug][TokenSync:start] requestPermission=$requestPermission forceSync=$forceSync',
      );
      if (requestPermission) {
        await _requestDevicePermissions();
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          debugPrint('[PushDebug][TokenSync:apns] token=$apnsToken');
        } catch (e) {
          debugPrint('[PushDebug][TokenSync:apns:error] $e');
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PushDebug][TokenSync:no-token]');
        return;
      }

      fcmToken = token;
      final topicSignature = _topicSignature();
      debugPrint(
        '[PushDebug][TokenSync:token] token=$token topics=$topicSignature',
      );
      if (!forceSync && !_shouldSync(token, topicSignature)) {
        debugPrint('[PushDebug][TokenSync:skip] unchanged');
        return;
      }
      await subscribeToServer();
      await _rememberSyncedState(token, topicSignature);
      debugPrint('[PushDebug][TokenSync:done]');
    } catch (e) {
      debugPrint('[PushDebug][TokenSync:error] $e');
      // Keep push sync non-blocking.
    }
  }

  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) {
      debugPrint('[PushDebug][LocalNotif:init:skip] already-initialized');
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
    debugPrint('[PushDebug][LocalNotif:init:plugin-ready]');

    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_basicNotificationChannel);
    await androidPlugin?.createNotificationChannel(_bookingNotificationChannel);
    debugPrint(
      '[PushDebug][LocalNotif:channels] created=${_basicNotificationChannel.id},${_bookingNotificationChannel.id}',
    );

    _localNotificationsInitialized = true;
  }

  static Future<void> _requestDevicePermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        '[PushDebug][Permissions:fcm] auth=${settings.authorizationStatus} alert=${settings.alert} badge=${settings.badge} sound=${settings.sound}',
      );
    } catch (e) {
      debugPrint('[PushDebug][Permissions:fcm:error] $e');
    }

    try {
      final iosPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[PushDebug][Permissions:ios-local] granted=$granted');
    } catch (e) {
      debugPrint('[PushDebug][Permissions:ios-local:error] $e');
    }

    try {
      final macPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      final granted = await macPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[PushDebug][Permissions:mac-local] granted=$granted');
    } catch (e) {
      debugPrint('[PushDebug][Permissions:mac-local:error] $e');
    }

    try {
      final statusBefore = await Permission.notification.status;
      debugPrint('[PushDebug][Permissions:android-before] $statusBefore');
      if (statusBefore.isDenied) {
        final statusAfter = await Permission.notification.request();
        debugPrint('[PushDebug][Permissions:android-after] $statusAfter');
      }
    } catch (e) {
      debugPrint('[PushDebug][Permissions:android:error] $e');
    }
  }

  static void _attachForegroundListener() {
    debugPrint('[PushDebug][Listener:foreground:attach]');
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        debugPrint(
          '[PushDebug][FG:message] messageId=${message.messageId} data=${message.data} title=${message.notification?.title} body=${message.notification?.body}',
        );
        await showLocalNotification(message);
      },
      onError: (Object error) {
        debugPrint('[PushDebug][FG:message:error] $error');
      },
    );
  }

  static void _attachOpenListener() {
    debugPrint('[PushDebug][Listener:open:attach]');
    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        debugPrint('Notification opened: ${message.data}');
      },
      onError: (Object error) {
        debugPrint('[PushDebug][Open:error] $error');
      },
    );
  }

  static void _attachTokenRefreshListener() {
    debugPrint('[PushDebug][Listener:token-refresh:attach]');
    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        if (token.isEmpty) {
          debugPrint('[PushDebug][TokenRefresh:empty]');
          return;
        }
        debugPrint('[PushDebug][TokenRefresh:value] token=$token');
        fcmToken = token;
        await syncTokenWithServer(forceSync: true);
      },
      onError: (Object error) {
        debugPrint('[PushDebug][TokenRefresh:error] $error');
      },
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    await _ensureLocalNotificationsInitialized();

    try {
      final title = _notificationTitleFromMessage(message);
      final body = _notificationBodyFromMessage(message);
      if (title == null && body == null) {
        debugPrint('[PushDebug][LocalNotif:skip] empty title/body');
        return;
      }

      final channel = _isRideStatusUpdate(message)
          ? _bookingNotificationChannel
          : _basicNotificationChannel;
      debugPrint(
        '[PushDebug][LocalNotif:show] channel=${channel.id} title=$title body=$body data=${message.data}',
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
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
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
      debugPrint('[PushDebug][LocalNotif:shown]');
    } catch (e) {
      debugPrint('[PushDebug][LocalNotif:error] $e');
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
