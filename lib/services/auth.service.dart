import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/user.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/services/storage.service.dart';

class AuthService {
  static String? bearerToken;
  static User? currentUser;

  static bool isLoggedIn() {
    return currentUser != null;
  }

  static Future<String> saveTokenToStorage(
    String userToken,
  ) async {
    await StorageService.prefs?.setString(
      AppStrings.userToken,
      userToken,
    );
    return userToken;
  }

  Future<User?> saveUserToStorage(
    String stringMap,
  ) async {
    currentUser = User.fromJson(
      jsonDecode(stringMap),
    );
    await StorageService.prefs?.setString(
      AppStrings.userKey,
      stringMap,
    );
    // subscribeToTopic(
    //   "all",
    // );
    // subscribeToTopic(
    //   "${currentUser?.id}",
    // );
    // subscribeToTopic(
    //   "${currentUser?.role}",
    // );
    // subscribeToTopic(
    //   "c_${currentUser?.id}",
    // );
    // subscribeToTopic(
    //   "branch_${currentUser?.branchID}",
    // );
    // subscribeToTopic(
    //   "branch_${currentUser?.branchID}_${currentUser?.role}",
    // );
    return currentUser;
  }

  static Future<String?> getTokenFromStorage() async {
    try {
      final String? string = StorageService.prefs?.getString(
        AppStrings.userToken,
      );
      if (string != "" && string != null) {
        bearerToken = string;
      } else {
        throw "null";
      }
    } catch (_) {
      debugPrint(
        "getTokenFromStorage: null",
      );
    }
    return bearerToken;
  }

  static Future<User?> getUserFromStorage() async {
    try {
      final stringMap = StorageService.prefs?.getString(
        AppStrings.userKey,
      );
      currentUser = User.fromJson(
        jsonDecode(stringMap!),
      );
    } catch (_) {
      debugPrint(
        "getUserFromStorage: null",
      );
    }
    return currentUser;
  }

  Future<void> logout() async {
    // unsubscribeFromTopic(
    //   "${currentUser?.id}",
    // );
    // unsubscribeFromTopic(
    //   "${currentUser?.role}",
    // );
    // unsubscribeFromTopic(
    //   "c_${currentUser?.id}",
    // );
    // unsubscribeFromTopic(
    //   "branch_${currentUser?.branchID}",
    // );
    // unsubscribeFromTopic(
    //   "branch_${currentUser?.branchID}_${currentUser?.role}",
    // );
    await HttpService().getCacheManager().clearAll();
    await StorageService.rxPrefs?.clear();
    await StorageService.prefs?.clear();
    dropoffAddress = null;
    pickupAddress = null;
    currentUser = null;
    if (!AuthService.inReviewMode()) {
      Get.offAll(() => const IntroView());
    } else {
      Get.offAll(() => const HomeView());
    }
  }

  static String device() {
    if (kIsWeb) {
      return "web";
    } else if (Platform.isIOS) {
      return "ios";
    } else {
      return "android";
    }
  }

  static bool inReviewMode() {
    bool disable = false;
    if (AppStrings.homeSettingsObject != null) {
      if (device() == "ios" &&
          "${AppStrings.homeSettingsObject?["disable_ibn"]}" == versionCode) {
        disable = true;
      }
      if (device() == "android" &&
          "${AppStrings.homeSettingsObject?["disable_gbn"]}" == versionCode) {
        disable = true;
      }
    } else {
      disable = false;
    }
    return disable;
  }

  static bool shouldUpgrade() {
    try {
      final androidNewVersion = int.parse(
        "${AppStrings.appSettingsObject?["strings"]?["upgrade"]?["customer"]?["android"] ?? 0}",
      );
      final iosNewVersion = int.parse(
        "${AppStrings.appSettingsObject?["strings"]?["upgrade"]?["customer"]?["ios"] ?? 0}",
      );
      final webNewVersion = int.parse(
        "${AppStrings.appSettingsObject?["strings"]?["upgrade"]?["customer"]?["web"] ?? 0}",
      );
      final currentVersion = int.parse("${versionCode ?? 0}");
      if (kIsWeb) {
        return currentVersion < webNewVersion;
      } else if (Platform.isIOS) {
        return currentVersion < iosNewVersion;
      } else {
        return currentVersion < androidNewVersion;
      }
    } catch (e) {
      return false;
    }
  }

// void subscribeToTopic(String topic) {
//   try {
//     fMsg.subscribeToTopic(topic);
//     debugPrint("Subscribed to topic: $topic");
//   } catch (e) {
//     debugPrint("Error subscribing to topic $topic: $e");
//   }
// }

// void unsubscribeFromTopic(String topic) {
//   try {
//     fMsg.unsubscribeFromTopic(topic);
//     debugPrint("Unsubscribed from topic: $topic");
//   } catch (e) {
//     debugPrint("Error unsubscribing from topic $topic: $e");
//   }
// }
}
