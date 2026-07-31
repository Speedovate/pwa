import 'dart:io';
import 'dart:async';
import 'dart:convert';
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
import 'package:pwa/services/google_auth.service.dart';
import 'package:pwa/requests/taxi.request.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pwa/models/api_response.model.dart';

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
      showError("Please enter your phone number");
    } else if (!phoneRegex.hasMatch(phoneTEC.text)) {
      showError("Please enter a valid phone number");
    } else if (passwordTEC.text.isEmpty) {
      showError("Please enter your password");
    } else if (passwordTEC.text.length < 6) {
      showError("Password must be at least 6 characters");
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
        showError(e);
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
      final googleAuth = await GoogleAuthService.signIn();
      AlertService().showLoading();
      final verifiedIdToken = googleAuth.idToken;
      if (!googleAuth.alreadySignedInToFirebase) {
        final credential = GoogleAuthProvider.credential(
          idToken: verifiedIdToken,
          accessToken: googleAuth.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      final apiResponse = await authRequest.googleLoginRequest(
        email: googleAuth.email,
        idToken: verifiedIdToken,
      );
      if (apiResponse.allGood) {
        await handleDeviceLogin(apiResponse);
      } else {
        throw apiResponse.message;
      }
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? e.code);
    } on SocketException catch (e) {
      showError(e.message.isNotEmpty ? e.message : e);
    } on TimeoutException catch (e) {
      showError(e.message ?? e);
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
        content: cleanErrorMessage(apiResponse.message),
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
