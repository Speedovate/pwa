import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/intro.view.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';

class ChangeViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var phoneTEC = TextEditingController();
  var passwordTEC = TextEditingController();
  var nPasswordTEC = TextEditingController();
  var cPasswordTEC = TextEditingController();

  initialise({
    required String phone,
  }) {
    phoneTEC.text = phone;
  }

  resetPassword() async {
    if (nPasswordTEC.text.isEmpty) {
      showError("Please enter your new password");
    } else if (nPasswordTEC.text.length < 6) {
      showError("Password must be at least 6 characters");
    } else if (cPasswordTEC.text.isEmpty) {
      showError("Please confirm your new password");
    } else if (cPasswordTEC.text != nPasswordTEC.text) {
      showError("Passwords entered do not match");
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.resetPasswordRequest(
          phone: "+63${phoneTEC.text}",
          password: nPasswordTEC.text,
        );
        if (apiResponse.allGood) {
          Get.offAll(
            () => const IntroView(),
            transition: Transition.noTransition,
            duration: Duration.zero,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.to(
              () => const LoginView(),
              transition: Transition.noTransition,
              duration: Duration.zero,
            );
            AlertService().showAppAlert(
              asset: AppLotties.success,
              title: "Forgot Password",
              content: "Your password has been changed",
              confirmAction: () {
                Get.back();
              },
            );
          });
        } else {
          throw apiResponse.message;
        }
      } catch (e) {
        AlertService().stopLoading(forceStop: true);
        showError(e);
      }
    }
  }

  changePassword() async {
    if (passwordTEC.text.isEmpty) {
      showError("Please enter your old password");
    } else if (passwordTEC.text.length < 6) {
      showError("Password must be at least 6 characters");
    } else if (nPasswordTEC.text.isEmpty) {
      showError("Please enter your new password");
    } else if (nPasswordTEC.text.length < 6) {
      showError("Password must be at least 6 characters");
    } else if (passwordTEC.text == nPasswordTEC.text) {
      showError("Please change your new password");
    } else if (cPasswordTEC.text.isEmpty) {
      showError("Please confirm your new password");
    } else if (cPasswordTEC.text != nPasswordTEC.text) {
      showError("Passwords entered do not match");
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.changePasswordRequest(
          password: passwordTEC.text,
          nPassword: nPasswordTEC.text,
          cPassword: cPasswordTEC.text,
        );
        if (apiResponse.allGood) {
          AlertService().stopLoading(forceStop: true);
          queueHomeDrawerDialog(
            title: "Change Password",
            content: "Your password has been changed",
          );
          Get.offAll(
            () => const HomeView(),
            transition: Transition.noTransition,
            duration: Duration.zero,
          );
        } else {
          throw apiResponse.message;
        }
      } catch (e) {
        AlertService().stopLoading(forceStop: true);
        showError(e);
      }
    }
  }
}
