import 'dart:math';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/views/change.view.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/map.service.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';

class VerifyViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var codeTEC = TextEditingController();
  var nameTEC = TextEditingController();
  var emailTEC = TextEditingController();
  var phoneTEC = TextEditingController();
  var birthdayTEC = TextEditingController();
  var referralTEC = TextEditingController();
  var passwordTEC = TextEditingController();

  bool get _usesRemoteOtpConfig =>
      isBool(AppStrings.appSettingsObject?["strings"][itexmo] ?? false);

  String _resolvedErrorMessage(
    ApiResponse apiResponse, {
    required String fallback,
  }) {
    final text = apiResponse.message.trim();
    if (text.isEmpty || text.toLowerCase() == "null") {
      final body = apiResponse.body;
      if (body is Map<String, dynamic>) {
        final error = "${body["error"] ?? ""}".trim();
        if (error.isNotEmpty && error.toLowerCase() != "null") {
          return error;
        }

        final errors = body["errors"];
        if (errors is List && errors.isNotEmpty) {
          final first = "${errors.first}".trim();
          if (first.isNotEmpty && first.toLowerCase() != "null") {
            return first;
          }
        }
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              final first = "${value.first}".trim();
              if (first.isNotEmpty && first.toLowerCase() != "null") {
                return first;
              }
            }
            final direct = "$value".trim();
            if (direct.isNotEmpty && direct.toLowerCase() != "null") {
              return direct;
            }
          }
        }
      } else {
        final raw = "$body".trim();
        if (raw.isNotEmpty && raw.toLowerCase() != "null") {
          return raw;
        }
      }
      return "$fallback [${apiResponse.code}]";
    }
    return text;
  }

  initialise({
    String? name,
    String? email,
    String? phone,
    String? birthday,
    String? referral,
    String? password,
  }) async {
    nameTEC.text = name ?? "";
    emailTEC.text = email ?? "";
    phoneTEC.text = phone ?? "";
    birthdayTEC.text = birthday ?? "";
    referralTEC.text = referral ?? "";
    passwordTEC.text = password ?? "";
    await applyOtpConfigBehavior();
    notifyListeners();
  }

  Future<void> applyOtpConfigBehavior() async {
    if (_usesRemoteOtpConfig) {
      codeTEC.text = "";
    } else {
      codeTEC.text = "${100000 + Random().nextInt(900000)}";
      try {
        await PushService.syncTokenWithServer(requestPermission: false);
      } catch (_) {}
    }
    notifyListeners();
  }

  resendCode() async {
    try {
      ApiResponse apiResponse = await authRequest.sendOTP(
        type: "register",
        phone: "+63${phoneTEC.text}",
      );
      if (apiResponse.allGood) {
        if (apiResponse.body?["data"] != null) {
          if (apiResponse.body?["data"]["exists"] == true) {
            maxResendSeconds = int.parse(
              apiResponse.body!["data"]["countdown_remaining"].toString(),
            );
            resendSecs = int.parse(
              apiResponse.body!["data"]["countdown_remaining"].toString(),
            );
            showError(apiResponse.message);
          }
        }
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      showError(e);
    }
  }

  verifyCode(String purpose) async {
    if ((codeTEC.text == "" || codeTEC.text == "null") ||
        codeTEC.text.length != 6) {
      showError("Please enter the 6-digit code");
    } else {
      try {
        ApiResponse apiResponse;
        AlertService().showLoading();
        if (isBool(AppStrings.appSettingsObject?["strings"][itexmo] ?? false)) {
          apiResponse = await authRequest.verifyOTP(
            code: codeTEC.text.trim(),
            phone: "+63${phoneTEC.text}",
          );
        } else {
          apiResponse = await authRequest.verifyOTP(
            code: "008891",
            phone: "+63${phoneTEC.text}",
          );
        }
        if (apiResponse.allGood) {
          try {
            if (purpose == "register") {
              ApiResponse apiResponse = await authRequest.registerRequest(
                countryCode: "PH",
                email: emailTEC.text,
                code: referralTEC.text,
                password: passwordTEC.text,
                phone: "+63${phoneTEC.text}",
                birthday: birthdayTEC.text.trim(),
                name: capitalizeWords(nameTEC.text),
                lat: double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
                lng: double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
              );
              if (apiResponse.hasError()) {
                AlertService().stopLoading();
                AlertService().showAppAlert(
                  asset: AppLotties.error,
                  title: "Registration Failed",
                  content: _resolvedErrorMessage(
                    apiResponse,
                    fallback:
                        "There was an error while processing your registration. Please try again later.",
                  ),
                );
              } else {
                final fbToken = apiResponse.body?["fb_token"];
                try {
                  await FirebaseAuth.instance.signInWithCustomToken(fbToken);
                } catch (e) {
                  throw e.toString();
                }
                await AuthService().saveUserToStorage(
                  jsonEncode(
                    apiResponse.body?["user"],
                  ),
                );
                await AuthService.saveTokenToStorage(
                  apiResponse.body?["token"],
                );
                await AuthService.getUserFromStorage();
                await AuthService.getTokenFromStorage();
                await AppStrings.getAppSettingsFromStorage();
                await AuthService.ensureUserNameInFirestore();
                await PushService.syncTokenWithServer(requestPermission: false);
                await MapService.warmUpPreferredMapEngine();
                AlertService().stopLoading(forceStop: true);
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
                        const HomeView(),
                  ),
                  (route) => false,
                );
              }
            } else if (purpose == "forgot_password") {
              AlertService().stopLoading();
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
                      ChangeView(
                    isReset: true,
                    phone: phoneTEC.text,
                  ),
                ),
              );
            }
          } catch (e) {
            throw e.toString();
          }
        } else {
          AlertService().stopLoading();
          AlertService().showAppAlert(
            asset: AppLotties.error,
            title: "Verification Failed",
            content: _resolvedErrorMessage(
              apiResponse,
              fallback:
                  "There was an error while verifying your code. Please try again later.",
            ),
          );
        }
      } catch (e) {
        AlertService().stopLoading();
        showError(e);
      }
    }
  }
}
