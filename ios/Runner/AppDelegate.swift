import UIKit
import Flutter
import FirebaseCore
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    GMSServices.provideAPIKey("AIzaSyBulbBRV3toC3XWR9TRVACFTmjgfcsD0TU")
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("[PPC_NOTIF_DEBUG] \(Date().iso8601String) ios native willPresent id=\(notification.request.identifier) userInfo=\(notification.request.content.userInfo)")
    if notification.request.trigger is UNPushNotificationTrigger {
      super.userNotificationCenter(center, willPresent: notification) { _ in
        print("[PPC_NOTIF_DEBUG] \(Date().iso8601String) ios native forwarded remote foreground to flutter plugins")
      }
      print("[PPC_NOTIF_DEBUG] \(Date().iso8601String) ios native suppress remote foreground for flutter local render")
      completionHandler([])
      return
    }
    print("[PPC_NOTIF_DEBUG] \(Date().iso8601String) ios native present local notification")
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}

private extension Date {
  var iso8601String: String {
    ISO8601DateFormatter().string(from: self)
  }
}
