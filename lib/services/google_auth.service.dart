import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.email,
    required this.idToken,
    this.accessToken,
    this.alreadySignedInToFirebase = false,
  });

  final String email;
  final String idToken;
  final String? accessToken;
  final bool alreadySignedInToFirebase;
}

class GoogleAuthService {
  GoogleAuthService._();

  static const String webClientId =
      '599344409686-e8colg5jkq3o8qkrvpf8ri4r18pjuqb5.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? webClientId : null,
    scopes: const [
      'email',
      'profile',
      'openid',
    ],
  );

  static GoogleSignIn get instance => _googleSignIn;

  static Future<GoogleAuthResult> signIn() async {
    if (kIsWeb) {
      return _signInWithPopup();
    }

    final account =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    final auth = await account?.authentication;
    final email = account?.email;
    final idToken = auth?.idToken;

    if (account == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    if (email == null || email.isEmpty) {
      throw StateError(
        'Google sign-in did not return an email address. Please choose a Google account with an email.',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google sign-in did not return an ID token. Please try again or use phone login.',
      );
    }

    return GoogleAuthResult(
      email: email,
      idToken: idToken,
      accessToken: auth?.accessToken,
    );
  }

  static Future<GoogleAuthResult> _signInWithPopup() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    provider.addScope('openid');

    final userCredential =
        await FirebaseAuth.instance.signInWithPopup(provider);
    final credential = userCredential.credential;
    final email = userCredential.user?.email;
    final idToken = credential is OAuthCredential ? credential.idToken : null;
    final accessToken =
        credential is OAuthCredential ? credential.accessToken : null;

    if (email == null || email.isEmpty) {
      throw StateError(
        'Google sign-in did not return an email address. Please choose a Google account with an email.',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google sign-in did not return an ID token. Please try again or use phone login.',
      );
    }

    return GoogleAuthResult(
      email: email,
      idToken: idToken,
      accessToken: accessToken,
      alreadySignedInToFirebase: true,
    );
  }
}
