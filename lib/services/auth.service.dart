import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/user.model.dart';
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

  Future<User?> saveUserToStorage(String stringMap) async {
    currentUser = User.fromJson(
      jsonDecode(stringMap),
    );
    await StorageService.prefs?.setString(
      AppStrings.userKey,
      stringMap,
    );
    subscribeToTopic("all");
    subscribeToTopic("${currentUser?.id}");
    subscribeToTopic("${currentUser?.role}");
    subscribeToTopic("branch_${currentUser?.branchID}");
    subscribeToTopic("${currentUser?.role?.split("")[0]}");
    subscribeToTopic("${currentUser?.role}_${currentUser?.id}");
    subscribeToTopic("${currentUser?.role?.split("")[0]}_${currentUser?.id}");
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

  logout() async {
    unsubscribeFromTopic("${currentUser?.id}");
    unsubscribeFromTopic("${currentUser?.role}");
    unsubscribeFromTopic("branch_${currentUser?.branchID}");
    unsubscribeFromTopic("${currentUser?.role?.split("")[0]}");
    unsubscribeFromTopic("${currentUser?.role}_${currentUser?.id}");
    unsubscribeFromTopic(
        "${currentUser?.role?.split("")[0]}_${currentUser?.id}");
    await StorageService.rxPrefs?.clear();
    await StorageService.prefs?.clear();
    dropoffAddress = null;
    pickupAddress = null;
    currentUser = null;
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
  }

  static String device() => "huawei";

  static bool inReviewMode() {
    bool disable = false;
    if (AppStrings.homeSettingsObject != null) {
      if (device() == "huawei" &&
          "${AppStrings.homeSettingsObject?["disable_hbn"]}" == versionCode) {
        disable = true;
      }
    }
    return disable;
  }

  static bool shouldUpgrade() {
    try {
      final webNewVersion = int.parse(
        "${AppStrings.appSettingsObject?["strings"]?["upgrade"]?["customer"]?["huawei"] ?? 0}",
      );
      final currentVersion = int.parse("${versionCode ?? 0}");
      return currentVersion < webNewVersion;
    } catch (e) {
      return false;
    }
  }

   subscribeToTopic(String topic) async {
    try {
      final topics = StorageService.prefs?.getStringList("topics") ?? [];
      if (!topics.contains(topic)) {
        topics.add(topic);
        await StorageService.prefs?.setStringList("topics", topics);
      }
      debugPrint("Subscribed to topic: $topic (web pseudo)");
    } catch (e) {
      debugPrint("Error subscribing to topic $topic: $e");
    }
  }

   unsubscribeFromTopic(String topic) async {
    try {
      final topics = StorageService.prefs?.getStringList("topics") ?? [];
      topics.remove(topic);
      await StorageService.prefs?.setStringList("topics", topics);
      debugPrint("Unsubscribed from topic: $topic (web pseudo)");
    } catch (e) {
      debugPrint("Error unsubscribing from topic $topic: $e");
    }
  }

  Future<List<String>> getSubscribedTopics() async {
    return StorageService.prefs?.getStringList("topics") ?? [];
  }
}
