import 'package:get/get.dart';
import 'package:pwa/views/home.view.dart';
import 'package:stacked/stacked.dart';

class HomeViewModel extends BaseViewModel {
  Future<void> initialise() async {
    await goToNextPage();
  }

  goToNextPage() async {
    await Future.delayed(
      const Duration(
        seconds: 5,
      ),
    );
    Get.offAll(() => const HomeView());
  }
}
