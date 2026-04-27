// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/camera.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/web_view.widget.dart';
import 'package:pwa/services/storage.service.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/utils/map_types.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';

const String facebookSupportUrl = "https://www.facebook.com/ppctodaofficial";
const String telSupportUrl = "tel://+639686410532";
const String smsSupportUrl = "sms://+639686410532";

String browserUserAgent() => lowerCase(
      html.window.navigator.userAgent,
      alt: "",
    );

bool isHuaweiLikeBrowser() {
  final userAgent = browserUserAgent();
  return userAgent.contains("huaweibrowser") || userAgent.contains("hmscore");
}

bool isIOSLikeBrowser() {
  final userAgent = browserUserAgent();
  if (userAgent.contains("iphone") ||
      userAgent.contains("ipad") ||
      userAgent.contains("ipod")) {
    return true;
  }
  if (userAgent.contains("macintosh")) {
    try {
      final touchPoints = globalContext
          .getProperty<JSObject>('navigator'.toJS)
          .getProperty<JSNumber?>('maxTouchPoints'.toJS);
      return (touchPoints?.toDartInt ?? 0) > 1;
    } catch (_) {
      return false;
    }
  }
  return false;
}

bool isGoogleAuthLikelySupported() => !isIOSLikeBrowser();

bool isWebPushLikelySupported() => html.window.navigator.serviceWorker != null;

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
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (dialogContext) {
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
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(dialogContext).padding.top,
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF030744),
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
                                Navigator.of(dialogContext).pop();
                                await openFacebookSupportChannel();
                              },
                            ),
                            const SizedBox(height: 12),
                            _supportDialogButton(
                              label: "Send us a message",
                              icon: Icons.sms,
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                try {
                                  await launchUrl(
                                    Uri.parse(smsSupportUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (_) {}
                              },
                            ),
                            const SizedBox(height: 12),
                            _supportDialogButton(
                              label: "Contact us",
                              icon: Icons.call,
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                try {
                                  await launchUrl(
                                    Uri.parse(telSupportUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (_) {}
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
        ),
      );
    },
  );
}

Widget _supportDialogButton({
  required String label,
  required IconData icon,
  required Future<void> Function() onTap,
}) {
  const color = Color(0xFF1877F2);
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: const BorderRadius.all(
        Radius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        focusColor: Colors.black.withValues(alpha: 0.2),
        hoverColor: Colors.black.withValues(alpha: 0.2),
        splashColor: Colors.black.withValues(alpha: 0.2),
        highlightColor: Colors.black.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: color,
              ),
            ],
          ),
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
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null.",
        );
      }
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
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
    return 0.0;
  }
}

parseString(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null.",
        );
      }
      return null;
    }
    if (value is String) {
      return value;
    } else if (value is int || value is double) {
      return value.toString();
    }
    return value.toString();
  } catch (e) {
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
    return "";
  }
}

parseInt(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null.",
        );
      }
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
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
    return 0;
  }
}

bool parseBool(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null",
        );
      }
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
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
    return false;
  }
}

parseDateTime(dynamic value, String fieldName) {
  try {
    if (value == null) {
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null.",
        );
      }
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
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
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
      if (showParseText) {
        debugPrint(
          "Error: '$fieldName' is null.",
        );
      }
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
    if (showParseText) {
      debugPrint(
        "Error '$fieldName': $e",
      );
    }
    return null;
  }
}

