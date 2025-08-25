import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';

class SettingsViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();

  initialise() async {}

  logoutPressed() {
    AlertService().showAppAlert(
      title: "Are you sure?",
      content: "You're about to logout",
      hideCancel: false,
      confirmText: "Logout",
      confirmColor: Colors.red,
      confirmAction: () {
        Navigator.pop(Get.overlayContext!);
        processLogout();
      },
    );
  }

  processLogout() async {
    AlertService().showLoading();
    final apiResponse = await authRequest.logoutRequest();
    if (apiResponse.allGood) {
      await AuthService().logout();
    } else {
      AlertService().stopLoading();
      AlertService().showAppAlert(
        asset: AppLotties.error,
        title: "Logout Failed",
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
    }
  }
}
