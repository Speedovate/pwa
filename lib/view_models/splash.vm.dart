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

class SplashViewModel extends BaseViewModel {
  StreamSubscription? configStream;
  StreamSubscription? hotspotStream;
  TaxiRequest taxiRequest = TaxiRequest();
  SettingsRequest settingsRequest = SettingsRequest();

  initialise() async {
    await getAppUser();
    await getBanners();
    await getVehicles();
    subscribeToServer();
    startListeningToConfigs();
    startListeningToHotspots();
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ??
        !AuthService.isLoggedIn();
    isAd1Seen = StorageService.prefs?.getBool("is_ad_1_seen") ??
        !AuthService.isLoggedIn();
    await goToNextPage();
  }

  getAppUser() async {
    await AuthService.getUserFromStorage();
    await AuthService.getTokenFromStorage();
    try {
      version = "1.0.32";
      versionCode = "52";
    } catch (e) {
      debugPrint(
        "getAppInfo error: $e",
      );
    }
  }

  getSettings() async {
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
              latitude: double.parse("${initLatLng?.lat ?? 9.7638}"),
              longitude: double.parse("${initLatLng?.lng ?? 118.7473}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.syncLocationRequest(
            earthDistance: earthDistance,
            lat: double.parse("${initLatLng?.lat ?? 9.7638}"),
            lng: double.parse("${initLatLng?.lng ?? 118.7473}"),
            isMocked: false,
          );
          if (apiResponse.allGood) {
            debugPrint(
              "splash getSettings success",
            );
          } else {
            throw apiResponse.message;
          }
        }
      } catch (e) {
        debugPrint(
          "splash getSettings error: $e",
        );
      }
    } catch (_) {}
    startListeningToConfigs();
    startListeningToHotspots();
  }

  getBanners() async {
    try {
      gBanners = await settingsRequest.bannersRequest();
      debugPrint(
        "splash bannersRequest success",
      );
    } catch (e) {
      debugPrint(
        "splash bannersRequest error: $e",
      );
    }
  }

  getVehicles() async {
    try {
      gVehicleTypes = await taxiRequest.vehicleTypesRequest();
      debugPrint(
        "splash vehicleTypesRequest success",
      );
    } catch (e) {
      debugPrint(
        "splash vehicleTypesRequest error: $e",
      );
    }
  }

  goToNextPage() {
    if (!AuthService.isLoggedIn()) {
      if (!AuthService.inReviewMode()) {
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
        // print("xyz ${jsonEncode(
        //   gSpots
        //       .map(
        //         (e) => {
        //           'add': e.addressLine,
        //           'lat': e.coordinates.latitude,
        //           'lng': e.coordinates.longitude,
        //         },
        //       )
        //       .toList(),
        // )}");
      },
    );
  }
}
