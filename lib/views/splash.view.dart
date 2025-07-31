import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/view_models/splash.vm.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  SplashViewModel splashViewModel = SplashViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<SplashViewModel>.reactive(
      viewModelBuilder: () => splashViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
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
      },
    );
  }
}
