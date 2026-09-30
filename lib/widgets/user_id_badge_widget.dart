import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter/services.dart';

/// User ID Badge Widget that renders the custom graphic PNG/SVGA/GIF/WebP banner
/// and superimposes the numeric ID perfectly in the empty space of the capsule banner.
class UserIdBadgeWidget extends StatelessWidget {
  final String searchId;
  final TextStyle? textStyle;
  final double? badgeWidth;
  final double? badgeHeight;
  final bool showCopyIcon;
  final Color? copyIconColor;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;

  const UserIdBadgeWidget({
    super.key,
    required this.searchId,
    this.textStyle,
    this.badgeWidth,
    this.badgeHeight,
    this.showCopyIcon = false,
    this.copyIconColor,
    this.onCopy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (searchId.isEmpty) {
      return const SizedBox.shrink();
    }

    final cleanId = searchId.trim();
    final digitLength = cleanId.length;

    Widget body = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('global_settings')
          .doc('id_badges')
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? data = snapshot.data?.data();

        // 1. Check digit-specific badge (e.g. digit_1, digit_2, digit_3...)
        Map<String, dynamic>? badgeData = data?['digit_$digitLength'];

        // 2. Fallback to default badge (digit_0) if not found or inactive
        if (badgeData == null ||
            badgeData['isActive'] != true ||
            (badgeData['badgeUrl'] ?? '').toString().isEmpty) {
          badgeData = data?['digit_0'];
        }

        final bool hasActiveBadge = badgeData != null &&
            badgeData['isActive'] == true &&
            (badgeData['badgeUrl'] ?? '').toString().isNotEmpty;

        final String badgeUrl = (badgeData?['badgeUrl'] ?? '').toString();

        final double baseHeight = (badgeData?['height'] is num ? (badgeData!['height'] as num).toDouble() : 30.0);

        final double baseWidth = (badgeData?['width'] is num ? (badgeData!['width'] as num).toDouble() : 116.0);

        final double effectiveBadgeHeight = badgeHeight ?? baseHeight;

        final double effectiveBadgeWidth = badgeWidth ??
            (badgeHeight != null
                ? (badgeHeight! * (baseWidth / baseHeight))
                : baseWidth);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasActiveBadge)
              // Complete Graphic PNG/SVGA Banner with ID Number in empty space
              SizedBox(
                width: effectiveBadgeWidth,
                height: effectiveBadgeHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Full PNG/SVGA Banner background (Shield + Capsule Bar)
                    Positioned.fill(
                      child: _buildMediaBadge(
                        badgeUrl,
                        effectiveBadgeWidth,
                        effectiveBadgeHeight,
                      ),
                    ),
                    // 2. ID Number placed perfectly over the empty portion of the capsule
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: effectiveBadgeHeight * 1.25,
                          right: effectiveBadgeHeight * 0.25,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              cleanId,
                              style: (textStyle ?? const TextStyle()).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: textStyle?.fontSize ?? (effectiveBadgeHeight * 0.46),
                                letterSpacing: 0.3,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Fallback Default Sleek Pill when no badge is configured
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID: ',
                      style: (textStyle ?? const TextStyle()).copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: (textStyle?.fontSize ?? 12) * 0.9,
                      ),
                    ),
                    Text(
                      cleanId,
                      style: (textStyle ?? const TextStyle()).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: textStyle?.fontSize ?? 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Copy Icon next to badge banner
            if (showCopyIcon) ...[
              const SizedBox(width: 5),
              InkWell(
                onTap: onCopy ??
                    () {
                      Clipboard.setData(ClipboardData(text: cleanId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ID $cleanId copied to clipboard'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: copyIconColor ?? Colors.black54,
                ),
              ),
            ],
          ],
        );
      },
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: body,
      );
    }

    return body;
  }

  Widget _buildMediaBadge(String url, double width, double height) {
    final lower = url.toLowerCase();

    // SVGA Animation support
    if (lower.contains('.svga')) {
      return SizedBox(
        width: width,
        height: height,
        child: SVGAEasyPlayer(
          resUrl: url,
          fit: BoxFit.fill,
        ),
      );
    }

    // WebP, GIF, PNG support
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.fill,
      placeholder: (context, url) => SizedBox(width: width, height: height),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}
