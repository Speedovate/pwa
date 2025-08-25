import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/views/verify.view.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/api_response.model.dart';

class RegisterViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var nameTEC = TextEditingController();
  var emailTEC = TextEditingController();
  var phoneTEC = TextEditingController();
  var passwordTEC = TextEditingController();
  var cPasswordTEC = TextEditingController();

  initialise() async {}

  processRegister() async {
    if (selfieFile == null && !AuthService.inReviewMode()) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please add a profile photo",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (nameTEC.text.trim().isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your full name",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (!nameRegex.hasMatch(nameTEC.text.trim())) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter correct full name",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (emailTEC.text.trim().isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter your email address",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (!emailRegex.hasMatch(emailTEC.text.trim())) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please enter a valid email address",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (phoneTEC.text.trim().isEmpty) {
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
    } else if (!phoneRegex.hasMatch(phoneTEC.text.trim())) {
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
    } else if (passwordTEC.text.trim().isEmpty) {
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
    } else if (passwordTEC.text.trim().length < 6) {
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
    } else if (cPasswordTEC.text.trim().isEmpty) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please confirm your password",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (cPasswordTEC.text.trim() != passwordTEC.text.trim()) {
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
    } else if (!agreed) {
      ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.overlayContext!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please agree to the terms of service",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.checkCredentialsExist(
          email: emailTEC.text.trim(),
          phone: "+63${phoneTEC.text.trim()}",
        );
        if (apiResponse.allGood) {
          processOTPVerification();
        } else {
          AlertService().stopLoading();
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
      } catch (e) {
        AlertService().stopLoading();
        ScaffoldMessenger.of(Get.overlayContext!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.overlayContext!,
        ).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "There was an error while processing"
              " your request. Please try again later",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  processOTPVerification() async {
    try {
      ApiResponse apiResponse = await authRequest.sendOTP(
        type: "register",
        phone: "+63${phoneTEC.text.trim()}",
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
            AlertService().stopLoading();
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
        AlertService().stopLoading();
        Navigator.push(
          Get.overlayContext!,
          MaterialPageRoute(
            builder: (context) => VerifyView(
              name: nameTEC.text.trim(),
              email: emailTEC.text.trim(),
              phone: phoneTEC.text.trim(),
              purpose: "register",
              password: passwordTEC.text.trim(),
            ),
          ),
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
