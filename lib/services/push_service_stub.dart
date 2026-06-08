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
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
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
    } catch (_) {}
  }

  static Future<void> _warmUpMobileMessaging() async {
    if (kIsWeb) {
      return;
    }
    try {
      await FirebaseMessaging.instance.getAPNSToken();
    } catch (_) {}
    await AuthService().subscribeToTopic('all');
  }

  static Future<void> requestNotificationPermissionsIfNeeded() async {
    if (_hasRequestedRuntimePermissions) {
      return;
    }
    _hasRequestedRuntimePermissions = true;
    await _requestDevicePermissions();
    await syncTokenWithServer(forceSync: true);
  }

  static Future<void> syncTokenWithServer({
    bool requestPermission = false,
    bool forceSync = false,
  }) async {
    try {
      if (requestPermission) {
        await _requestDevicePermissions();
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await FirebaseMessaging.instance.getAPNSToken();
        } catch (_) {}
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      fcmToken = token;
      final topicSignature = _topicSignature();
      if (!forceSync && !_shouldSync(token, topicSignature)) {
        return;
      }
      await subscribeToServer();
      await _rememberSyncedState(token, topicSignature);
    } catch (_) {
      // Keep push sync non-blocking.
    }
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
    } catch (_) {}

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final statusBefore = await Permission.notification.status;
      if (statusBefore.isDenied) {
        final statusAfter = await Permission.notification.request();
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
        await showLocalNotification(message);
      },
      onError: (Object _) {},
    );
  }

  static void _attachOpenListener() {
    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {},
      onError: (Object _) {},
    );
  }

  static void _attachTokenRefreshListener() {
    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        if (token.isEmpty) {
          return;
        }
        fcmToken = token;
        await syncTokenWithServer(forceSync: true);
      },
      onError: (Object _) {},
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    await _ensureLocalNotificationsInitialized();

    try {
      final title = _notificationTitleFromMessage(message);
      final body = _notificationBodyFromMessage(message);
      if (title == null && body == null) {
        return;
      }

      final channel = _isRideStatusUpdate(message)
          ? _bookingNotificationChannel
          : _basicNotificationChannel;

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
    } catch (_) {
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
