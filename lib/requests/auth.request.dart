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
  static const int _webUploadMaxLongSide = 1080;
  static const Duration _authConnectTimeout = Duration(seconds: 60);
  static const Duration _authSendTimeout = Duration(seconds: 120);
  static const Duration _authReceiveTimeout = Duration(seconds: 120);

  String _selfieUploadFilename({
    bool mobileProfileUpdate = false,
    Uint8List? uploadBytes,
  }) {
    final ext = _imageUploadExtension(uploadBytes ?? selfieFile);
    if (mobileProfileUpdate && selfieFileFromMobileCamera) {
      return "mobile_${Random().nextInt(900000)}.$ext";
    }
    return "image_${Random().nextInt(900000)}.$ext";
  }

  String _imageUploadExtension(Uint8List? bytes) {
    if (bytes == null || bytes.length < 12) {
      return !kIsWeb ? "png" : "jpg";
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return "png";
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return "jpg";
    }
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return "gif";
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return "webp";
    }
    return !kIsWeb ? "png" : "jpg";
  }

  Future<Uint8List?> _effectiveSelfieUploadBytes() async {
    if (selfieFile == null) {
      return null;
    }
    Uint8List effectiveBytes = selfieFile!;
    if (selfieFileNeedsHorizontalFlip) {
      effectiveBytes = await _flipImageBytesHorizontally(effectiveBytes);
    }
    int uploadMaxLongSide = kIsWeb
        ? _webUploadMaxLongSide
        : _mobileUploadMaxLongSide;
    effectiveBytes = await _resizeImageBytesForUpload(
      effectiveBytes,
      maxLongSide: uploadMaxLongSide,
    );
    return effectiveBytes;
  }

  Future<ApiResponse> fcmRequest({
    required String token,
    required List<String> topics,
  }) async {
    try {
      final body = {
        "token": token,
        "topics": topics.join(","),
        "action": "subscribeTopics",
      };
      final fcmUrl = "${Api.baseUrl}${Api.fcm}";
      final apiResult = await post(
        fcmUrl,
        body,
      );
      final postResponse = ApiResponse.fromResponse(apiResult);
      if (!postResponse.message.contains('POST method is not supported')) {
        return postResponse;
      }

      final fallbackResult = await get(
        fcmUrl,
        queryParameters: body,
      );
      return ApiResponse.fromResponse(fallbackResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<User> getUser() async {
    try {
      final apiResult = await get(
        Api.authUser,
        includeHeaders: true,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
      );
      return ApiResponse.fromResponse(apiResult);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<ApiResponse> logoutRequest() async {
    try {
      final apiResult = await get(Api.authSignOut);
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
              filename: _selfieUploadFilename(
                uploadBytes: effectiveSelfieFile,
              ),
            ),
          ),
        );
        formData.files.add(
          MapEntry(
            "customizable_photo",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(
                uploadBytes: effectiveSelfieFile,
              ),
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
              filename: _selfieUploadFilename(
                uploadBytes: effectiveSelfieFile,
              ),
            ),
          ),
        );
        formData.files.add(
          MapEntry(
            "customizable_photo",
            MultipartFile.fromBytes(
              effectiveSelfieFile,
              filename: _selfieUploadFilename(
                uploadBytes: effectiveSelfieFile,
              ),
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
        connectTimeout: _authConnectTimeout,
        sendTimeout: _authSendTimeout,
        receiveTimeout: _authReceiveTimeout,
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
      final effectivePhoto =
          photo == null ? null : await _effectiveSelfieUploadBytes() ?? photo;
      final apiResult = await postWithFiles(
        Api.authUpdate,
        {
          "_method": "PUT",
          "name": name,
          "email": email,
          "phone": phone,
          "country_code": countryCode,
          "photo": effectivePhoto == null
              ? null
              : MultipartFile.fromBytes(
                  effectivePhoto,
                  filename: _selfieUploadFilename(
                    mobileProfileUpdate: true,
                    uploadBytes: effectivePhoto,
                  ),
                ),
        },
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
  final scale = longSide <= maxLongSide ? 1.0 : maxLongSide / longSide;
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
