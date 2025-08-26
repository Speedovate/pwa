import 'dart:async';
import 'package:pwa/utils/data.dart';
import 'package:pwa/view_models/gmap.vm.dart';
import 'package:pwa/view_models/load.vm.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/services/storage.service.dart';

class HomeViewModel extends GMapViewModel {
  Future<void> initialise() async {
    isAdSeen = StorageService.prefs?.getBool("is_ad_seen") ?? !AuthService.isLoggedIn();
    notifyListeners();
    if (AuthService.isLoggedIn()) {
      LoadViewModel().getLoadBalance();
    }
    notifyListeners();
  }
}
