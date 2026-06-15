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
  debugPrint('[$_notifDebugTag] ${DateTime.now().toIso8601String()} $message');
}

String _cleanNotificationText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.toLowerCase() == 'null' ? '' : text;
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
  _notifDebug('dedupe check key=$key cached=${_shownNotificationKeys.length}');
  if (_shownNotificationKeys.containsKey(key)) {
    _notifDebug('local notification skipped duplicate key=$key');
    return true;
  }
  _shownNotificationKeys[key] = now;
  return false;
}

String? _notificationTitleFromMessage(RemoteMessage message) {
  final title = _cleanNotificationText(
    message.data['title'] ?? message.notification?.title,
  );
  _notifDebug(
    'title resolve rawData=${message.data['title']} '
    'rawNotification=${message.notification?.title} cleaned=$title',
  );
  if (title.isEmpty) {
    return null;
  }
  return _parseNotificationTitle(title);
}

String _parseNotificationTitle(String title) {
  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedTitle.contains('ride status update')) {
    _notifDebug('parse title matched ride status update raw=$title');
    return 'Booking Update';
  }
  _notifDebug('parse title unchanged raw=$title');
  return title;
}

String? _notificationBodyFromMessage(RemoteMessage message) {
  final body = _cleanNotificationText(
    message.data['body'] ?? message.notification?.body,
  );
  _notifDebug(
    'body resolve rawData=${message.data['body']} '
    'rawNotification=${message.notification?.body} cleaned=$body',
  );
  return body.isEmpty ? null : _parseNotificationBody(body);
}

String _parseNotificationBody(String body) {
  final parsed = body.replaceAll(
    RegExp(r'ride booking', caseSensitive: false),
    'booking',
  );
  _notifDebug('parse body raw=$body parsed=$parsed');
  return parsed;
}

bool _isRideStatusUpdate(RemoteMessage message) {
  final explicitChannel =
      '${message.data['channel_id'] ?? message.data['channel'] ?? ''}'
          .trim()
          .toLowerCase();
  _notifDebug(
    'channel resolve explicit=$explicitChannel '
    'rawTitle=${message.data['title'] ?? message.notification?.title}',
  );
  if (explicitChannel == _bookingNotificationChannel.id) {
    _notifDebug('channel decision booking explicit');
    return true;
  }
  if (explicitChannel == _basicNotificationChannel.id) {
    _notifDebug('channel decision basic explicit');
    return false;
  }

  final title = '${message.data['title'] ?? message.notification?.title ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final isBooking = title.contains('ride status update');
  _notifDebug(
      'channel decision titleFallback=$isBooking normalizedTitle=$title');
  return isBooking;
}

@pragma('vm:entry-point')
void _handleLocalNotificationResponse(NotificationResponse response) {}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _notifDebug(
    'receive background messageId=${message.messageId} '
    'sentTime=${message.sentTime} ttl=${message.ttl} '
    'category=${message.category} collapseKey=${message.collapseKey} '
    'data=${message.data}',
  );
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _notifDebug('background firebase initialized');
  } catch (e) {
    _notifDebug('background firebase init ignored error=$e');
  }
  await StorageService.getPrefs();
  _notifDebug('background prefs ready');
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
    _notifDebug('background handler attaching');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    unawaited(
      _warmUpMobileMessaging().catchError((Object error) {
        _notifDebug('warm up failed error=$error');
      }),
    );
    unawaited(
      syncTokenWithServer(requestPermission: false).catchError((Object error) {
        _notifDebug('initial sync failed error=$error');
      }),
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
    _notifDebug('warm up start');
    await _waitForAPNSToken();
    _notifDebug('warm up subscribe topic=all');
    await AuthService().subscribeToTopic('all');
    _notifDebug('warm up complete');
  }

  static Future<void> requestNotificationPermissionsIfNeeded() async {
    if (_hasRequestedRuntimePermissions) {
      _notifDebug('request runtime notification permissions skipped already');
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
      _notifDebug('sync token will subscribe topics=$topicSignature');
      final syncedToServer = await subscribeToServer();
      if (!syncedToServer) {
        _notifDebug('sync token stop server subscribe failed');
        return;
      }
      await _rememberSyncedState(token, topicSignature);
      _notifDebug('sync token complete topics=$topicSignature');
    } catch (e) {
      _notifDebug('sync token failed error=$e');
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
      } catch (e) {
        _notifDebug('apns token attempt error attempt=$attempt error=$e');
      }
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

    _notifDebug('local notifications init start');
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
    _notifDebug(
        'android basic channel ensured id=${_basicNotificationChannel.id}');
    await androidPlugin?.createNotificationChannel(_bookingNotificationChannel);
    _notifDebug(
      'android booking channel ensured id=${_bookingNotificationChannel.id}',
    );

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
    } catch (e) {
      _notifDebug('firebase permission request error=$e');
    }

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
    } catch (e) {
      _notifDebug('local iOS notification permissions error=$e');
    }

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
    } catch (e) {
      _notifDebug('local macOS notification permissions error=$e');
    }

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
    } catch (e) {
      _notifDebug('android notification permission error=$e');
    }
  }

  static void _attachForegroundListener() {
    _notifDebug(
        'foreground listener attaching existing=${_messageSubscription != null}');
    _messageSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        _notifDebug(
          'receive foreground messageId=${message.messageId} '
          'sentTime=${message.sentTime} ttl=${message.ttl} '
          'category=${message.category} collapseKey=${message.collapseKey} '
          'data=${message.data}',
        );
        await showLocalNotification(message);
      },
      onError: (Object error) {
        _notifDebug('foreground listener error=$error');
      },
    );
  }

  static void _attachOpenListener() {
    _notifDebug(
        'open listener attaching existing=${_messageOpenedSubscription != null}');
    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        _notifDebug(
          'notification opened messageId=${message.messageId} '
          'sentTime=${message.sentTime} data=${message.data}',
        );
      },
      onError: (Object error) {
        _notifDebug('open listener error=$error');
      },
    );
  }

  static void _attachTokenRefreshListener() {
    _notifDebug(
      'token refresh listener attaching existing=${_tokenRefreshSubscription != null}',
    );
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
      onError: (Object error) {
        _notifDebug('token refresh listener error=$error');
      },
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    _notifDebug(
      'create local notification start messageId=${message.messageId} '
      'sentTime=${message.sentTime} dataKeys=${message.data.keys.join(",")}',
    );
    await _ensureLocalNotificationsInitialized();

    try {
      if (_shouldSkipDuplicateNotification(message)) {
        return;
      }

      final title = _notificationTitleFromMessage(message);
      final body = _notificationBodyFromMessage(message);
      _notifDebug(
        'parse result messageId=${message.messageId} title=$title body=$body',
      );
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
        'create local notification details messageId=${message.messageId} '
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
      _notifDebug(
        'create local notification platformDetails androidSound=${channel.sound} '
        'darwinSound=${channel.id == _bookingNotificationChannel.id ? _bookingDarwinNotificationSound : _basicDarwinNotificationSound}',
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
      _notifDebug('created local notification channel=${channel.id}');
    } catch (e) {
      _notifDebug('local notification failed error=$e');
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
