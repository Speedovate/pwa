import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pwa/services/storage.service.dart';

class AppStrings {
  static String get appName => env('app_name') ?? '';

  static String get companyName => env('company_name') ?? '';

  static String get googleMapApiKey => env('google_maps_key') ?? '';

  static bool get avoidHighways => env('avoid_highways') ?? false;

  static bool get avoidTolls => env('avoid_tolls') ?? false;

  static bool get avoidFerries => env('avoid_ferries') ?? false;

  static bool get optimizeWaypoints => env('optimize_waypoints') ?? false;

  static String get fcmApiKey => env('fcm_key') ?? '';

  static String get currencySymbol => env('currency') ?? '';

  static String get countryCode => env('country_code') ?? '';

  static bool get enableOtp => env('enable_otp') == '1';

  static bool get enableOTPLogin => env('enableOTPLogin') == '1';

  static bool get enableGoogleDistance => env('enableGoogleDistance') == '1';

  static bool get enableSingleVendor => env('enableSingleVendor') == '1';

  static bool get enableMultipleVendorOrder =>
      env('enableMultipleVendorOrder') ?? false;

  static bool get enableReferSystem => env('enableReferSystem') == '1';

  static String get referAmount => env('referAmount') ?? '';

  static bool get enableChat => env('enableChat') == '1';

  static bool get enableOrderTracking => env('enableOrderTracking') == '1';

  static bool get enableFetchByLocation => env('enableFetchByLocation') ?? true;

  static bool get showVendorTypeImageOnly =>
      env('showVendorTypeImageOnly') == '1';

  static bool get enableUploadPrescription =>
      env('enableUploadPrescription') == '1';

  static bool get enableParcelVendorByLocation =>
      env('enableParcelVendorByLocation') == '1';

  static bool get enableParcelMultipleStops =>
      env('enableParcelMultipleStops') == '1';

  static int get maxParcelStops =>
      int.parse(env('maxParcelStops')?.toString() ?? '1');

  static String get what3wordsApiKey => env('what3wordsApiKey') ?? '';

  static bool get isWhat3wordsApiKey => what3wordsApiKey.isNotEmpty;

  static String get androidDownloadLink => env('androidDownloadLink') ?? '';

  static String get iOSDownloadLink => env('iosDownloadLink') ?? '';

  static String get huaweiDownloadLink => env('huaweiDownloadLink') ?? '';

  static bool get isSingleVendorMode => env('isSingleVendorMode') == '1';

  static bool get canScheduleTaxiOrder =>
      env('taxi')?['canScheduleTaxiOrder'] == '1';

  static int get taxiMaxScheduleDays =>
      int.parse(env('taxi')?['taxiMaxScheduleDays']?.toString() ?? '2');

  static Map<String, dynamic>? get enabledVendorType =>
      env('enabledVendorType');

  static double get bannerHeight =>
      double.parse(env('bannerHeight')?.toString() ?? '150.0');

  static String get otpGateway => env('otpGateway') ?? 'itexmo';

  static bool get isFirebaseOtp => otpGateway.toLowerCase() == 'firebase';

  static bool get isCustomOtp => otpGateway.toLowerCase() != 'firebase';

  static String get emergencyContact => env('emergencyContact') ?? '911';

  static bool get googleLogin => env('auth')?['googleLogin'] ?? true;

  static bool get appleLogin => env('auth')?['appleLogin'] ?? false;

  static bool get facebookLogin => env('auth')?['facebookLogin'] ?? false;

  static bool get qrcodeLogin => env('auth')?['qrcodeLogin'] ?? false;

  static dynamic get uiConfig => env('ui');

  static double get categoryImageWidth =>
      double.parse(env('ui')?['categorySize']?['w']?.toString() ?? '40.0');

  static double get categoryImageHeight =>
      double.parse(env('ui')?['categorySize']?['h']?.toString() ?? '40.0');

  static double get categoryTextSize => double.parse(
      env('ui')?['categorySize']?['text']?['size']?.toString() ?? '12.0');

  static int get categoryPerRow =>
      int.parse(env('ui')?['categorySize']?['row']?.toString() ?? '4');

  static bool get searchGoogleMapByCountry =>
      env('ui')?['google']?['searchByCountry'] ?? false;

  static String get searchGoogleMapByCountries =>
      env('ui')?['google']?['searchByCountries'] ?? '';

  static const String notificationChannel = 'high_importance_channel';
  static const String firstTimeOnApp = 'first_time';
  static const String authenticated = 'authenticated';
  static const String userToken = 'auth_token';
  static const String userKey = 'user';
  static const String appLocale = 'locale';
  static const String notificationsKey = 'notifications';
  static const String appCurrency = 'currency';
  static const String appColors = 'colors';
  static const String appRemoteSettings = 'appRemoteSettings';
  static const String homeSettings = 'homeSettings';
  static const String fixedTrips = 'fixedTrips';
  static const String vehicleTypes = 'vehicleTypes';
  static const String appStoreId = '1663633725';

  static dynamic appSettingsObject;
  static dynamic homeSettingsObject;

  static Future<bool?> saveAppSettingsToStorage(String stringMap) async {
    return await StorageService.prefs?.setString(
      AppStrings.appRemoteSettings,
      stringMap,
    );
  }

  static Future<bool?> saveHomeSettingsToStorage(String stringMap) async {
    return StorageService.prefs?.setString(
      AppStrings.homeSettings,
      stringMap,
    );
  }

  static Future getAppSettingsFromStorage() async {
    try {
      appSettingsObject = StorageService.prefs?.getString(
        AppStrings.appRemoteSettings,
      );
      if (appSettingsObject != null) {
        appSettingsObject = jsonDecode(
          appSettingsObject,
        );
      }
    } catch (_) {
      debugPrint(
        "getAppSettingsFromStorage: null",
      );
    }
  }

  static Future getHomeSettingsFromStorage() async {
    try {
      homeSettingsObject = StorageService.prefs?.getString(
        AppStrings.homeSettings,
      );
      if (homeSettingsObject != null) {
        homeSettingsObject = jsonDecode(
          homeSettingsObject,
        );
      }
    } catch (_) {
      debugPrint(
        "getHomeSettingsFromStorage: null",
      );
    }
  }

  static dynamic env(String ref) {
    getAppSettingsFromStorage();
    return appSettingsObject != null ? appSettingsObject[ref] : "";
  }

  static List<String> get orderCancellationReasons {
    return [
      "Long pickup time",
      "Vendor is too slow",
      "custom",
    ];
  }

  static List<String> get orderStatuses {
    return [
      'pending',
      'preparing',
      'ready',
      'enroute',
      'failed',
      'cancelled',
      'delivered'
    ];
  }
}
