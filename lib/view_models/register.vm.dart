import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/views/verify.view.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterViewModel extends BaseViewModel {
  bool isBirthdayActive = false;
  DateTime selectedDate = DateTime.now();
  AuthRequest authRequest = AuthRequest();
  var nameTEC = TextEditingController();
  var emailTEC = TextEditingController();
  var phoneTEC = TextEditingController();
  var birthdayTEC = TextEditingController();
  var referralTEC = TextEditingController();
  var passwordTEC = TextEditingController();
  var cPasswordTEC = TextEditingController();

  initialise() async {
    try {
      await PushService.syncTokenWithServer(requestPermission: true);
    } catch (_) {}
  }

  processRegister({
    String provider = "custom",
  }) async {
    if (selfieFile == null && !AuthService.inReviewMode()) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (nameTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" && emailTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (birthdayTEC.text.trim().isEmpty || isBirthdayActive) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Please set your birthday",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (provider == "custom" &&
        !emailRegex.hasMatch(emailTEC.text.trim())) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" && phoneTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" &&
        !phoneRegex.hasMatch(phoneTEC.text.trim())) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" && passwordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" && passwordTEC.text.trim().length < 6) {
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
    } else if (provider == "custom" && cPasswordTEC.text.isEmpty) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
    } else if (provider == "custom" &&
        cPasswordTEC.text.trim() != passwordTEC.text.trim()) {
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
    } else if (!agreed) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
      late ApiResponse apiResponse;
      try {
        String? emailAddress;
        GoogleSignInAccount? gsiAccount;
        GoogleSignInAuthentication? auth;
        if (provider == "custom") {
          apiResponse = await authRequest.checkCredentialsExist(
            email: emailTEC.text.trim(),
            phone: "+63${phoneTEC.text.trim()}",
          );
        } else {
          final gsi = GoogleSignIn(
            clientId:
                "599344409686-e8colg5jkq3o8qkrvpf8ri4r18pjuqb5.apps.googleusercontent.com",
            scopes: [
              'email',
              'profile',
              'openid',
            ],
          );
          gsiAccount = await gsi.signInSilently();
          gsiAccount ??= await gsi.signIn();
          auth = await gsiAccount?.authentication;
          if (auth?.idToken != null) {
            final payload = parseJwt(auth!.idToken!);
            emailAddress = payload['email'];
          } else {
            emailAddress = gsiAccount?.email;
          }
          if (emailAddress == null) {
            throw Exception("An error occurred. Please try again");
          }
          apiResponse = await authRequest.checkCredentialsExist(
            email: emailAddress,
            phone: "+63008891",
          );
        }
        if (apiResponse.allGood) {
          if (provider == "custom") {
            processOTPVerification();
          } else {
            processGoogleRegister(
              auth?.accessToken,
              auth?.idToken,
              emailAddress,
            );
          }
        } else {
          AlertService().stopLoading(forceStop: true);
          showError(apiResponse.message);
        }
      } catch (e) {
        AlertService().stopLoading(forceStop: true);
        showError(
          "There was an error while processing your request. Please try again later",
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
            AlertService().stopLoading(forceStop: true);
            ScaffoldMessenger.of(Get.context!).clearSnackBars();
            ScaffoldMessenger.of(
              Get.context!,
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
        AlertService().stopLoading(forceStop: true);
        Navigator.push(
          Get.context!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                VerifyView(
              purpose: "register",
              name: nameTEC.text.trim(),
              email: emailTEC.text.trim(),
              phone: phoneTEC.text.trim(),
              birthday: birthdayTEC.text.trim(),
              referral: referralTEC.text.trim(),
              password: passwordTEC.text.trim(),
            ),
          ),
        );
      } else {
        throw apiResponse.message;
      }
    } catch (e) {
      AlertService().stopLoading(forceStop: true);
      if (lowerCase(e.toString()).contains("otp")) {
        Navigator.push(
          Get.context!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                VerifyView(
              purpose: "register",
              name: nameTEC.text.trim(),
              email: emailTEC.text.trim(),
              phone: phoneTEC.text.trim(),
              birthday: birthdayTEC.text.trim(),
              referral: referralTEC.text.trim(),
              password: passwordTEC.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(Get.context!).clearSnackBars();
        ScaffoldMessenger.of(
          Get.context!,
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

  processGoogleRegister(
    String? accessToken,
    String? idToken,
    String? email,
  ) async {
    try {
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await finishGoogleRegistration(
        idToken,
        email,
      );
      AlertService().stopLoading(forceStop: true);
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? e.code);
    } on SocketException {
      showError("No internet connection. Please try again.");
    } on TimeoutException {
      showError("Request timed out. Please try again later.");
    } catch (e) {
      showError(
        e.toString().contains("null")
            ? "An error occurred. Try again later"
            : e.toString(),
      );
    } finally {
      AlertService().stopLoading(forceStop: true);
    }
  }

  finishGoogleRegistration(
    String? idToken,
    String? email,
  ) async {
    try {
      ApiResponse apiResponse = await authRequest.gRegisterRequest(
        email: "$email",
        countryCode: "PH",
        phone: "+63008891",
        password: "password",
        code: referralTEC.text,
        firebaseIdToken: "$idToken",
        birthday: birthdayTEC.text.trim(),
        name: capitalizeWords(nameTEC.text.trim()),
        lat: double.parse("${initLatLng?.lat ?? 9.7638}"),
        lng: double.parse("${initLatLng?.lng ?? 118.7473}"),
      );
      if (apiResponse.hasError()) {
        AlertService().stopLoading(forceStop: true);
        AlertService().showAppAlert(
          asset: AppLotties.error,
          title: "Registration Failed",
          content: apiResponse.message,
        );
      } else {
        final fbToken = apiResponse.body?["fb_token"];
        try {
          await FirebaseAuth.instance.signInWithCustomToken(fbToken);
        } catch (e) {
          throw e.toString();
        }
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
        await PushService.syncTokenWithServer(requestPermission: true);
        Navigator.pushAndRemoveUntil(
          Get.context!,
          PageRouteBuilder(
            reverseTransitionDuration: Duration.zero,
            transitionDuration: Duration.zero,
            pageBuilder: (
              context,
              a,
              b,
            ) =>
                const HomeView(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      AlertService().stopLoading(forceStop: true);
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(
        Get.context!,
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
