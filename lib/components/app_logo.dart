import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_theme_service.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height = 150,
    this.color,
  });

  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppThemeService>()) {
      return _buildAssetLogo();
    }
    final themeService = Get.find<AppThemeService>();
    return Obx(() {
      if (themeService.appLogoUrl.value.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: themeService.appLogoUrl.value,
          width: width,
          height: height,
          color: color,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => _buildAssetLogo(),
        );
      }
      return _buildAssetLogo();
    });
  }

  Widget _buildAssetLogo() {
    return Image.asset(
      "assets/images/app_logo.png",
      width: width,
      height: height,
      color: color,
    );
  }
}
