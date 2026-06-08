import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:georange/georange.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/models/coordinates.model.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/requests/settings.request.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashViewModel extends BaseViewModel {
  StreamSubscription? configStream;
  StreamSubscription? hotspotStream;
  TaxiRequest taxiRequest = TaxiRequest();
  SettingsRequest settingsRequest = SettingsRequest();

  Future<void> initialise() async {
    await getAppUser();
    await AuthService().syncStoredTopicsForCurrentSession();
    await AppStrings.getAppSettingsFromStorage();
    await AppStrings.getHomeSettingsFromStorage();
    if (AppStrings.appSettingsObject == null) {
      await getSettings();
    }
    _handleUpgradeGate();
    await AuthService.ensureUserNameInFirestore();
    if (isIOSLikeBrowser()) {
      initLatLng = defaultLatLng;
      lastGeolocationErrorMessage = null;
    } else {
      await getMyLatLng(
        forceFresh: true,
        requestPermission: false,
      );
    }
    subscribeToServer();
    startListeningToConfigs();
    startListeningToHotspots();
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ??
        !AuthService.isLoggedIn();
    isAd1Seen = StorageService.prefs?.getBool("is_ad_1_seen") ??
        !AuthService.isLoggedIn();
    unawaited(getBanners());
    unawaited(getVehicles());
    await goToNextPage();
  }

  bool _handleUpgradeGate() {
    if (!AuthService.shouldUpgrade()) {
      AuthService.resetUpgradeDismissal();
    }
    return true;
  }

  Future<void> getAppUser() async {
    await AuthService.getUserFromStorage();
    await AuthService.getTokenFromStorage();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      versionCode = packageInfo.buildNumber;
      version = packageInfo.version;
    } catch (e) {
      // Package info is best-effort during splash.
    }
  }

  Future<void> getSettings() async {
    try {
      ApiResponse hResponse = await settingsRequest.homeSettingsRequest();
      await AppStrings.saveHomeSettingsToStorage(
        jsonEncode(hResponse.body),
      );
      await AppStrings.getHomeSettingsFromStorage();
      ApiResponse aResponse = await settingsRequest.appSettingsRequest();
      await AppStrings.saveAppSettingsToStorage(
        jsonEncode(aResponse.body),
      );
      await AppStrings.getAppSettingsFromStorage();
      try {
        notifyListeners();
        if (AuthService.isLoggedIn()) {
          Point earthCenterLocation = Point(
            latitude: 0.00,
            longitude: 0.00,
          );
          double earthDistance = GeoRange().distance(
            earthCenterLocation,
            Point(
              latitude: double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
              longitude:
                  double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.syncLocationRequest(
            earthDistance: earthDistance,
            lat: double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
            lng: double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
            isMocked: false,
          );
          if (apiResponse.allGood) {
          } else {
            throw apiResponse.message;
          }
        }
      } catch (e) {
        // Location sync is best-effort during splash.
      }
    } catch (_) {
      // Settings fetch failures are handled by existing fallback flow.
    }
    startListeningToConfigs();
    startListeningToHotspots();
  }

  Future<void> getBanners() async {
    try {
      gBanners = await settingsRequest.bannersRequest();
    } catch (e) {
      // Banner loading failures are non-fatal.
    }
  }

  Future<void> getVehicles() async {
    try {
      gVehicleTypes = await taxiRequest.vehicleTypesRequest();
    } catch (e) {
      // Vehicle loading failures are non-fatal.
    }
  }

  Future<void> goToNextPage() async {
    if (!AuthService.isLoggedIn()) {
      Navigator.pushAndRemoveUntil(
        Get.context!,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (
            context,
            a,
            b,
          ) =>
              const IntroView(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        Get.context!,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (
            context,
            a,
            b,
          ) =>
              const HomeView(),
        ),
        (route) => false,
      );
    }
  }

  startListeningToConfigs() {
    if (configStream != null && !configStream!.isPaused) {
      return;
    }
    configStream = fbStore
        .collection("config")
        .doc("pxSAbF8XqPWayhRVMvo7")
        .snapshots()
        .listen(
      (event) async {
        try {
          if ("${StorageService.prefs?.getString("config_version")}" == "" ||
              "${StorageService.prefs?.getString("config_version")}" ==
                  "null" ||
              "${StorageService.prefs?.getString("config_version")}" !=
                  "${event.data()?["version"]}") {
            await StorageService.prefs?.setString(
              "config_version",
              "${event.data()?["version"]}",
            );
            await getSettings();
            Get.forceAppUpdate();
          } else {
            await AppStrings.getAppSettingsFromStorage();
            await AppStrings.getHomeSettingsFromStorage();
          }
        } catch (_) {}
      },
    );
  }

  void startListeningToHotspots() {
    if (hotspotStream != null && !hotspotStream!.isPaused) {
      return;
    }
    hotspotStream = fbStore
        .collection("hotspots")
        .doc("puerto-princesa")
        .snapshots()
        .listen(
      (event) async {
        try {
          final List hotspots = event.data()?["places"] ?? [];
          gSpots = hotspots
              .map(
                (e) => Address(
                  addressLine: e?["add"],
                  coordinates: Coordinates(
                    double.parse(e?["lat"]),
                    double.parse(e?["lng"]),
                  ),
                ),
              )
              .toList();
        } catch (_) {
          gSpots = [];
        }
      },
    );
  }
}
