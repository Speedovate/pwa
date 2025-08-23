import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:pwa/widgets/camera.widget.dart';
import 'package:pwa/widgets/list_tile.widget.dart';
import 'package:pwa/widgets/web_view.widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:google_maps/google_maps.dart' as gmaps;

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

          return parts[0] +
              '(' +
              parts[1][0].toUpperCase() +
              parts[1].substring(1).toLowerCase();
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
      input.toString().trim().isEmpty ||
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
      input.toString().trim().isEmpty ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(' ').map(
      (word) {
        if (word.contains('(')) {
          var parts = word.split('(');
          return parts[0].toLowerCase() + '(' + parts[1].toLowerCase();
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
      input.toString().trim().isEmpty ||
      input.toString().trim() == "null") {
    return alt;
  } else {
    return input.split(' ').map(
      (word) {
        if (word.contains('(')) {
          var parts = word.split('(');
          return parts[0].toUpperCase() + '(' + parts[1].toUpperCase();
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
  const double minSpeed = 35;
  const double maxSpeed = 55;
  int calculateSeconds(double speed) => ((distanceKm / speed) * 3600).round();
  String formatTimeRange(int minSeconds, int maxSeconds) {
    if (maxSeconds < 60) {
      if (minSeconds.round() == maxSeconds.round()) {
        return "${maxSeconds.round()} sec${maxSeconds.round() != 1 ? "s" : ""}";
      } else {
        return "${minSeconds.round()} - ${maxSeconds.round()} sec";
      }
    } else if (maxSeconds < 3600) {
      final minMinutes = (minSeconds / 60).ceil();
      final maxMinutes = (maxSeconds / 60).ceil();
      if (minMinutes.round() == maxMinutes.round()) {
        return "${maxMinutes.round()} min${maxMinutes.round() != 1 ? "s" : ""}";
      } else {
        return "$minMinutes - $maxMinutes min";
      }
    } else {
      final minHours = double.parse((minSeconds / 3600).toStringAsFixed(1));
      final maxHours = double.parse((maxSeconds / 3600).toStringAsFixed(1));
      if (minHours.round() == maxHours.round()) {
        return "${maxHours.round()} hr${maxHours.round() != 1 ? "s" : ""}";
      } else {
        return "$minHours - $maxHours hr";
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
      debugPrint(
        "Error: '$fieldName' is null.",
      );
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
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
    return 0.0;
  }
}

parseString(dynamic value, String fieldName) {
  try {
    if (value == null) {
      debugPrint(
        "Error: '$fieldName' is null.",
      );
      return null;
    }
    if (value is String) {
      return value;
    } else if (value is int || value is double) {
      return value.toString();
    }
    return value.toString();
  } catch (e) {
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
    return "";
  }
}

parseInt(dynamic value, String fieldName) {
  try {
    if (value == null) {
      debugPrint(
        "Error: '$fieldName' is null.",
      );
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
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
    return 0;
  }
}

bool parseBool(dynamic value, String fieldName) {
  try {
    if (value == null) {
      debugPrint(
        "Error: '$fieldName' is null",
      );
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
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
    return false;
  }
}

parseDateTime(dynamic value, String fieldName) {
  try {
    if (value == null) {
      debugPrint(
        "Error: '$fieldName' is null.",
      );
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
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
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
      debugPrint(
        "Error: '$fieldName' is null.",
      );
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
    debugPrint(
      "Error parsing field '$fieldName': $e",
    );
    return null;
  }
}

Future<gmaps.LatLng?> getMyLatLng() async {
  try {
    final position = await geolocation.getCurrentPosition();
    final lat = position.coords?.latitude;
    final lng = position.coords?.longitude;
    if (lat != null && lng != null) {
      return gmaps.LatLng(
        lat,
        lng,
      );
    }
  } catch (_) {}
  return gmaps.LatLng(
    9.7392,
    118.7353,
  );
}

openWebview(
  String title,
  String url,
) {
  Get.to(
    () => WebViewWidget(
      title: title,
      selectedUrl: Uri.parse(
        url,
      ),
    ),
  );
}

Future<void> showCameraSource({
  bool isEdit = false,
  String cameraType = "profile",
}) async {
  try {
    Get.to(
      () => CameraWidget(
        isEdit: isEdit,
        cameraType: cameraType,
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
    context: Get.overlayContext!,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTileWidget(
          onTap: () async {
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
            ? const SizedBox()
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
                    debugPrint("Error picking image: $e");
                  }
                },
                leading: const Icon(Icons.image),
                title: const Text("Gallery"),
              ),
      ],
    ),
  );
}
