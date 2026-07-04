import 'dart:convert';
export 'browser_utils.dart';
export 'location_helper.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/browser_utils.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/widgets/camera.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/web_view.widget.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:permission_handler/permission_handler.dart';

const String facebookSupportUrl = "https://www.facebook.com/ppctodaofficial";
const String telSupportUrl = "tel:+639686410532";
const String smsSupportUrl = "sms:+639686410532";

void showPermissionSettingsDialog({
  required String permissionName,
  String? reason,
}) {
  AlertService().showPermissionSettingsDialog(
    permissionName: permissionName,
    reason: reason,
  );
}

Future<void> openFacebookSupportChannel() async {
  final facebookAppUri = Uri.parse(
    "fb://facewebmodal/f?href=${Uri.encodeComponent(facebookSupportUrl)}",
  );
  final facebookWebUri = Uri.parse(facebookSupportUrl);
  final smsUri = Uri.parse(smsSupportUrl);

  try {
    if (await canLaunchUrl(facebookAppUri) &&
        await launchUrl(
          facebookAppUri,
          mode: LaunchMode.externalApplication,
        )) {
      return;
    }
  } catch (_) {}

  try {
    if (await launchUrl(
      facebookWebUri,
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {}

  try {
    await launchUrl(
      smsUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
}

Future<void> showFacebookSupportDialog(
  BuildContext context, {
  String title = "Need assistance?",
  bool showRequestCancellation = false,
  Future<void> Function()? onRequestCancellation,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    useSafeArea: false,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 24,
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 800,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(20),
                  ),
                  border: Border.all(
                    color: const Color(0xFF030744).withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF030744).withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 4, 6, 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    height: 1.05,
                                    fontSize: 18,
                                    fontFamily: "Inter",
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF030744),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: WidgetButton(
                                  onTap: () => Navigator.of(context).pop(),
                                  mainColor: Colors.transparent,
                                  isTransparentColor: true,
                                  useDefaultHoverColor: false,
                                  interactionColor: const Color(0x14030744),
                                  borderRadius: 1000,
                                  child: const Center(
                                    child: Icon(
                                      Icons.close,
                                      size: 28,
                                      color: Color(0xFF030744),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          _supportDialogButton(
                            label: "Message us on Facebook",
                            icon: Icons.facebook,
                            onTap: () async {
                              Navigator.of(context).pop();
                              await openFacebookSupportChannel();
                            },
                          ),
                          const SizedBox(height: 10),
                          _supportDialogButton(
                            label: "Send us a message",
                            icon: Icons.sms,
                            onTap: () async {
                              Navigator.of(context).pop();
                              try {
                                await launchUrl(
                                  Uri.parse(smsSupportUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            },
                          ),
                          const SizedBox(height: 10),
                          _supportDialogButton(
                            label: "Contact us",
                            icon: Icons.call,
                            onTap: () async {
                              Navigator.of(context).pop();
                              try {
                                await launchUrl(
                                  Uri.parse(telSupportUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            },
                          ),
                          !showRequestCancellation
                              ? const SizedBox.shrink()
                              : const SizedBox(height: 10),
                          !showRequestCancellation
                              ? const SizedBox.shrink()
                              : _supportDialogButton(
                                  label: "Request cancellation",
                                  icon: Icons.cancel,
                                  color: Colors.red,
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    await onRequestCancellation?.call();
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

bool canShowRequestCancellationPill({
  String? status,
  dynamic driver,
  dynamic driverId,
}) {
  final hasAssignedDriver = hasAssignedDriverForOrder(
    driver: driver,
    driverId: driverId,
  );
  final normalizedStatus = (status ?? "").trim().toLowerCase();
  if (normalizedStatus == "pending" && !hasAssignedDriver) {
    return false;
  }
  return ![
    "enroute",
    "delivered",
    "completed",
    "successful",
    "cancelled",
  ].contains(normalizedStatus);
}

bool hasAssignedDriverForOrder({
  dynamic driver,
  dynamic driverId,
}) {
  if (driver != null) {
    return true;
  }
  final normalizedDriverId = "${driverId ?? ""}".trim().toLowerCase();
  return normalizedDriverId.isNotEmpty && normalizedDriverId != "null";
}

bool canShowGetNewDriverNowAction({
  String? status,
  dynamic driver,
  dynamic driverId,
}) {
  final normalizedStatus = (status ?? "").trim().toLowerCase();
  final hasAssignedDriver = hasAssignedDriverForOrder(
    driver: driver,
    driverId: driverId,
  );
  if (normalizedStatus == "pending" && !hasAssignedDriver) {
    return false;
  }
  return true;
}

Widget _supportDialogButton({
  required String label,
  required IconData icon,
  required Future<void> Function() onTap,
  Color color = const Color(0xFF1877F2),
}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: WidgetButton(
      onTap: onTap,
      borderRadius: 14,
      mainColor: color.withValues(alpha: 0.1),
      interactionColor: color.withValues(alpha: 0.18),
      useDefaultHoverColor: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color,
            ),
          ],
        ),
      ),
    ),
  );
}

String capitalizeWords(
  dynamic input, {
  String alt = "•••",
}) {
  if (input == null ||
      input.toString().trim() == "" ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(' ').map(
      (word) {
        if (word.contains('(')) {
          var parts = word.split('(');

          return "${parts[0]}(${parts[1][0].toUpperCase()}${parts[1].substring(1).toLowerCase()}";
        }
        return word.split('-').map(
          (part) {
            if (part.isNotEmpty) {
              return part[0].toUpperCase() + part.substring(1).toLowerCase();
            }
            return part;
          },
        ).join('-');
      },
    ).join(' ');
  }
}

String normalizeRequestMessage(dynamic input) {
  return "${input ?? ""}".trim().toLowerCase();
}

bool isRequestCancellationMessage(dynamic input) {
  return normalizeRequestMessage(input) == "request cancellation";
}

String? requestMessageType(dynamic input) {
  if (isRequestCancellationMessage(input)) {
    return "cancellation";
  }
  return null;
}

String displayRequestMessageLabel(
  dynamic input, {
  String alt = "",
}) {
  final type = requestMessageType(input);
  if (type == "cancellation") {
    return capitalizeWords("request cancellation", alt: alt);
  }
  return alt;
}

String capitalizeSentences(
  dynamic input, {
  String alt = "•••",
}) {
  if (input == null ||
      input.toString().trim() == "" ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(RegExp(r'(?<=[.!?])\s+')).map((sentence) {
      String trimmedSentence = sentence.trim();
      if (trimmedSentence.isEmpty) return "";
      String capitalizedSentence = trimmedSentence[0].toUpperCase() +
          trimmedSentence.substring(1).toLowerCase();
      return capitalizedSentence;
    }).join(' ');
  }
}

String lowerCase(
  dynamic input, {
  String alt = "•••",
}) {
  if (input == null ||
      input.toString().trim() == "" ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(' ').map(
      (word) {
        if (word.contains('(')) {
          var parts = word.split('(');
          return "${parts[0].toLowerCase()}(${parts[1].toLowerCase()}";
        }
        return word
            .split('-')
            .map(
              (part) => part.toLowerCase(),
            )
            .join('-');
      },
    ).join(' ');
  }
}

String upperCase(
  dynamic input, {
  String alt = "•••",
}) {
  if (input == null ||
      input.toString().trim() == "" ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(' ').map(
      (word) {
        if (word.contains('(')) {
          var parts = word.split('(');
          return "${parts[0].toUpperCase()}(${parts[1].toUpperCase()}";
        }
        return word
            .split('-')
            .map(
              (part) => part.toUpperCase(),
            )
            .join('-');
      },
    ).join(' ');
  }
}

bool isBool(dynamic value) {
  if (value == null) {
    return false;
  } else {
    return value.toString() == "1" || value.toString() == "true";
  }
}

String travelTime(double distanceKm) {
  const double minSpeed = 25;
  const double maxSpeed = 40;
  int calculateSeconds(double speed) => ((distanceKm / speed) * 3600).round();
  String rangeUnit(String singular, String plural, num start, num end) {
    return start == 1 && end == 1 ? singular : plural;
  }

  String formatTimeRange(int minSeconds, int maxSeconds) {
    if (maxSeconds < 60) {
      if (minSeconds.round() == maxSeconds.round()) {
        return "${maxSeconds.round()} sec${maxSeconds.round() != 1 ? "s" : ""}";
      } else {
        return "${minSeconds.round()} - ${maxSeconds.round()} ${rangeUnit("sec", "secs", minSeconds.round(), maxSeconds.round())}";
      }
    } else if (maxSeconds < 3600) {
      final minMinutes = (minSeconds / 60).ceil();
      final maxMinutes = (maxSeconds / 60).ceil();
      if (minMinutes.round() == maxMinutes.round()) {
        return "${maxMinutes.round()} min${maxMinutes.round() != 1 ? "s" : ""}";
      } else {
        return "$minMinutes - $maxMinutes ${rangeUnit("min", "mins", minMinutes, maxMinutes)}";
      }
    } else {
      final minHours = double.parse((minSeconds / 3600).toStringAsFixed(1));
      final maxHours = double.parse((maxSeconds / 3600).toStringAsFixed(1));
      if (minHours.round() == maxHours.round()) {
        return "${maxHours.round()} hr${maxHours.round() != 1 ? "s" : ""}";
      } else {
        return "$minHours - $maxHours ${rangeUnit("hr", "hrs", minHours, maxHours)}";
      }
    }
  }

  final minTimeInSeconds = calculateSeconds(maxSpeed);
  final maxTimeInSeconds = calculateSeconds(minSpeed);
  return formatTimeRange(minTimeInSeconds, maxTimeInSeconds);
}

String formatEtaText(String input) {
  final replacements = {
    r'\bseconds\b': 'secs',
    r'\bsecond\b': 'sec',
    r'\bminutes\b': 'mins',
    r'\bminute\b': 'min',
    r'\bhours\b': 'hrs',
    r'\bhour\b': 'hr',
  };
  String formatted = input;
  replacements.forEach((pattern, replacement) {
    formatted = formatted.replaceAll(
      RegExp(pattern, caseSensitive: false),
      replacement,
    );
  });
  formatted = formatted.replaceAll(
    RegExp(
      r'\band\b',
      caseSensitive: false,
    ),
    '',
  );
  formatted = formatted.replaceAll(RegExp(r'\s+'), ' ').trim();
  return formatted;
}

parseDouble(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {}
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.parse(value.toString());
  } catch (e) {
    if (showParseText) {}
    return 0.0;
  }
}

parseString(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {}
      return null;
    }
    if (value is String) {
      return value;
    } else if (value is int || value is double) {
      return value.toString();
    }
    return value.toString();
  } catch (e) {
    if (showParseText) {}
    return "";
  }
}

parseInt(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {}
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.parse(value.toString());
  } catch (e) {
    if (showParseText) {}
    return 0;
  }
}

bool parseBool(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {}
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    return false;
  } catch (e) {
    if (showParseText) {}
    return false;
  }
}

parseDateTime(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {}
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    return null;
  } catch (e) {
    if (showParseText) {}
    return null;
  }
}

List<T>? parseList<T>(
  dynamic value,
  String fieldName, {
  T Function(dynamic)? transform,
}) {
  try {
    if (value == null) {
      if (showParseText) {}
      return null;
    }
    if (value is List) {
      if (transform != null) {
        return value.map((e) => transform(e)).toList();
      }
      return value.cast<T>();
    }
    return null;
  } catch (e) {
    if (showParseText) {}
    return null;
  }
}

openWebview(
  String title,
  String url, {
  bool isFromWallet = false,
}) {
  bool isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;
  final parsedUrl = Uri.tryParse(url);
  bool isExternal = parsedUrl?.host != Uri.base.host;
  if (!isMobile && isExternal) {
    openExternalUrl(
      url,
      sameTab: isFromWallet,
    );
    return;
  }
  Navigator.push(
    Get.context!,
    PageRouteBuilder(
      reverseTransitionDuration: Duration.zero,
      transitionDuration: Duration.zero,
      pageBuilder: (context, a, b) => WebViewWidget(
        title: title,
        isFromWallet: isFromWallet,
        selectedUrl: Uri.parse(url),
      ),
    ),
  );
}

Future<dynamic> showCameraSource({
  bool isEdit = false,
  String cameraType = "profile",
}) async {
  Future<dynamic> openCameraView() {
    return Navigator.push(
      Get.context!,
      PageRouteBuilder(
        reverseTransitionDuration: Duration.zero,
        transitionDuration: Duration.zero,
        pageBuilder: (
          context,
          a,
          b,
        ) =>
            CameraWidget(
          isEdit: isEdit,
          cameraType: cameraType,
        ),
      ),
    );
  }

  try {
    if (GetPlatform.isAndroid || GetPlatform.isIOS) {
      if (await Permission.camera.isPermanentlyDenied &&
          !AuthService.inReviewMode()) {
        showPermissionSettingsDialog(
          permissionName: "Camera",
          reason: 'Go to Settings > Apps > PPC TODA > '
              'Permissions and allow "Camera" so you can take your profile photo.',
        );
        return null;
      } else if (await Permission.camera.isDenied) {
        PermissionStatus status = await Permission.camera.request();
        if (status.isGranted) {
          return openCameraView();
        }
        showPermissionSettingsDialog(
          permissionName: "Camera",
          reason: 'Please allow camera access in Settings '
              'so you can take your profile photo.',
        );
        return null;
      } else {
        return openCameraView();
      }
    }

    return openCameraView();
  } catch (e) {
    AlertService().showAppAlert(
      title: "Error",
      content: cleanErrorMessage(e),
    );
    return null;
  }
}

Future<dynamic> showImageSource({
  bool isEdit = false,
  bool hideGallery = false,
  String cameraType = "profile",
}) async {
  return showModalBottomSheet(
    context: Get.overlayContext ?? Get.context!,
    useSafeArea: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(18),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Profile Photo",
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: "Inter",
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF030744),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTileWidget(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF030744),
              ),
              title: const Text(
                "Camera",
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: "Inter",
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF030744),
                ),
              ),
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(sheetContext).pop();
                await showCameraSource(
                  isEdit: isEdit,
                  cameraType: cameraType,
                );
              },
            ),
            if (!hideGallery)
              Divider(
                height: 1,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            if (!hideGallery)
              ListTileWidget(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                leading: const Icon(
                  Icons.image_outlined,
                  color: Color(0xFF030744),
                ),
                title: const Text(
                  "Gallery",
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: "Inter",
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF030744),
                  ),
                ),
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(sheetContext).pop();
                  await showGallerySource(cameraType: cameraType);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

