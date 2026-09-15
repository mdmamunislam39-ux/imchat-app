import 'package:flutter/material.dart';
import 'package:chat_messenger/helpers/app_helper.dart';

import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:get/get.dart';

class BasicInfo extends StatelessWidget {
  const BasicInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final User currentUser = AuthController.instance.currentUser;

      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding / 2,
        ),
        child: Row(
          children: [
            // Profile photo
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.editProfile),
              child: CachedCircleAvatar(
                radius: 50,
                iconSize: 60,
                borderColor: primaryColor,
                backgroundColor: primaryColor,
                imageUrl: currentUser.photoUrl,
                userId: currentUser.userId,
                showFrame: false,
              ),
            ),
            const SizedBox(width: 10),
            // Basic info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currentUser.fullname.formattedUsername,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (currentUser.isVerified == true)
                        Icon(
                          Icons.verified,
                          size: 18,
                          color: Colors.blue,
                        )
                    ],
                  ),
                  // GestureDetector(
                  //   onTap: () => Get.toNamed(AppRoutes.editProfile),
                  //   child: Text(
                  //     '@${currentUser.username}',
                  //     style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  //         color: primaryColor, fontWeight: FontWeight.w600),
                  //   ),
                  // ),
                  // const SizedBox(height: 4),

                  Text(
                    currentUser.number,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  Text(
                    currentUser.bio,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Trailing
            IconButton(
              onPressed: () => Get.toNamed(AppRoutes.editProfile),
              icon: const Icon(
                IconlyLight.editSquare,
                color: primaryColor,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ──────────────────────────────────────────────
// Premium ID + Followers single horizontal row
//  Layout:  ID 12345678 📋  |  👥 Followers 12
// ──────────────────────────────────────────────

