import 'package:rx_shared_preferences/rx_shared_preferences.dart';

class StorageService {
  static SharedPreferences? prefs;
  static RxSharedPreferences? rxPrefs;

  static Future<SharedPreferences> getPrefs() async {
    if (prefs == null) {
      prefs = await SharedPreferences.getInstance();
      rxPrefs = RxSharedPreferences(prefs!, null);
    }
    return prefs!;
  }
}
