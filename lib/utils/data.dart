// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'package:pwa/models/banner.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/load.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/chat_media.model.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:pwa/models/available_driver.model.dart';

Load? gLoad;
dynamic cameras;
String? version;
String? fcmToken;
Timer? globalTimer;
Uint8List? chatFile;
final ValueNotifier<Uint8List?> chatFileListenable = ValueNotifier(null);
bool agreed = false;
int orderDriver = 0;
String? versionCode;
int branchNumber = 0;
Uint8List? selfieFile;
bool isAdSeen = false;
bool isAd1Seen = false;
bool isSharing = false;
bool isChatViewOpen = false;
bool isLoadingDialogOpen = false;
final ValueNotifier<bool> isLoadingDialogOpenListenable = ValueNotifier(false);
Address? pickupAddress;
bool isTourist = false;
bool showBranch = false;
Address? dropoffAddress;
bool showParseText = false;
bool locUnavailable = false;
bool mapUnavailable = false;
bool cameFromSettings = false;
bool cameFromLocation = false;
bool otherVehicleOpen = false;
bool loadingPolylines = false;
List<ChatMedia> mediaList = [];
AvailableDriver? availableDriver;
List<VehicleType> availableVehicles = [];
String useExt = "enableFatchByLocation";
String itexmo = "enableParcelVendorByLocation";
const gmaps.LatLng defaultLatLng = gmaps.LatLng(
  9.763886475089924,
  118.747330789576,
);
gmaps.LatLng? initLatLng = defaultLatLng;
gmaps.LatLng? lastKnownRealLatLng;
bool hasRealLocationFix = false;
String? lastGeolocationErrorMessage;

RegExp phoneRegex = RegExp(
  r"^9\d{9}$",
);

RegExp emailRegex = RegExp(
  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
);

RegExp nameRegex = RegExp(
  r"^[A-Za-zÑñ]{2,}(?:\s+[A-Za-zÑñ]\.?|\s+[A-Za-zÑñ]+)*(?:\s+[A-Za-zÑñ]{2,})+$",
);

int bookingId = 0;
int rebookSecs = 0;
Timer? resendCountdownTimer;
Timer? rebookCountdownTimer;
int resendSecs = defaultCountdownSeconds;
int maxResendSeconds = defaultCountdownSeconds;
int defaultCountdownSeconds =
    AppStrings.homeSettingsObject?["code_countdown_seconds"] ?? 120;

List<Address> gSpots = [];
List<Banner> gBanners = [];
List<VehicleType> gVehicleTypes = [];

final fbStore = FirebaseFirestore.instance;
final userQuickChatDoc = fbStore.collection("quick_chat").doc("user");
var geolocation = html.window.navigator.geolocation;

void setLoadingDialogOpen(bool isOpen) {
  if (isLoadingDialogOpen == isOpen &&
      isLoadingDialogOpenListenable.value == isOpen) {
    return;
  }
  isLoadingDialogOpen = isOpen;
  isLoadingDialogOpenListenable.value = isOpen;
}

void setChatFile(Uint8List? fileBytes) {
  if (identical(chatFile, fileBytes) &&
      identical(chatFileListenable.value, fileBytes)) {
    return;
  }
  chatFile = fileBytes;
  chatFileListenable.value = fileBytes;
}

void setChatViewOpen(bool isOpen) {
  isChatViewOpen = isOpen;
}

Future<void> waitForLoadingDialogToClose() {
  if (!isLoadingDialogOpen) {
    return Future.value();
  }

  final completer = Completer<void>();

  void listener() {
    if (isLoadingDialogOpenListenable.value) {
      return;
    }
    isLoadingDialogOpenListenable.removeListener(listener);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  isLoadingDialogOpenListenable.addListener(listener);
  listener();
  return completer.future;
}

List<String> parseQuickChatOptions(Map<String, dynamic>? data) {
  final rawOptions = data?["options"];
  if (rawOptions is! List) {
    return const [];
  }

  return rawOptions
      .map((option) => "$option".trim())
      .where((option) => option.isNotEmpty && option.toLowerCase() != "null")
      .toList();
}

bool isPhotoUrlMessage(String? message) {
  final value = (message ?? "").trim().toLowerCase();
  return value.startsWith("https://") || value.startsWith("http://");
}
