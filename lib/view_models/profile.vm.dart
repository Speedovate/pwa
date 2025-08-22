import 'dart:convert';
import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';

class ProfileViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();

  initialise() async {}

  Future<void> processUpdate() async {
    AlertService().showLoading();
    try {
      final apiResponse = await authRequest
          .updateProfile(
            photo: selfieFile,
            name: AuthService.currentUser?.name,
            email: AuthService.currentUser?.email,
            phone: AuthService.currentUser?.phone,
            countryCode: AuthService.currentUser?.countryCode,
          )
          .timeout(
            const Duration(
              seconds: 30,
            ),
          );
      if (apiResponse.allGood) {
        await AuthService().saveUserToStorage(
          jsonEncode(
            apiResponse.body?["user"],
          ),
        );
        await AuthService.getUserFromStorage();
        Get.forceAppUpdate();
      }
      AlertService().stopLoading();
      AlertService().showAppAlert(
        asset: apiResponse.allGood ? AppLotties.success : AppLotties.error,
        title: "Profile Update",
        content: apiResponse.message.toString().toLowerCase().contains("dio") ||
                apiResponse.message
                    .toString()
                    .toLowerCase()
                    .contains("firebase") ||
                apiResponse.message
                    .toString()
                    .toLowerCase()
                    .contains("internal")
            ? "There was an error while processing"
                " your request. Please try again later"
            : apiResponse.message,
      );
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
