// ignore_for_file: avoid_web_libraries_in_flutter

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
Timer? pickupCountdownTimer;
Timer? resendCountdownTimer;
Timer? rebookCountdownTimer;
int pickupSecs = defaultPickupSeconds;
int resendSecs = defaultCountdownSeconds;
int maxResendSeconds = defaultCountdownSeconds;
int defaultPickupSeconds = 4;
int defaultCountdownSeconds =
    AppStrings.homeSettingsObject?["code_countdown_seconds"] ?? 120;

List<Address> gSpots = [];
List<Banner> gBanners = [];
List<VehicleType> gVehicleTypes = [];

final fbStore = FirebaseFirestore.instance;
var geolocation = html.window.navigator.geolocation;
