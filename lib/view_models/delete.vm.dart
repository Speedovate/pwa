import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/api_response.model.dart';

class DeleteViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var reasonTEC = TextEditingController();
  var passwordTEC = TextEditingController();

  initialise() {}

  processAccountDeletion() async {
    if (passwordTEC.text.isEmpty) {
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
    } else if (reasonTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your reason",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (reasonTEC.text.length < 6) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please tell us your reason",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      AlertService().showAppAlert(
        title: "Are you sure?",
        content: "You're about to delete your account",
        hideCancel: false,
        confirmText: "Delete",
        confirmColor: Colors.red,
        confirmAction: () async {
          Get.back();
          AlertService().showLoading();
          try {
            ApiResponse apiResponse = await authRequest.deleteProfile(
              password: passwordTEC.text,
              reason: reasonTEC.text,
            );
            if (apiResponse.allGood) {
              await AuthService().logout();
              AlertService().showAppAlert(
                asset: AppLotties.success,
                title: "Account Deleted",
                content: "Your account has been deleted",
              );
            } else {
              throw apiResponse.message;
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
        },
      );
    }
  }
}
