import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/api.dart';
import 'package:pwa/models/user.model.dart';
import 'package:pwa/services/http.service.dart';
import 'package:pwa/models/api_response.model.dart';

class AuthRequest extends HttpService {
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
        "password": password,
        "country_code": countryCode,
      };
      List<File> files = [];
      FormData formData = FormData.fromMap(body);
      if (selfieFile != null) {
        formData.files.add(
          MapEntry(
            "profile",
            MultipartFile.fromBytes(
              selfieFile!,
              filename: "profile.jpg",
            ),
          ),
        );
        formData.files.add(
          MapEntry(
            "customizable_photo",
            MultipartFile.fromBytes(
              selfieFile!,
              filename: "customizable_photo.jpg",
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
                  selfieFile!,
                  filename: "photo.jpg",
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