Future<gmaps.LatLng?> getMyLatLng({
  bool forceFresh = false,
}) async {
  final useFastTimeout =
      !forceFresh && hasRealLocationFix && lastKnownRealLatLng != null;
  try {
    lastGeolocationErrorMessage = null;
    final position = await _requestCurrentPosition(
      enableHighAccuracy: true,
      timeout: useFastTimeout ? const Duration(seconds: 5) : null,
      maximumAge: useFastTimeout ? const Duration(seconds: 30) : Duration.zero,
    );
    return _storeRealLatLng(position);
  } catch (e, stackTrace) {
    final permissionDenied = await _isGeolocationDenied();
    if (!permissionDenied) {
      try {
        final relaxedPosition = await _requestCurrentPosition(
          enableHighAccuracy: false,
          timeout: const Duration(seconds: 10),
          maximumAge: const Duration(seconds: 30),
        );
        lastGeolocationErrorMessage = null;
        return _storeRealLatLng(relaxedPosition);
      } catch (retryError) {
        debugPrint(
          "Retry location fetch failed: ${_describeGeolocationError(retryError)}",
        );
        lastGeolocationErrorMessage = _describeGeolocationError(retryError);
      }
    }
    final existingLocation =
        _nonDefaultLatLng(lastKnownRealLatLng) ?? _nonDefaultLatLng(initLatLng);
    initLatLng = existingLocation ?? (permissionDenied ? defaultLatLng : null);
    lastGeolocationErrorMessage ??= _describeGeolocationError(e);
    debugPrint(
      "Failed to fetch location: ${_describeGeolocationError(e)}\n$stackTrace\nusing fallback $initLatLng",
    );
    return initLatLng;
  }
}

Future<html.Geoposition> _requestCurrentPosition({
  required bool enableHighAccuracy,
  required Duration? timeout,
  required Duration maximumAge,
}) {
  return geolocation.getCurrentPosition(
    enableHighAccuracy: enableHighAccuracy,
    timeout: timeout,
    maximumAge: maximumAge,
  );
}

gmaps.LatLng _storeRealLatLng(html.Geoposition position) {
  final lat = position.coords?.latitude;
  final lng = position.coords?.longitude;
  if (lat == null || lng == null) {
    throw "Location coordinates are unavailable";
  }
  final nextLatLng = gmaps.LatLng(
    lat.toDouble(),
    lng.toDouble(),
  );
  initLatLng = nextLatLng;
  lastKnownRealLatLng = nextLatLng;
  hasRealLocationFix = true;
  debugPrint("Location fetched: $initLatLng");
  return nextLatLng;
}

gmaps.LatLng? _nonDefaultLatLng(gmaps.LatLng? value) {
  if (value == null) {
    return null;
  }
  if (value.lat == defaultLatLng.lat && value.lng == defaultLatLng.lng) {
    return null;
  }
  return value;
}

String _describeGeolocationError(Object error) {
  try {
    final jsError = error as JSObject;
    final code = jsError.getProperty<JSAny?>('code'.toJS)?.dartify();
    final message = jsError.getProperty<JSAny?>('message'.toJS)?.dartify();
    final normalizedCode = '$code';
    final readableCode = switch (normalizedCode) {
      '1' => 'PERMISSION_DENIED',
      '2' => 'POSITION_UNAVAILABLE',
      '3' => 'TIMEOUT',
      _ => 'UNKNOWN_ERROR',
    };
    return '$readableCode: $message';
  } catch (_) {
    return '$error';
  }
}

Future<bool> _isGeolocationDenied() async {
  try {
    final permissions = globalContext
        .getProperty<JSObject>('navigator'.toJS)
        .getProperty<JSObject?>('permissions'.toJS);
    if (permissions == null) {
      return false;
    }
    final queryPromise = permissions.callMethod<JSPromise<JSObject?>>(
      'query'.toJS,
      {
        'name': 'geolocation',
      }.jsify(),
    );
    final status = await queryPromise.toDart;
    final state = status?.getProperty<JSString?>('state'.toJS)?.toDart;
    return '$state' == 'denied';
  } catch (_) {
    return false;
  }
}

