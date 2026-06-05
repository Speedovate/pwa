import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/user.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/api_response.model.dart';

class AuthRequest extends HttpService {
  static const int _mobileUploadMaxLongSide = 1080;

  String _selfieUploadFilename({
    bool mobileProfileUpdate = false,
  }) {
    if (mobileProfileUpdate && selfieFileFromMobileCamera) {
      final ext = selfieFileNeedsHorizontalFlip ? "png" : "jpg";
      return "mobile_${Random().nextInt(900000)}.$ext";
    }
    final ext = selfieFileNeedsHorizontalFlip ? "png" : "jpg";
    return "image_${Random().nextInt(900000)}.$ext";
  }

  Future<Uint8List?> _effectiveSelfieUploadBytes() async {
    if (selfieFile == null) {
      return null;
    }
    Uint8List effectiveBytes = selfieFile!;
    if (selfieFileNeedsHorizontalFlip) {
      effectiveBytes = await _flipImageBytesHorizontally(effectiveBytes);
    }
    if (!kIsWeb) {
      effectiveBytes = await _resizeImageBytesForUpload(
        effectiveBytes,
        maxLongSide: _mobileUploadMaxLongSide,
      );
    }
    return effectiveBytes;
  }

  Future<ApiResponse> fcmRequest({
    required String token,
    required List<String> topics,
  }) async {
    try {
      final apiResult = await post(
        "${Api.baseUrl}/api/fcm",
        {
          "token": token,
          "topics": topics.join(","),
          "action": "subscribeTopics",
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<User> getUser() async {
    try {
      final apiResult = await get(
        Api.authUser,
        includeHeaders: true,
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      final apiResponse = ApiResponse.fromResponse(apiResult);
      if (apiResponse.allGood) {
        return User.fromJson(apiResponse.body?["user"]);
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> phoneLoginRequest({
    required String phone,
    required String password,
  }) async {
    try {
      final apiResult = await post(
        Api.authSignIn,
        {
          "phone": "+63$phone",
          "password": password,
          "role": "client",
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> googleLoginRequest({
    required String email,
    required String idToken,
  }) async {
    try {
      final apiResult = await post(
        Api.googleLogin,
        {
          "email": email,
          "provider": "google",
          "firebase_id_token": idToken,
        },
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> logoutRequest() async {
    try {
      final apiResult = await get(Api.authSignOut).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> checkCredentialsExist({
    required String email,
    required String phone,
  }) async {
    try {
      final apiResult = await get(
        Api.authCheck,
        queryParameters: {
          "email": email,
          "phone": phone,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> sendOTP({
    required String type,
    required String phone,
  }) async {
    try {
      final apiResult = await post(
        Api.authSend,
        {
          "type": type,
          "phone": phone,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> verifyOTP({
    required String code,
    required String phone,
  }) async {
    try {
      final apiResult = await post(
        Api.authVerify,
        {
          "code": code,
          "phone": phone,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> registerRequest({
    String? code,
    required double lat,
    required double lng,
    required String name,
    required String email,
    required String phone,
    required String birthday,
    required String password,
    required String countryCode,
  }) async {
    try {
      dynamic body = {
        "lat": lat,
        "lng": lng,
        "name": name,
        "code": code,
        "email": email,
        "phone": phone,
        "role": "client",
        if (!kIsWeb) "provider": "phone",
        "birthday": birthday,
        "password": password,
        "country_code": countryCode,
      };
      List<File> files = [];
      FormData formData = FormData.fromMap(body);
      final effectiveSelfieFile = await _effectiveSelfieUploadBytes();
      if (effectiveSelfieFile != null) {
        formData.files.add(
          MapEntry(
            "profile",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(),
            ),
          ),
        );
        formData.files.add(
          MapEntry(
            "customizable_photo",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(),
            ),
          ),
        );
      }
      if (files.isNotEmpty) {
        for (File file in files) {
          formData.files.addAll(
            [
              MapEntry(
                "documents[]",
                await MultipartFile.fromFile(
                  file.path,
                ),
              ),
            ],
          );
        }
      }
      final apiResult = await postCustomFiles(
        Api.authSignUp,
        null,
        formData: formData,
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> gRegisterRequest({
    String? code,
    required double lat,
    required double lng,
    required String name,
    required String email,
    required String phone,
    required String birthday,
    required String password,
    required String countryCode,
    required String firebaseIdToken,
  }) async {
    try {
      dynamic body = {
        "lat": lat,
        "lng": lng,
        "name": name,
        "code": code,
        "email": email,
        "phone": phone,
        "role": "client",
        "provider": "google",
        "birthday": birthday,
        "password": password,
        "country_code": countryCode,
        "firebase_id_token": firebaseIdToken,
      };
      List<File> files = [];
      FormData formData = FormData.fromMap(body);
      final effectiveSelfieFile = await _effectiveSelfieUploadBytes();
      if (effectiveSelfieFile != null) {
        formData.files.add(
          MapEntry(
            "profile",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(),
            ),
          ),
        );
        formData.files.add(
          MapEntry(
            "customizable_photo",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(),
            ),
          ),
        );
      }
      if (files.isNotEmpty) {
        for (File file in files) {
          formData.files.addAll(
            [
              MapEntry(
                "documents[]",
                await MultipartFile.fromFile(
                  file.path,
                ),
              ),
            ],
          );
        }
      }
      final apiResult = await postCustomFiles(
        Api.authSignUp,
        null,
        formData: formData,
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> verifyPhoneAccount({
    required String phone,
  }) async {
    try {
      final apiResult = await get(
        Api.authPhone,
        queryParameters: {
          "phone": phone,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> resetPasswordRequest({
    required String phone,
    required String password,
  }) async {
    try {
      final apiResult = await post(
        Api.authForgot,
        {
          "phone": phone,
          "password": password,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> changePasswordRequest({
    required String password,
    required String nPassword,
    required String cPassword,
  }) async {
    try {
      final apiResult = await post(
        Api.authChange,
        {
          "_method": "PUT",
          "password": password,
          "new_password": nPassword,
          "new_password_confirmation": cPassword,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> deleteProfile({
    required String password,
    required String reason,
  }) async {
    try {
      final apiResult = await post(
        Api.authDelete,
        {
          "_method": "DELETE",
          "password": password,
          "reason": reason,
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> updateProfile({
    required String? name,
    required String? email,
    required String? phone,
    required Uint8List? photo,
    required String? countryCode,
  }) async {
    try {
      final apiResult = await postWithFiles(
        Api.authUpdate,
        {
          "_method": "PUT",
          "name": name,
          "email": email,
          "phone": phone,
          "country_code": countryCode,
          "photo": photo == null
              ? null
              : MultipartFile.fromBytes(
                  await _effectiveSelfieUploadBytes() ?? photo,
                  filename: _selfieUploadFilename(
                    mobileProfileUpdate: true,
                  ),
                ),
        },
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }
}

Future<Uint8List> _flipImageBytesHorizontally(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();

  canvas.translate(image.width.toDouble(), 0);
  canvas.scale(-1, 1);
  canvas.drawImage(image, ui.Offset.zero, paint);

  final picture = recorder.endRecording();
  final flippedImage = await picture.toImage(image.width, image.height);
  final byteData = await flippedImage.toByteData(
    format: ui.ImageByteFormat.png,
  );

  if (byteData == null) {
    return bytes;
  }

  return byteData.buffer.asUint8List();
}

Future<Uint8List> _resizeImageBytesForUpload(
  Uint8List bytes, {
  required int maxLongSide,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  final longSide = max(width, height);

  if (longSide <= maxLongSide) {
    return bytes;
  }

  final scale = maxLongSide / longSide;
  final targetWidth = max(1, (width * scale).round());
  final targetHeight = max(1, (height * scale).round());
  final resizedCodec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
  final resizedFrame = await resizedCodec.getNextFrame();
  final resizedImage = resizedFrame.image;
  final byteData = await resizedImage.toByteData(
    format: ui.ImageByteFormat.png,
  );

  if (byteData == null) {
    return bytes;
  }

  return byteData.buffer.asUint8List();
}
