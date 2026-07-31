


import 'dart:io';

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/wallet_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/preferences_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/screens/languages/languages_screen.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

import 'components/basic_info.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Vars
    final PreferencesController prefController = Get.find();
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final Color? iconColor = isDarkMode ? primaryColor : null;
    final User currentUser = AuthController.instance.currentUser;
    final themeService = Get.find<AppThemeService>();

    return Obx(() {
      return Container(
        decoration: themeService.getScreenBgUrl('profile') != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(themeService.getScreenBgUrl('profile')!),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: Scaffold(
          backgroundColor: themeService.getScreenColor('profile') ?? (isDarkMode ? Colors.black : Colors.white),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            vertical: defaultPadding,
            horizontal: defaultPadding / 2,
          ),
          child: Column(
            children: [
              Align(alignment: Alignment.topLeft,
                child: IconButton(onPressed: (){
                  Get.back();
                }, icon: Icon(Icons.close)),
              ),
              Column(
                children: [
                  // <-- Basic account info -->
                  const BasicInfo(),
                  const Divider(thickness: 1.0, height: 30),
        
                  // Dark theme
                  Obx(
                    () => ListTile(tileColor: Colors.transparent,
                      title: Text('dark_theme'.tr),
                      leading: Icon(Icons.brightness_6_outlined, color: iconColor),
                      trailing: CupertinoSwitch(
                        activeTrackColor: primaryColor,
                        value: prefController.isDarkMode.value,
                        onChanged: (value) =>
                            prefController.isDarkMode.value = value,
                      ),
                    ),
                  ),
                  
                  // Terms of Service
                  ListTile(tileColor: Colors.transparent,
                    title: Text('Voice room Wallet'),
                    leading: Icon(Icons.record_voice_over_outlined, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () {
                      Get.to(()=> UserWalletScreen(currentUser: currentUser,));
                    },
                  ),

                  // Change Language
                  Obx(() {
                    // Get app preferences controller
                    final String langName = prefController.langName;
        
                    return ListTile(tileColor: Colors.transparent,
                      leading: Icon(Icons.translate, color: iconColor),
                      title: Text('language'.tr),
                      subtitle: langName.isEmpty ? null : Text(langName),
                      trailing: const Icon(IconlyLight.arrowRight2),
                      onTap: () => Get.to(() => const LanguagesScreen()),
                    );
                  }),
                  
                  // Settings
                  ListTile(tileColor: Colors.transparent,
                    title: Text('Settings'.tr),
                    leading: Icon(IconlyLight.setting, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => Get.toNamed('/settings'),
                  ),
        
                  // Terms of Service
                  ListTile(tileColor: Colors.transparent,
                    title: Text('terms_of_service'.tr),
                    leading: Icon(IconlyLight.paper, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.openTermsPage(),
                  ),
        
                  // Privacy Policy
                  ListTile(tileColor: Colors.transparent,
                    title: Text('privacy_policy'.tr),
                    leading: Icon(IconlyLight.lock, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.openPrivacyPage(),
                  ),
        
                  // Invite friends
                  ListTile(tileColor: Colors.transparent,
                    title: Text('invite_friends'.tr),
                    leading: Icon(Icons.share_outlined, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.shareApp(),
                  ),
        
                  // Rate on Google Play / App Store
                  ListTile(tileColor: Colors.transparent,
                    title: Text(
                        '${'rate_us_on'.tr} ${Platform.isAndroid ? 'Google Play' : 'App Store'}'),
                    leading: Icon(IconlyLight.star, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.rateApp(),
                  ),
        
                  // Contact support
                  ListTile(tileColor: Colors.transparent,
                    title: Text('contact_support'.tr),
                    leading: Icon(IconlyLight.message, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.openMailApp('support'.tr),
                  ),
        
                  // About us
                  ListTile(tileColor: Colors.transparent,
                    title: Text('about_us'.tr),
                    leading: Icon(IconlyLight.dangerCircle, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => Get.toNamed(AppRoutes.about),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        ),
      );
    });
  }
}
