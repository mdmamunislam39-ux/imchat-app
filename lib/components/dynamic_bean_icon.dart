import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_theme_service.dart';

class DynamicBeanIcon extends StatelessWidget {
  const DynamicBeanIcon({
    super.key,
    this.width = 16,
    this.height = 16,
    this.fallbackIcon = 'assets/images/cashout.png', // Typical fallback for beans
    this.color,
  });

  final double width;
  final double height;
  final String fallbackIcon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeService = Get.find<AppThemeService>();
      if (themeService.beansIconUrl.value.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: themeService.beansIconUrl.value,
          width: width,
          height: height,
          color: color,
          fit: BoxFit.contain,
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
    );
  }
}
