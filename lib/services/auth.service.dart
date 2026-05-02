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
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/services/storage.service.dart';

class AuthService {
  static String? bearerToken;
  static User? currentUser;

  static const List<String> _guestTopics = ["all"];

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
    await syncStoredTopicsForCurrentSession();
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
    await AuthService().syncStoredTopicsForCurrentSession();
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
    AlertService().stopLoading(forceStop: true);
    final currentContext = Get.context;
    if (currentContext != null) {
      ScaffoldMessenger.maybeOf(currentContext)?.clearSnackBars();
    }
    if (Get.isDialogOpen == true) {
      Get.back();
    }
    await StorageService.rxPrefs?.clear();
    await StorageService.prefs?.clear();
    await StorageService.prefs?.setStringList("topics", _guestTopics);
    await StorageService.prefs?.remove(AppStrings.lastPushTopicSignature);
    dropoffAddress = null;
    pickupAddress = null;
    currentUser = null;
    await PushService.syncTokenWithServer(forceSync: true);
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
      return;
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
      return;
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

  Future<void> syncStoredTopicsForCurrentSession() async {
    final topics = isLoggedIn()
        ? _buildLoggedInTopics()
        : _guestTopics;
    await StorageService.prefs?.setStringList(
      "topics",
      topics,
    );
  }

  List<String> _buildLoggedInTopics() {
    final topics = <String>[
      "all",
      "c",
      "client",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "${currentUser?.id}",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "c_${currentUser?.id}",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "client_${currentUser?.id}",
      if ("${currentUser?.branchID}".trim().isNotEmpty &&
          "${currentUser?.branchID}" != "null")
        "branch_${currentUser?.branchID}",
    ];
    return topics.toSet().toList();
  }
}
