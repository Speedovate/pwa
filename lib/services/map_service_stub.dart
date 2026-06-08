class MapService {
  static bool get shouldAttemptGoogleMaps => true;
  static bool get isLeafletFallbackPreferred => false;

  static bool? get initialEngineDecision => true;
  static bool get isGoogleMapsLoaded => true;

  static Future<bool> ensureGoogleMapsReady() async {
    return true;
  }

  static Future<void> warmUpPreferredMapEngine() async {}
}
