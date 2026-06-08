import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:pwa/utils/data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pwa/firebase_options.dart';
import 'package:pwa/views/splash.view.dart';
import 'package:pwa/services/push.service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pwa/services/storage.service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await StorageService.getPrefs();
  if (!kIsWeb) {
    try {
      cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      cameras = null;
    }
  }
  await SystemChrome.setPreferredOrientations(
    const [
      DeviceOrientation.portraitUp,
    ],
  );
  await PushService.initialize();
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Set<PointerDeviceKind> get _dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.blueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(24, 0, 24, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8),
            ),
          ),
          contentTextStyle: TextStyle(
            color: Colors.white,
          ),
          actionTextColor: Colors.white,
        ),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: _dragDevices,
      ),
    );
  }
}
