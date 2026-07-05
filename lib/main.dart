import 'package:get/get.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/views/splash.view.dart';
import 'package:pwa/services/push.service.dart';
import 'package:pwa/services/startup.service.dart';
import 'package:pwa/services/connection_banner.service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StartupService.waitForFirebaseReady();
  await StartupService.ensurePrefsReady();
  await loadNotificationDiagnosticsLog();
  await SystemChrome.setPreferredOrientations(
    const [
      DeviceOrientation.portraitUp,
    ],
  );
  ConnectionBannerService.setSupportDialogHandler((_) async {
    final context = Get.context;
    if (context == null) {
      return;
    }
    await showFacebookSupportDialog(context);
  });
  try {
    await PushService.initialize();
  } catch (_) {}
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
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              ConnectionBannerService.buildOverlay(),
            ],
          ),
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
