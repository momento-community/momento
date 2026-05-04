import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps iOS SDK key. Read from GOOGLE_MAPS_KEY_IOS env injected at
    // build time (xcconfig / `flutter build ipa --dart-define-from-file=...`)
    // or fall back to the Info.plist `GMSApiKey` entry if present. When unset,
    // map screens render a watermarked dev surface. See CLAUDE.md.
    let key = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String) ?? ""
    if !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
