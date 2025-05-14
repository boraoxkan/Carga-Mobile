// File: ios/Runner/AppDelegate.swift

import UIKit
import Flutter
import GoogleMaps   // ← Mutlaka ekleyin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1) API anahtarınızı burada tanımlayın:
    GMSServices.provideAPIKey("AIzaSyBiyyUpZHM8MCdySX81OCyHFiLvRQJR7Q8")

    // 2) Flutter plugin’lerini kaydedin
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