Future<dynamic> showGallerySource({
  String cameraType = "profile",
}) async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selfieFile = await image.readAsBytes();
      selfieFileNeedsHorizontalFlip = false;
      selfieFileFromMobileCamera = false;
      Get.forceAppUpdate();
    }
  } catch (_) {
    showPermissionSettingsDialog(
      permissionName: "Photos",
      reason: 'Please allow photo access in Settings '
          'so you can choose an image from your gallery.',
    );
  }
}

share(String text) async {
  final shared = await tryNativeShare(
    title: 'PPC TODA',
    text: text,
    url: 'https://ppctoda.com',
  );
  if (!shared) {
    Clipboard.setData(
      ClipboardData(
        text: "$text Here's the download link: "
            "https://ppctoda.com",
      ),
    );
    showSuccess("Copied to clipboard.");
  }
}

void showSuccess(
  String message, {
  BuildContext? context,
}) {
  final currentContext = context ?? Get.context;
  if (currentContext == null) return;
  ScaffoldMessenger.of(currentContext).clearSnackBars();
  ScaffoldMessenger.of(currentContext).showSnackBar(
    SnackBar(
      backgroundColor: Colors.green,
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

void showError(
  Object error, {
  BuildContext? context,
}) {
  final currentContext = context ?? Get.context;
  if (currentContext == null) return;
  final message = cleanErrorMessage(error);
  ScaffoldMessenger.of(currentContext).clearSnackBars();
  ScaffoldMessenger.of(currentContext).showSnackBar(
    SnackBar(
      backgroundColor: Colors.red,
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

String googleAuthErrorMessage(
  Object error, {
  required bool isSignUp,
}) {
  final action = isSignUp ? "sign-up" : "sign-in";
  final fallback =
      "Google $action failed. Please try again or use phone ${isSignUp ? "registration" : "login"}.";

  if (error is PlatformException) {
    final code = error.code.trim();
    final lowerCode = code.toLowerCase();
    final message = (error.message ?? "").trim();
    final details = "${error.details ?? ""}".trim();
    final nativeMessage = message.isNotEmpty ? message : details;

    if (lowerCode.contains("cancel") || lowerCode == "sign_in_canceled") {
      return "Google $action was cancelled.";
    }
    if (lowerCode.contains("network")) {
      return "Google $action failed because the network is unavailable. Please check your connection.";
    }
    if (lowerCode.contains("developer") ||
        lowerCode.contains("configuration") ||
        lowerCode.contains("missing")) {
      return "Google $action is not configured correctly for this device. Please contact support. ($code)";
    }
    if (nativeMessage.isNotEmpty) {
      return "Google $action failed: $nativeMessage ($code)";
    }
    if (code.isNotEmpty) {
      return "Google $action failed with code $code.";
    }
    return fallback;
  }

  final message = cleanErrorMessage(error);
  if (message.isEmpty || message.toLowerCase() == "null") {
    return fallback;
  }
  return message;
}

String cleanErrorMessage(Object? error) {
  var message = "${error ?? ""}".trim();
  final prefixes = [
    "Exception: ",
    "Bad state: ",
    "Error: ",
    "FlutterError: ",
  ];
  for (final prefix in prefixes) {
    while (message.startsWith(prefix)) {
      message = message.replaceFirst(prefix, "").trim();
    }
  }
  if (message.isEmpty || message.toLowerCase() == "null") {
    return "Something went wrong.";
  }
  return message;
}

Map<String, dynamic> parseJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw Exception('Invalid token');
  final payload = base64Url.normalize(parts[1]);
  final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));
  return payloadMap;
}

Future<bool> subscribeToServer() async {
  final token = fcmToken?.trim();
  if (token == null || token.isEmpty || token == "null") {
    return false;
  }
  if (AuthService.isLoggedIn()) {
    final topics = StorageService.prefs?.getStringList("topics") ?? [];
    try {
      ApiResponse apiResponse = await AuthRequest().fcmRequest(
        token: token,
        topics: topics,
      );
      if (apiResponse.allGood) {
        return true;
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      // Ignore FCM registration failures for signed-out users.
    }
  } else {
    final topics = ["all"];
    try {
      ApiResponse apiResponse = await AuthRequest().fcmRequest(
        token: token,
        topics: topics,
      );
      if (apiResponse.allGood) {
        return true;
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      // Ignore FCM registration failures for signed-out users.
    }
  }
  return false;
}

void copyToClipboardWeb(String text) {
  Clipboard.setData(
    ClipboardData(text: text),
  );
}
