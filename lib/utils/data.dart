import 'dart:io';
import 'dart:async';
import 'dart:html' as html;
import 'package:pwa/models/banner.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/models/wallet.model.dart';
import 'package:pwa/models/address.model.dart';
import 'package:pwa/models/chat_media.model.dart';
import 'package:pwa/models/vehicle_type.model.dart';
import 'package:pwa/models/available_driver.model.dart';

File? chatFile;
Wallet? gWallet;
dynamic cameras;
String? version;
File? selfieFile;
Timer? globalTimer;
bool agreed = false;
int orderDriver = 0;
String? versionCode;
int branchNumber = 0;
bool isAdSeen = false;
bool isSharing = false;
Address? pickupAddress;
bool showBranch = false;
Address? dropoffAddress;
bool locUnavailable = false;
bool mapUnavailable = false;
bool cameFromSettings = false;
bool cameFromLocation = false;
bool otherVehicleOpen = false;
bool loadingPolylines = false;
List<ChatMedia> mediaList = [];
AvailableDriver? availableDriver;
List<VehicleType> availableVehicles = [];

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

List<Banner> gBanners = [];
List<VehicleType> gVehicleTypes = [];

var geolocation = html.window.navigator.geolocation;
