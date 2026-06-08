import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/constants/images.dart';
import 'package:pwa/view_models/splash.vm.dart';
import 'package:pwa/widgets/network_image.widget.dart';

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
        final mediaQuery = MediaQuery.of(context);
        final isLandscape = mediaQuery.size.width > mediaQuery.size.height;
        final double imageSize = isLandscape
            ? (mediaQuery.size.height / 2.1).clamp(0, 350).toDouble()
            : (mediaQuery.size.width / 1.3).clamp(0, 350).toDouble();
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: NetworkImageWidget(
              imageUrl: AppImages.splash,
              memCacheWidth: 600,
              width: imageSize,
              height: imageSize,
            ),
          ),
        );
      },
    );
  }
}
