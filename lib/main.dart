import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pwa/views/splash.view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/services/storage.service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA3tvPnJN8hy3HksAFLDkMHDAC6wMeXS-Q",
      authDomain: "toda-pal.firebaseapp.com",
      databaseURL:
          "https://toda-pal-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "toda-pal",
      storageBucket: "toda-pal.firebasestorage.app",
      messagingSenderId: "599344409686",
      appId: "1:599344409686:web:ae1f18c90ac11007675ff7",
    ),
  );
  await StorageService.getPrefs();
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {});
  runApp(
    const MyApp(),
  );
  unawaited(
    PushService.initialize(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'PPC TODA (Beta)',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        var mediaQuery = MediaQuery.of(
          context,
        );
        var textScaleFactor = 1.0;
        return MediaQuery(
          data: mediaQuery.copyWith(
            padding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            textScaler: TextScaler.linear(
              textScaleFactor,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashView(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.blueAccent,
        ),
      ),
    );
  }
}
