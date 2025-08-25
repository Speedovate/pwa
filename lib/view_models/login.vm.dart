import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:georange/georange.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';

class LoginViewModel extends BaseViewModel {
  TaxiRequest taxiRequest = TaxiRequest();
  AuthRequest authRequest = AuthRequest();
  var phoneTEC = TextEditingController();
  var passwordTEC = TextEditingController();

  initialise() async {}

  processPhoneLogin() async {
    if (phoneTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your phone number",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (!phoneRegex.hasMatch(phoneTEC.text)) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter a valid phone number",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (passwordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (passwordTEC.text.length < 6) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Password must be at least 6 characters",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.phoneLoginRequest(
          phone: phoneTEC.text,
          password: passwordTEC.text,
        );
        await handleDeviceLogin(apiResponse);
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

  handleDeviceLogin(ApiResponse apiResponse) async {
    if (apiResponse.hasError()) {
      AlertService().stopLoading();
      AlertService().showAppAlert(
        asset: AppLotties.error,
        title: "Login Failed",
        content: apiResponse.message,
      );
    } else {
      final fbToken = apiResponse.body?["fb_token"];
      await FirebaseAuth.instance.signInWithCustomToken(fbToken);
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
      try {
        myLatLng = await getMyLatLng();
        notifyListeners();
        if (myLatLng != null) {
          Point earthCenterLocation = Point(
            latitude: 0.00,
            longitude: 0.00,
          );
          double earthDistance = GeoRange().distance(
            earthCenterLocation,
            Point(
              latitude: double.parse("${myLatLng?.lat ?? 9.7638}"),
              longitude: double.parse("${myLatLng?.lng ?? 118.7473}"),
            ),
          );
          ApiResponse apiResponse = await taxiRequest.syncLocationRequest(
            earthDistance: earthDistance,
            lat: double.parse("${myLatLng?.lat ?? 9.7638}"),
            lng: double.parse("${myLatLng?.lng ?? 118.7473}"),
            isMocked: false,
          );
          if (apiResponse.allGood) {
            debugPrint(
              "login syncLocationRequest success",
            );
          } else {
            throw apiResponse.message;
          }
        }
      } catch (e) {
        debugPrint(
          "login syncLocationRequest error: $e",
        );
      }
      Navigator.pushAndRemoveUntil(
        Get.overlayContext!,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
transitionDuration: Duration.zero,
pageBuilder: (context, a, b) => const HomeView(),
        ),
        (route) => false,
      );
    }
  }
}
