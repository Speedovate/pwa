import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Image.asset(
          AppImages.splash,
          width: MediaQuery.of(context).size.width / 1.3,
          height: MediaQuery.of(context).size.width / 1.3,
        ),
      ),
    );
  }
}
