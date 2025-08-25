import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/verify.view.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/models/api_response.model.dart';

class SendViewModel extends BaseViewModel {
  AuthRequest authRequest = AuthRequest();
  var phoneTEC = TextEditingController();

  initialise() async {}

  sendCode(String purpose) async {
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
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.verifyPhoneAccount(
          phone: "+63${phoneTEC.text}",
        );
        AlertService().stopLoading();
        if (apiResponse.allGood) {
          processOTPVerification(purpose);
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
  }

  processOTPVerification(String purpose) async {
    try {
      ApiResponse apiResponse = await authRequest.sendOTP(
        type: "forgot_password",
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
        Navigator.push(
          Get.overlayContext!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                VerifyView(
              name: null,
              email: null,
              phone: phoneTEC.text,
              purpose: purpose,
              password: null,
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
      Navigator.push(
        Get.overlayContext!,
        PageRouteBuilder(
          reverseTransitionDuration: Duration.zero,
          transitionDuration: Duration.zero,
          pageBuilder: (
            context,
            a,
            b,
          ) =>
              VerifyView(
            name: null,
            email: null,
            phone: phoneTEC.text,
            purpose: purpose,
            password: null,
          ),
        ),
      );
    }
  }
}
