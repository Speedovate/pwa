import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:georange/georange.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/home.view.dart';
import 'package:pwa/constants/lotties.dart';
import 'package:pwa/constants/strings.dart';
import 'package:pwa/requests/auth.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/map.service.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginViewModel extends BaseViewModel {
  TaxiRequest taxiRequest = TaxiRequest();
  AuthRequest authRequest = AuthRequest();
  var phoneTEC = TextEditingController();
  var passwordTEC = TextEditingController();

  initialise() async {
    try {
      await PushService.syncTokenWithServer(requestPermission: false);
    } catch (_) {}
  }

  processPhoneLogin() async {
    if (phoneTEC.text.isEmpty) {
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
    } else if (!phoneRegex.hasMatch(phoneTEC.text)) {
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
    } else if (passwordTEC.text.isEmpty) {
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
    } else {
      AlertService().showLoading();
      try {
        ApiResponse apiResponse = await authRequest.phoneLoginRequest(
          phone: phoneTEC.text,
          password: passwordTEC.text,
        );
        await handleDeviceLogin(apiResponse);
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

  processGoogleLogin() async {
    if (!isGoogleAuthLikelySupported()) {
      showError(
        "Google sign-in is not supported on this browser. Please use phone login instead.",
      );
      return;
    }
    try {
      String? emailAddress;
      GoogleSignInAccount? gsiAccount;
      GoogleSignInAuthentication? auth;
      AlertService().showLoading();
      final gsi = GoogleSignIn(
        clientId: kIsWeb
            ? "599344409686-e8colg5jkq3o8qkrvpf8ri4r18pjuqb5.apps.googleusercontent.com"
            : null,
        scopes: [
          'email',
          'profile',
          'openid',
        ],
      );
      gsiAccount = await gsi.signInSilently();
      if (gsiAccount == null) {
        if (kIsWeb) {
          gsiAccount = await gsi.signInSilently(
            suppressErrors: false,
            reAuthenticate: true,
          );
        } else {
          gsiAccount = await gsi.signIn();
        }
      }
      auth = await gsiAccount?.authentication;
      if (auth?.idToken != null) {
        final payload = parseJwt(auth!.idToken!);
        emailAddress = payload['email'];
      } else {
        emailAddress = gsiAccount?.email;
      }
      if (gsiAccount == null) {
        throw StateError("Google sign-in was cancelled.");
      }
      if (emailAddress == null) {
        throw StateError(
          "Google sign-in did not return an email address. Please choose a Google account with an email.",
        );
      }
      if (auth?.idToken == null) {
        throw StateError(
          "Google sign-in did not return an ID token. Please try again or use phone login.",
        );
      }
      final verifiedIdToken = auth!.idToken!;
      final credential = GoogleAuthProvider.credential(
        idToken: verifiedIdToken,
        accessToken: auth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      final apiResponse = await authRequest.googleLoginRequest(
        email: emailAddress,
        idToken: verifiedIdToken,
      );
      if (apiResponse.allGood) {
        await handleDeviceLogin(apiResponse);
      } else {
        throw Exception(apiResponse.message);
      }
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? e.code);
    } on SocketException {
      showError("No internet connection. Please try again.");
    } on TimeoutException {
      showError("Request timed out. Please try again later.");
    } catch (e) {
      showError(
        googleAuthErrorMessage(
          e,
          isSignUp: false,
        ),
      );
    } finally {
      AlertService().stopLoading(forceStop: true);
    }
  }

  handleDeviceLogin(ApiResponse apiResponse) async {
    if (apiResponse.hasError()) {
      AlertService().stopLoading(forceStop: true);
      AlertService().showAppAlert(
        asset: AppLotties.error,
        title: "Login Failed",
        content: apiResponse.message,
      );
    } else {
      final fbToken = apiResponse.body?["fb_token"];
      await FirebaseAuth.instance.signInWithCustomToken(fbToken);
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
      await AppStrings.getAppSettingsFromStorage();
      await AuthService.ensureUserNameInFirestore();
      await PushService.syncTokenWithServer(requestPermission: false);
      await MapService.warmUpPreferredMapEngine();
      notifyListeners();
      try {
        Point earthCenterLocation = Point(
          latitude: 0.00,
          longitude: 0.00,
        );
        double earthDistance = GeoRange().distance(
          earthCenterLocation,
          Point(
            latitude: double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
            longitude: double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
          ),
        );
        ApiResponse apiResponse = await taxiRequest.syncLocationRequest(
          earthDistance: earthDistance,
          lat: double.parse("${initLatLng?.lat ?? defaultLatLng.lat}"),
          lng: double.parse("${initLatLng?.lng ?? defaultLatLng.lng}"),
          isMocked: false,
        );
        if (apiResponse.allGood) {
        } else {
          throw apiResponse.message;
        }
      } catch (e) {
        // Location sync is best-effort after login.
      }
      AlertService().stopLoading(forceStop: true);
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
  }
}
