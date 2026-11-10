import 'package:chat_messenger/services/deep_link_service.dart';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:chat_messenger/models/location.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'dialog_helper.dart';

abstract class AppHelper {
  ///
  /// App Helper Methods
  ///

  /// Generate unique ID.
  static String get generateID => const Uuid().v4();

  // Upload file to firebase storage
  static Future<String> uploadFile({
    required File file,
    required String userId,
  }) async {
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    // File name with unique prefix
    final String fileName = '${generateID}_${path.basename(file.path)}';

    final String ext = path.extension(file.path).toLowerCase();
    String? mimeType;
    if (ext == '.png') {
      mimeType = 'image/png';
    } else if (ext == '.jpg' || ext == '.jpeg') {
      mimeType = 'image/jpeg';
    } else if (ext == '.mp4') {
      mimeType = 'video/mp4';
    }

    final SettableMetadata? metadata =
        mimeType != null ? SettableMetadata(contentType: mimeType) : null;

    // Upload file
    final UploadTask uploadTask = FirebaseStorage.instance
        .ref()
        .child('uploads/$userId/$fileName')
        .putFile(file, metadata);

    debugPrint('AppHelper.uploadFile: uploading uploads/$userId/$fileName (${await file.length()} bytes)');
    final TaskSnapshot snapshot =
        await uploadTask.timeout(const Duration(seconds: 45));
    final String url = await snapshot.ref.getDownloadURL();
    debugPrint('AppHelper.uploadFile: upload finished -> $url');
    return url;
  }

  static Future<void> deleteFile(String fileUrl) async {
    try {
      await FirebaseStorage.instance.refFromURL(fileUrl).delete();
      debugPrint('deleteFile() -> success, fileUrl: $fileUrl');
    } catch (e) {
      debugPrint('deleteFile() -> error: $e');
    }
  }

  // Delete the storage files by path
  static Future<void> deleteStorageFiles(String path) async {
    try {
      final ListResult listResult =
          await FirebaseStorage.instance.ref().child(path).listAll();
      final List<Future<void>> references =
          listResult.items.map((e) => e.delete()).toList();
      // Check result
      if (references.isNotEmpty) {
        await Future.wait(references);
        debugPrint('deleteStorageFiles() -> success');
        return;
      }
      debugPrint('deleteStorageFiles() -> no files');
    } catch (e) {
      debugPrint('deleteStorageFiles() -> error: $e');
    }
  }



  static Future<void> downloadFile(String fileUrl) async {
    // Show "Saved" in the center immediately for 1 second
    Get.dialog(
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Material(
            color: Colors.transparent,
            child: Text(
              'Saved',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });

    // Run the actual download asynchronously so it doesn't block the UI thread
    Future.microtask(() async {
      try {
        final String fileName = MediaHelper.getFirebaseFileName(fileUrl);
        
        final Directory tempDir = await getTemporaryDirectory();
        final String savePath = '${tempDir.path}/$fileName';
        final File file = File(savePath);

        final request = http.Request('GET', Uri.parse(fileUrl));
        final response = await http.Client().send(request);

        if (response.statusCode == 200) {
          final sink = file.openWrite();
          await response.stream.pipe(sink);
          await sink.close();

          // Save to Gallery
          await ImageGallerySaverPlus.saveFile(savePath);
          
          // Cleanup temp file
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('downloadFile() -> error: $e');
      }
    });
  }

  // Clean the username
  static String sanitizeUsername(String text) {
    return text.trim().replaceAll(' ', '_').toLowerCase();
  }

  static String? usernameValidator(String? username) {
    if (username == null || username.trim().isEmpty) {
      return "enter_your_username".tr;
    }
    return null;
  }

  // Format the username
  static List<TextInputFormatter> get usernameFormatter {
    return [
      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9._]')),
      TextInputFormatter.withFunction((oldValue, newValue) {
        return TextEditingValue(
          text: sanitizeUsername(newValue.text),
          selection: newValue.selection,
        );
      }),
    ];
  }

  static Future<Location?> getUserCurrentLocation() async {
    LocationPermission permission;

    DialogHelper.showProcessingDialog(
      barrierDismissible: false,
    );

    // Check location services are enabled.
    if (!await Geolocator.isLocationServiceEnabled()) {
      DialogHelper.closeDialog();

      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, 'location_services_are_disabled'.tr);
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        DialogHelper.closeDialog();

        DialogHelper.showAlertDialog(
          titleColor: errorColor,
          title: Text('permission_denied'.tr),
          content: Text('location_permission_denied'.tr),
          actionText: 'open_settings'.tr,
          action: () {
            Get.back();
            Geolocator.openLocationSettings();
          },
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      DialogHelper.closeDialog();

      DialogHelper.showAlertDialog(
        titleColor: errorColor,
        title: Text('permission_denied'.tr),
        content: Text('location_permission_denied'.tr),
        actionText: 'open_settings'.tr,
        action: () {
          Get.back();
          Geolocator.openLocationSettings();
        },
      );

      return null;
    }
    // When we reach here, permissions are granted.
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    DialogHelper.closeDialog();

    return Location(latitude: position.latitude, longitude: position.longitude);
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'please_enter_your_password'.tr;
    } else if (value.length < 6) {
      return 'password_must_have_at_least_6_characters'.tr;
    }
    return null;
  }

