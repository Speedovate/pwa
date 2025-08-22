import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:pwa/views/intro.view.dart';

class SplashViewModel extends BaseViewModel {
  Future<void> initialise() async {
    await goToNextPage();
  }

  goToNextPage() async {
    await Future.delayed(
      const Duration(
        seconds: 5,
      ),
    );
    Get.offAll(() => const IntroView());
  }
}
