import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/login.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/api_response.model.dart';

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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
    } else if (cPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
          Navigator.popUntil(
            Get.overlayContext!,
            (route) => route.isFirst,
          );
          Navigator.push(
            Get.overlayContext!,
            PageRouteBuilder(
              reverseTransitionDuration: Duration.zero,
transitionDuration: Duration.zero,
pageBuilder: (context, a, b) => const LoginView(),
            ),
          );
          AlertService().showAppAlert(
            asset: AppLotties.success,
            title: "Forgot Password",
            content: "Your password has been changed",
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
    }
  }

  changePassword() async {
    if (passwordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
    } else if (nPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
    } else if (passwordTEC.text == nPasswordTEC.text) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
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
          AlertService().stopLoading();
          Navigator.pop(Get.overlayContext!);
          AlertService().showAppAlert(
            asset: AppLotties.success,
            title: "Change Password",
            content: "Your password has been changed",
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
    }
  }
}
