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
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your new password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (nPasswordTEC.text.length < 6) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (cPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please confirm your new password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (cPasswordTEC.text != nPasswordTEC.text) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Passwords entered do not match",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
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
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.to(
              () => const LoginView(),
              transition: Transition.noTransition,
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
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your old password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (passwordTEC.text.length < 6) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (nPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your new password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (nPasswordTEC.text.length < 6) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (passwordTEC.text == nPasswordTEC.text) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please change your new password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (cPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please confirm your new password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (cPasswordTEC.text != nPasswordTEC.text) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Passwords entered do not match",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
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
