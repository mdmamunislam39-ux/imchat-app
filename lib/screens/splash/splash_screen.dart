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
    // Ensure splash controller is registered
    if (!Get.isRegistered<SplashController>()) {
      Get.put(SplashController());
    }

    final AppThemeService themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : Get.put(AppThemeService(), permanent: true);

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
            child: SafeArea(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.90 + (0.10 * value),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // App logo
                      const AppLogo(
                        height: 140,
                      ),
                      const SizedBox(height: 24),
                      // Smooth loading indicator
                      LoadingIndicator(
                        size: 32,
                        color: textColor ?? Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
