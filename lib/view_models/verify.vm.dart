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
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';

class VerifyViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var codeTEC = TextEditingController();
  var nameTEC = TextEditingController();
  var emailTEC = TextEditingController();
  var phoneTEC = TextEditingController();
  var passwordTEC = TextEditingController();

  initialise({
    String? name,
    String? email,
    String? phone,
    String? password,
  }) {
    nameTEC.text = name ?? "";
    emailTEC.text = email ?? "";
    phoneTEC.text = phone ?? "";
    passwordTEC.text = password ?? "";
    if (isBool(AppStrings.homeSettingsObject?["use_itexmo"] ?? false)) {
      codeTEC.text = "";
    } else {
      codeTEC.text = "${100000 + Random().nextInt(900000)}";
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
            ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
            ScaffoldMessenger.of(
              Get.overlayContext!,
            ).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  apiResponse.message,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
        }
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.toString(),
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  verifyCode(String purpose) async {
    if ((codeTEC.text == "" || codeTEC.text == "null") ||
        codeTEC.text.length != 6) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter the 6-digit code",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      try {
        ApiResponse apiResponse;
        AlertService().showLoading();
        if (isBool(AppStrings.homeSettingsObject?["use_itexmo"] ?? false)) {
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
              myLatLng = await getMyLatLng();
              if (myLatLng != null) {
                ApiResponse apiResponse = await authRequest.registerRequest(
                  countryCode: "PH",
                  email: emailTEC.text,
                  password: passwordTEC.text,
                  phone: "+63${phoneTEC.text}",
                  name: capitalizeWords(nameTEC.text),
                  lat: double.parse("${myLatLng?.lat ?? 9.7638}"),
                  lng: double.parse("${myLatLng?.lng ?? 118.7473}"),
                );
                if (apiResponse.hasError()) {
                  AlertService().stopLoading();
                  AlertService().showAppAlert(
                    asset: AppLotties.error,
                    title: "Registration Failed",
                    content: apiResponse.message,
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
                  Get.offAll(() => const HomeView());
                }
              } else {
                AlertService().stopLoading();
              }
            } else if (purpose == "forgot_password") {
              AlertService().stopLoading();
              Get.to(
                () => ChangeView(
                  isReset: true,
                  phone: phoneTEC.text,
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
            content: apiResponse.message,
          );
        }
      } catch (e) {
        AlertService().stopLoading();
        ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.overlayContext!,
        ).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              e.toString(),
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }
}
