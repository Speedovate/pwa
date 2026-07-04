import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/user.model.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/services/storage.service.dart';

class AuthService {
  static String? bearerToken;
  static User? currentUser;
  static bool _upgradeDismissedForSession = false;
  static String? _dismissedUpgradeRuleSignature;

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
    final decoded = jsonDecode(stringMap);
    Map<String, dynamic> normalizedMap;
    if (decoded is Map<String, dynamic>) {
      normalizedMap = Map<String, dynamic>.from(decoded);
    } else if (decoded is Map) {
      normalizedMap = Map<String, dynamic>.from(decoded);
    } else {
      normalizedMap = {};
    }

    final previousUser = currentUser;
    if (normalizedMap["created_at"] == null &&
        previousUser?.createdAt != null) {
      normalizedMap["created_at"] = previousUser!.createdAt!.toIso8601String();
    }

    currentUser = User.fromJson(
      normalizedMap,
    );
    final normalizedStringMap = jsonEncode(normalizedMap);
    await StorageService.prefs?.setString(
      AppStrings.userKey,
      normalizedStringMap,
    );
    _syncPushForCurrentSessionInBackground("auth save user");
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
    } catch (_) {}
    return bearerToken;
  }

  static Future<User?> getUserFromStorage() async {
    try {
      final stringMap = StorageService.prefs?.getString(
        AppStrings.userKey,
      );
      final decoded = jsonDecode(stringMap!);
      currentUser = User.fromJson(
        decoded,
      );
    } catch (_) {}
    _syncPushForCurrentSessionInBackground(
      "auth restored user",
      forceSync: isLoggedIn(),
    );
    return currentUser;
  }

  static void _syncPushForCurrentSessionInBackground(
    String reason, {
    bool forceSync = false,
  }) {
    unawaited(
      () async {
        try {
          await AuthService().syncStoredTopicsForCurrentSession();
          await PushService.syncTokenWithServer(forceSync: forceSync);
        } catch (e) {
          // Keep push sync best-effort.
        }
      }(),
    );
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
      if (!userSnapshot.exists ||
          currentName.isEmpty ||
          currentName == "null") {
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
    } catch (_) {
      // Ignore Firestore sync failures for this best-effort update.
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
    dropoffAddress = null;
    pickupAddress = null;
    currentUser = null;
    await StorageService.prefs?.remove(AppStrings.lastPushTopicSignature);
    _syncPushForCurrentSessionInBackground(
      "auth logout",
      forceSync: true,
    );
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
  }

  static String device() {
    if (kIsWeb) {
      return "huawei";
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return "ios";
      case TargetPlatform.android:
        return "android";
      default:
        return "huawei";
    }
  }

  static bool inReviewMode() {
    final reviewVersionKey = switch (device()) {
      "ios" => "disable_ibn",
      "huawei" => "disable_hbn",
      "android" => "disable_gbn",
      _ => null,
    };
    final homeSettings = AppStrings.homeSettingsObject;
    if (reviewVersionKey == null || homeSettings is! Map) {
      return false;
    }
    return "${homeSettings[reviewVersionKey]}" == versionCode;
  }

  static Map<String, dynamic>? _upgradeConfigFor(String appKey) {
    final appSettings = AppStrings.appSettingsObject;
    if (appSettings is! Map) {
      return null;
    }
    final strings = appSettings["strings"];
    if (strings is! Map) {
      return null;
    }
    final upgrade = strings["upgrade"];
    if (upgrade is! Map) {
      return null;
    }
    final upgradeConfig = upgrade[appKey];
    if (upgradeConfig is Map<String, dynamic>) {
      return upgradeConfig;
    }
    if (upgradeConfig is Map) {
      return Map<String, dynamic>.from(upgradeConfig);
    }
    return null;
  }

  static int _upgradeVersionForDeviceFrom(Map<String, dynamic>? upgradeConfig) {
    final versionByDevice = switch (device()) {
      "ios" => upgradeConfig?["ios"],
      "android" => upgradeConfig?["android"],
      _ => upgradeConfig?["huawei"],
    };
    return int.tryParse("${versionByDevice ?? 0}") ?? 0;
  }

  static ({int version, bool force}) _effectiveUpgradeRule() {
    final customerConfig = _upgradeConfigFor("customer");
    final vendorConfig = _upgradeConfigFor("vendor");
    final customerVersion = _upgradeVersionForDeviceFrom(customerConfig);
    final vendorVersion = _upgradeVersionForDeviceFrom(vendorConfig);

    if (vendorVersion > customerVersion) {
      final vendorForce = "${vendorConfig?["force"] ?? "0"}".toLowerCase();
      return (
        version: vendorVersion,
        force: vendorForce == "1" || vendorForce == "true",
      );
    }

    final customerForce = "${customerConfig?["force"] ?? "0"}".toLowerCase();
    final vendorForce = "${vendorConfig?["force"] ?? "0"}".toLowerCase();
    return (
      version: customerVersion,
      force: customerVersion == vendorVersion
          ? (customerForce == "1" ||
              customerForce == "true" ||
              vendorForce == "1" ||
              vendorForce == "true")
          : (customerForce == "1" || customerForce == "true"),
    );
  }

  static bool _shouldUpgradeForCurrentRule() {
    try {
      final currentVersion = int.parse("${versionCode ?? 0}");
      return currentVersion < _effectiveUpgradeRule().version;
    } catch (e) {
      return false;
    }
  }

  static String _currentUpgradeRuleSignature() {
    final rule = _effectiveUpgradeRule();
    return "${device()}|${rule.version}|${rule.force}|${upgradeDownloadLink()}";
  }

  static void syncUpgradeDismissalForCurrentConfig() {
    final shouldUpgradeNow = _shouldUpgradeForCurrentRule();
    final nextSignature = _currentUpgradeRuleSignature();
    if (!shouldUpgradeNow) {
      _upgradeDismissedForSession = false;
      _dismissedUpgradeRuleSignature = null;
      return;
    }
    if (_dismissedUpgradeRuleSignature != null &&
        _dismissedUpgradeRuleSignature != nextSignature) {
      _upgradeDismissedForSession = false;
      _dismissedUpgradeRuleSignature = null;
    }
  }

  static bool shouldUpgrade() {
    syncUpgradeDismissalForCurrentConfig();
    return _shouldUpgradeForCurrentRule();
  }

  static bool isUpgradeForced() {
    return _effectiveUpgradeRule().force;
  }

  static bool isUpgradeDismissed() {
    syncUpgradeDismissalForCurrentConfig();
    return _upgradeDismissedForSession;
  }

  static void dismissUpgradeForSession() {
    _upgradeDismissedForSession = true;
    _dismissedUpgradeRuleSignature = _currentUpgradeRuleSignature();
  }

  static void resetUpgradeDismissal() {
    _upgradeDismissedForSession = false;
    _dismissedUpgradeRuleSignature = null;
  }

  static String upgradeDownloadLink() {
    final resolvedLink = switch (device()) {
      "ios" => "https://apps.apple.com/app/id6743928831",
      "android" => AppStrings.androidDownloadLink,
      _ => AppStrings.huaweiDownloadLink,
    };
    if (resolvedLink.trim().isNotEmpty) {
      return resolvedLink;
    }

    return "https://ppctoda.com";
  }

  subscribeToTopic(String topic) async {
    try {
      final topics = StorageService.prefs?.getStringList("topics") ?? [];
      if (!topics.contains(topic)) {
        topics.add(topic);
        await StorageService.prefs?.setStringList("topics", topics);
      }
      if (!kIsWeb) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
    } catch (e) {
      // Ignore topic persistence failures.
    }
  }

  unsubscribeFromTopic(String topic) async {
    try {
      final topics = StorageService.prefs?.getStringList("topics") ?? [];
      topics.remove(topic);
      await StorageService.prefs?.setStringList("topics", topics);
      if (!kIsWeb) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (e) {
      // Ignore topic persistence failures.
    }
  }

  Future<List<String>> getSubscribedTopics() async {
    return StorageService.prefs?.getStringList("topics") ?? [];
  }

  Future<void> syncStoredTopicsForCurrentSession() async {
    final topics = _normalizedTopicsForCurrentSession();
    await StorageService.prefs?.setStringList(
      "topics",
      topics,
    );
    if (!kIsWeb) {
      for (final topic in topics) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } catch (e) {
          // Ignore best-effort topic subscribe failures.
        }
      }
    }
  }

  List<String> _normalizedTopicsForCurrentSession() {
    final topics = isLoggedIn() ? _buildLoggedInTopics() : _guestTopics;
    if (!topics.contains("all")) {
      topics.add("all");
    }
    return topics.toSet().toList();
  }

  List<String> _buildLoggedInTopics() {
    final topics = <String>[
      "all",
      "c",
      "client",
      "customer",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "${currentUser?.id}",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "c_${currentUser?.id}",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "client_${currentUser?.id}",
      if ("${currentUser?.id}".trim().isNotEmpty &&
          "${currentUser?.id}" != "null")
        "customer_${currentUser?.id}",
      if ("${currentUser?.branchID}".trim().isNotEmpty &&
          "${currentUser?.branchID}" != "null")
        "branch_${currentUser?.branchID}",
      if ("${currentUser?.branchID}".trim().isNotEmpty &&
          "${currentUser?.branchID}" != "null")
        "branch_${currentUser?.branchID}_client",
      if ("${currentUser?.branchID}".trim().isNotEmpty &&
          "${currentUser?.branchID}" != "null")
        "branch_${currentUser?.branchID}_customer",
    ];
    return topics.toSet().toList();
  }
}
