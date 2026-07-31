import 'package:get/get.dart';
import '../services/global_settings_service.dart';

abstract class AppConfig {
  ///
  /// <-- CONFIG OF CONSTANT VALUES -->
  ///

  /// App Name
  static const String appName = "imChat";

  /// Email for Support
  static const String appEmail = "imchat@gmail.com";

  /// App Version is displayed in settings > "About us" page.
  static const String appVersion = "Android v1.0.0 - iOS v1.0.0";

  // App identifiers used to share the app and rate it on Google Play/App Store.
  static const String iOsAppId = "1:518076067996:ios:922434d04be0323ca3fd59";
  static const String androidPackageName = "com.imchatappcompany.appname";

  /// Privacy Policy Link:
  static const String privacyPolicyUrl = "https://www.yoursite.com/privacy";

  /// Terms of Service Link:
  static const String termsOfServiceUrl = "https://www.yoursite.com/terms";

  ///
  ///  <-- Video & Voice call features -->
  ///
  static String get agoraAppID {
    try {
      final settingsService = Get.find<GlobalSettingsService>();
      final val = settingsService.agoraAppId.value;
      return val.isNotEmpty ? val : "c74eafbb98784225bae6be9b7e7f6225";
    } catch (e) {
      return "c74eafbb98784225bae6be9b7e7f6225";
    }
  }

  ///
  ///  <-- GIF API KEY -->
  /// TODO: Get your GIF_API_KEY at: https://developers.giphy.com/dashboard
  ///
  static const String gifAPiKey = "YOUR_GIF_API_KEY";

  //
  // <-- GOOGLE ADMOB IDS - Section -->
  //

  //
  // <-- Android Platform -->
  //
  // TODO: Add your Android AD Unit IDs
  static const String androidBannerID = "Your-Android-Banner-ID";
  static const String androidInterstitialID = "Your-Android-Interstitial-ID";

  //
  // <-- IOS Platform -->
  //
  // TODO: Add your iOS AD Unit IDs
  static const String iOsBannerID = "Your-iOS-Banner-ID";
  static const String iOsInterstitialID = "Your-iOS-Interstitial-ID";
}


