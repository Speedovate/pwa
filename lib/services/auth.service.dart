import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/user.model.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/services/storage.service.dart';

class AuthService {
  static String? bearerToken;
  static User? currentUser;

  static bool isLoggedIn() {
    return currentUser != null &&
        currentUser?.name != null &&
        currentUser?.name != "null";
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
    await subscribeToTopic("c");
    await subscribeToTopic("all");
    await subscribeToTopic("client");
    await subscribeToTopic("${currentUser?.id}");
    await subscribeToTopic("c_${currentUser?.id}");
    await subscribeToTopic("client_${currentUser?.id}");
    await subscribeToTopic("branch_${currentUser?.branchID}");
    await PushService.syncTokenWithServer();
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

  static Future<void> ensureUserNameInFirestore() async {
    if (!isLoggedIn() ||
        currentUser?.id == null ||
        "${currentUser?.name}".trim().isEmpty ||
        "${currentUser?.name}" == "null") {
      return;
    }
    try {
      final userRef = fbStore.collection("users").doc("${currentUser?.id}");
      final userSnapshot = await userRef.get();
      final userData = userSnapshot.data();
      final currentName = "${userData?["name"] ?? ""}".trim();
      if (!userSnapshot.exists || currentName.isEmpty || currentName == "null") {
        await userRef.set(
          {
            "id": currentUser?.id,
            "name": currentUser?.name,
            "updated_at": Timestamp.now(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint("ensureUserNameInFirestore error: $e");
    }
  }

  logout() async {
    await unsubscribeFromTopic("c");
    await unsubscribeFromTopic("client");
    await unsubscribeFromTopic("${currentUser?.id}");
    await unsubscribeFromTopic("c_${currentUser?.id}");
    await unsubscribeFromTopic("client_${currentUser?.id}");
    await unsubscribeFromTopic("branch_${currentUser?.branchID}");
    await StorageService.rxPrefs?.clear();
    await StorageService.prefs?.clear();
    dropoffAddress = null;
    pickupAddress = null;
    currentUser = null;
    await PushService.syncTokenWithServer();
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
