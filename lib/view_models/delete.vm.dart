import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
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
      showError("Please enter your password");
    } else if (passwordTEC.text.length < 6) {
      showError("Password must be at least 6 characters");
    } else if (reasonTEC.text.isEmpty) {
      showError("Please enter your reason");
    } else if (reasonTEC.text.length < 6) {
      showError("Please tell us your reason");
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
              return;
            } else {
              throw apiResponse.message;
            }
          } catch (e) {
            if (!AuthService.isLoggedIn()) {
              return;
            }
            AlertService().stopLoading();
            showError(e);
          }
        },
      );
    }
  }
}
