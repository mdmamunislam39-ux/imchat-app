import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_theme_service.dart';

class DynamicDiamondIcon extends StatelessWidget {
  const DynamicDiamondIcon({
    super.key,
    this.width = 16,
    this.height = 16,
    this.fallbackIcon = 'assets/images/diamond_icon.webp', // Assuming diamond_icon.png is the standard asset
    this.color,
    this.fit = BoxFit.contain,
    this.errorBuilder,
  });

  final double width;
  final double height;
  final String fallbackIcon;
  final Color? color;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppThemeService>()) {
      return _buildFallback();
    }
    return Obx(() {
      final themeService = Get.find<AppThemeService>();
      if (themeService.diamondIconUrl.value.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: themeService.diamondIconUrl.value,
          width: width,
          height: height,
          color: color,
          fit: fit,
          errorWidget: (context, url, error) => _buildFallback(),
        );
      }
      return _buildFallback();
    });
  }

  Widget _buildFallback() {
    return Image.asset(
      fallbackIcon,
      width: width,
      height: height,
      color: color,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}
