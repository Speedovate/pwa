import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:georange/georange.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/requests/settings.request.dart';

class SplashViewModel extends BaseViewModel {
  StreamSubscription? configStream;
  TaxiRequest taxiRequest = TaxiRequest();
  SettingsRequest settingsRequest = SettingsRequest();

  Future<void> initialise() async {
    await getAppUser();
    await getVehicles();
    await getBanners();
    startListeningToConfigs();
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ?? !AuthService.isLoggedIn();
    await goToNextPage();
  }

  Future<void> getAppUser() async {
    await AuthService.getUserFromStorage();
    await AuthService.getTokenFromStorage();
    try {
      version = "1.0.0";
      versionCode = "1";
    } catch (e) {
      debugPrint(
        "getAppInfo error: $e",
      );
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
        myLatLng = await getMyLatLng();
        notifyListeners();
        if (AuthService.isLoggedIn()) {
          if (myLatLng != null) {
            Point earthCenterLocation = Point(
              latitude: 0.00,
              longitude: 0.00,
            );
            double earthDistance = GeoRange().distance(
              earthCenterLocation,
              Point(
                latitude: double.parse("${myLatLng?.lat ?? 9.7638}"),
                longitude: double.parse("${myLatLng?.lng ?? 118.7473}"),
              ),
            );
            ApiResponse apiResponse = await taxiRequest.syncLocationRequest(
              earthDistance: earthDistance,
              lat: double.parse("${myLatLng?.lat ?? 9.7638}"),
              lng: double.parse("${myLatLng?.lng ?? 118.7473}"),
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
        }
      } catch (e) {
        debugPrint(
          "splash getSettings error: $e",
        );
      }
    } catch (_) {}
    startListeningToConfigs();
  }

  Future<void> getBanners() async {
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

  Future<void> getVehicles() async {
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
          Get.overlayContext!,
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
          Get.overlayContext!,
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
        Get.overlayContext!,
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

  void startListeningToConfigs() {
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
}
