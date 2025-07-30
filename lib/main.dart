import 'package:flutter/material.dart';
import 'package:pwa/views/splash.view.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBp6_fzqtLoGmIeSyg3vtrHyJJfxVg902c",
      authDomain: "ppc-toda.firebaseapp.com",
      databaseURL:
          "https://ppc-toda-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "ppc-toda",
      storageBucket: "ppc-toda.firebasestorage.app",
      messagingSenderId: "462080229186",
      appId: "1:462080229186:web:be7b5e37e13c33e09392db",
      measurementId: "G-30S1M2THQW",
    ),
  );
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PPC TODA',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        var mediaQuery = MediaQuery.of(
          context,
        );
        var textScaleFactor = 1.0;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              textScaleFactor,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashView(),
    );
  }
}
