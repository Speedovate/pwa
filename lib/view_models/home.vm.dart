import 'dart:async';
import 'package:pwa/view_models/gmap.vm.dart';
import 'package:pwa/view_models/load.vm.dart';


class HomeViewModel extends GMapViewModel {
  Future<void> initialise() async {
    LoadViewModel().getLoadBalance();
  }
}
