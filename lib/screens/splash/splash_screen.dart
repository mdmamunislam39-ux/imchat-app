import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/app_logo.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/screens/splash/controller/splash_controller.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Init splash controller
    Get.put(SplashController());
    final themeService = Get.find<AppThemeService>();

    return Obx(() {
      final bgColor = themeService.splashColor.value;
      final textColor = themeService.splashTextColor.value;
      final bgImageUrl = themeService.splashImageUrl.value;

      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: textColor != null
              ? Theme.of(context).colorScheme.copyWith(primary: textColor)
              : null,
          textTheme: textColor != null
              ? Theme.of(context).textTheme.apply(
                  bodyColor: textColor,
                  displayColor: textColor,
                )
              : null,
        ),
        child: Scaffold(
          backgroundColor: bgColor ?? Theme.of(context).scaffoldBackgroundColor,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: bgImageUrl.isNotEmpty
                ? BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(bgImageUrl),
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                Center(
                  child: Column(
                    children: [
                      const AppLogo(),
                      const SizedBox(height: 16),
                      Center(
                        child: LoadingIndicator(
                          size: 50,
                          color: textColor ?? Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