  // Get Store URL => Google Play / App Store
  static Future<String> getStoreUrl() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName.isNotEmpty
          ? packageInfo.packageName
          : AppConfig.androidPackageName;
      if (Platform.isAndroid) {
        return "https://play.google.com/store/apps/details?id=$packageName";
      } else {
        return "https://apps.apple.com/app/id${AppConfig.iOsAppId}";
      }
    } catch (_) {
      if (Platform.isAndroid) {
        return "https://play.google.com/store/apps/details?id=${AppConfig.androidPackageName}";
      }
      return "https://apps.apple.com/app/id${AppConfig.iOsAppId}";
    }
  }

  /// Share app with friends
  static Future<void> shareApp() async {
    try {
      final String username = AuthController.instance.currentUser.fullname;
      final String storeUrl = await getStoreUrl();

      final String shareText = 'invite_friend_message'.trParams({
        'appName': AppConfig.appName,
        'username': username,
        'storeName': Platform.isAndroid ? 'Google Play' : 'App Store',
        'storeUrl': storeUrl,
      });

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      debugPrint('shareApp() -> error: $e');
    }
  }

  /// Rate app on Google Play / App Store
  static Future<void> rateApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName.isNotEmpty
          ? packageInfo.packageName
          : AppConfig.androidPackageName;

      if (Platform.isAndroid) {
        final Uri marketUri = Uri.parse("market://details?id=$packageName");
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return;
        }
        final String webUrl = "https://play.google.com/store/apps/details?id=$packageName";
        await openUrl(webUrl);
      } else if (Platform.isIOS) {
        final Uri iosMarketUri = Uri.parse("itms-apps://itunes.apple.com/app/id${AppConfig.iOsAppId}?action=write-review");
        if (await canLaunchUrl(iosMarketUri)) {
          await launchUrl(iosMarketUri, mode: LaunchMode.externalApplication);
          return;
        }
        final String webUrl = "https://apps.apple.com/app/id${AppConfig.iOsAppId}?action=write-review";
        await openUrl(webUrl);
      }
    } catch (e) {
      debugPrint('rateApp() -> error: $e');
      final storeUrl = await getStoreUrl();
      await openUrl(storeUrl);
    }
  }

  /// Open email app to contact support
  static Future<void> openMailApp(String subject) =>
      openUrl("mailto:${AppConfig.appEmail}?subject=$subject");

  static Future<void> openMessageApp(String phoneNumber, String message) async {
  final Uri smsUri = Uri(
    scheme: 'sms',
    path: phoneNumber, // The phone number to which the message will be sent
    query: 'body=$message', // Pre-fills the message body
  );

  if (await canLaunchUrl(smsUri)) {
    await launchUrl(smsUri);
  } else {
    throw 'Could not open the messaging app';
  }
}
  /// Open Terms of Services page in Browser
  static Future<void> openTermsPage() => openUrl(AppConfig.termsOfServiceUrl);

  /// Open Privacy Policy page in Browser
  static Future<void> openPrivacyPage() async {
    // Get Privacy URL
    final Uri uri = Uri.parse(AppConfig.privacyPolicyUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw "Could not launch url: $uri";
    }
  }

  static Future<void> openGoogleMaps(double latitude, double longitude) async {
    final String mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    await openUrl(mapsUrl).onError(
      (error, stackTrace) => DialogHelper.showSnackbarMessage(
          SnackMsgType.error, 'failed_to_open_the_google_maps_url'),
    );
  }

  // Open Link (with in-app deep link interception)
  static Future<void> openUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url.trim());
      final parsed = DeepLinkService.parseDeepLink(uri);
      if (parsed != null) {
        await DeepLinkService.executeDeepLinkAction(parsed['type']!, parsed['id']!);
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch url: $url');
      }
    } catch (e) {
      debugPrint('openUrl() -> error: $e');
    }
  }
}

extension UsernameFormatter on String {
  /// Format the username by truncating to 20 characters and adding ".."
  String get formattedUsername {
    if (length > 20) {
      return '${substring(0, 20)}..';
    }
    return this;
  }
}