openWebview(String title, String url) {
  bool isExternal = Uri.tryParse(url)?.host != Uri.base.host;
  if (isExternal) {
    html.window.open(url, '_blank');
    return;
  }
  Navigator.push(
    Get.context!,
    PageRouteBuilder(
      reverseTransitionDuration: Duration.zero,
      transitionDuration: Duration.zero,
      pageBuilder: (context, a, b) => WebViewWidget(
        title: title,
        selectedUrl: Uri.parse(url),
      ),
    ),
  );
}

showCameraSource({
  bool isEdit = false,
  String cameraType = "profile",
}) async {
  try {
    Navigator.push(
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
  } catch (e) {
    AlertService().showAppAlert(
      title: "Error",
      content: e.toString(),
    );
  }
}

Future<dynamic> showImageSource({
  bool isEdit = false,
  bool hideGallery = false,
  String cameraType = "profile",
}) async {
  return showModalBottomSheet(
    context: Get.context!,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTileWidget(
          onTap: () {
            Get.back();
            showCameraSource(
              isEdit: isEdit,
              cameraType: cameraType,
            );
          },
          leading: const Icon(Icons.camera_alt),
          title: const Text("Camera"),
        ),
        hideGallery
            ? const SizedBox.shrink()
            : ListTileWidget(
                onTap: () async {
                  Get.back();
                  try {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      selfieFile = await image.readAsBytes();
                      Get.forceAppUpdate();
                    }
                  } catch (e) {
                    if (showParseText) {
                      debugPrint(
                        "Error picking image: $e",
                      );
                    }
                  }
                },
                leading: const Icon(Icons.image),
                title: const Text("Gallery"),
              ),
      ],
    ),
  );
}

share(String text) async {
  try {
    await html.window.navigator.share(
      {
        'title': 'PPC TODA (Beta)',
        'text': text,
        'url': "https://ppctoda.com",
      },
    );
  } catch (e) {
    Clipboard.setData(
      ClipboardData(
        text: "$text Here's the download link: "
            "https://ppctoda.com",
      ),
    );
    ScaffoldMessenger.of(
      Get.context!,
    ).clearSnackBars();
    ScaffoldMessenger.of(
      Get.context!,
    ).showSnackBar(
      SnackBar(
        margin: const EdgeInsets.all(
          20,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const Text(
          "Copied to clipboard.",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

showError(Object error) {
  final context = Get.context;
  if (context == null) return;
  String message = error.toString();
  if (message.startsWith("Exception: ")) {
    message = message.replaceFirst("Exception: ", "");
  }
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.red.shade700,
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

Map<String, dynamic> parseJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw Exception('Invalid token');
  final payload = base64Url.normalize(parts[1]);
  final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));
  return payloadMap;
}

Future<void> subscribeToServer() async {
  final token = fcmToken?.trim();
  if (token == null || token.isEmpty || token == "null") {
    debugPrint("Skipping FCM subscription: token unavailable");
    return;
  }
  if (AuthService.isLoggedIn()) {
    final topics = StorageService.prefs?.getStringList("topics") ?? [];
    try {
      ApiResponse apiResponse = await AuthRequest().fcmRequest(
        token: token,
        topics: topics,
      );
      if (apiResponse.allGood) {
        debugPrint("subscribed topic(s): ${topics.join(",")}");
        debugPrint("reponse: ${jsonEncode(apiResponse.body)}");
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      debugPrint("$e");
    }
  } else {
    final topics = ["all"];
    try {
      ApiResponse apiResponse = await AuthRequest().fcmRequest(
        token: token,
        topics: topics,
      );
      if (apiResponse.allGood) {
        debugPrint("subscribed topic(s): ${topics.join(",")}");
        debugPrint("reponse: ${jsonEncode(apiResponse.body)}");
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      debugPrint("$e");
    }
  }
}

void copyToClipboardWeb(String text) {
  final textarea = html.TextAreaElement()
    ..value = text
    ..style.position = 'fixed';
  html.document.body?.append(textarea);
  textarea.focus();
  textarea.select();
  html.document.execCommand('copy');
  textarea.remove();
}
