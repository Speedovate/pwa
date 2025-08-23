class Api {
  static String get baseUrl {
    return "https://ppctoda.com/api";
  }

  /// Config
  static const banners = "/banners";
  static const appConfigs = "/config/app";
  static const homeConfigs = "/config/home";

  /// Geo
  static const geoPolylines = "/geo/polylines";
  static const geoAddresses = "/geo/addresses";
  static const geoCoordinates = "/geo/coordinates";

  /// Load
  static const loadBuy = "/load/buy";
  static const loadBalance = "/load/balance";
  static const loadTransfer = "/load/transfer";
  static const loadTransactions = "/wallet/transactions";

  /// static const loadTransactions = "/load/transactions";

  /// Auth
  static const authUser = "/auth/user";
  static const authSend = "/auth/send";
  static const authCheck = "/auth/check";
  static const authPhone = "/auth/phone";
  static const authVerify = "/auth/verify";
  static const authSignUp = "/auth/signup";
  static const authSignIn = "/auth/signin";
  static const authUpdate = "/auth/update";
  static const authDelete = "/auth/delete";
  static const authSignOut = "/auth/signout";
  static const authForgot = "/auth/password/forgot";
  static const authChange = "/auth/password/change";

  /// Booking
  static const bookingRating = /*"/booking/rating" ??*/ "/rating";
  static const bookingOrders = /*"/booking/orders" ??*/ "/orders";
  static const bookingReport = /*"/booking/report" ??*/ "/report";
  static const bookingLast = /*"/booking/last/order" ??*/ "/taxi/last/order";
  static const bookingChat = /*"/booking/chat/notify" ??*/ "/chat/notification";
  static const bookingSubmit = /*"/booking/order/submit" ??*/
      "/taxi/book/order";
  static const bookingCancel = /*"/booking/orders/cancel" ??*/
      "/taxi/order/cancel";
  static const bookingCurrent = /*"/booking/current/order" ??*/
      "/taxi/current/order";
  static const bookingLocation = /*"/booking/location/sync" ??*/
      "/sync_location";
  static const bookingVehicles = /*"/booking/vehicle/types" ??*/
      "/vehicle/types";
  static const bookingDriverInfo = /*"/booking/driver/info" ??*/
      "/taxi/driver/info";
  static const bookingDriver = /*"/booking/current/order/driver" ??*/
      "/taxi/current/order_driver";
  static const bookingPricing = /*"/booking/vehicle/types/pricing" ??*/
      "/vehicle/types/pricing";
  static const bookingAvailability = /*"/booking/location/availability" ??*/
      "/taxi/location/available";

  static String get terms {
    final webUrl = baseUrl.replaceAll('/api', '');
    return "$webUrl/admin123456/pages/terms";
  }

  static String get contactUs {
    final webUrl = baseUrl.replaceAll('/api', '');
    return "$webUrl/admin123456/pages/contact";
  }

  static String get privacyPolicy {
    final webUrl = baseUrl.replaceAll('/api', '');
    return "$webUrl/admin123456/privacy/policy";
  }
}
