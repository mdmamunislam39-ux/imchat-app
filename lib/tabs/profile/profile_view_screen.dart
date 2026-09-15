import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/api/report_api.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/app_controller.dart';
import 'package:chat_messenger/controllers/report_controller.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/models/app_info.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/helper/call_helper.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/components/svg_icon.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/screens/news_feed/post_media_viewer.dart';

import 'components/action_button.dart';
import 'controllers/profile_view_controller.dart';

class ProfileViewScreen extends StatelessWidget {
  const ProfileViewScreen({
    super.key,
    required this.user,
    required this.isGroup,
  });

  final User user;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    final controller = Get.put(ProfileViewController(user.userId));
    final ReportController reportController = Get.find();

    return Scaffold(
      appBar: CustomAppBar(
        height: 50,
        title: Text('profile'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            vertical: defaultPadding * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile photo (no frame shown in this minimal view)
                    GestureDetector(
                      onTap: () {
                        if (user.photoUrl.isNotEmpty) {
                          Get.to(() => PostMediaViewer(
                            mediaList: [
                              PostMedia(
                                url: user.photoUrl,
                                type: 'image',
                              ),
                            ],
                            initialIndex: 0,
                          ));
                        }
                      },
                      child: CachedCircleAvatar(
                        radius: 70,
                        iconSize: 60,
                        imageUrl: user.photoUrl,
                        userId: user.userId,
                        showFrame: false,
                      ),
                    ),
                    // Profile name
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: defaultPadding / 2),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.fullname,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontSize: 26),
                            ),
                            if (user.isVerified == true || user.userId == 'official_team' || user.userId.startsWith('official_channel_') || user.userType == 'channel')
                              const Padding(
                                padding: EdgeInsets.only(left: 6.0),
                                child: Icon(
                                  Icons.verified,
                                  size: 24,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.searchId.isNotEmpty ? 'ID: ${user.searchId}' : 'ID: ${user.userId}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(color: greyColor),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              final idToCopy = user.searchId.isNotEmpty ? user.searchId : user.userId;
                              await Clipboard.setData(ClipboardData(text: idToCopy));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'ID $idToCopy copied to clipboard!',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: primaryColor,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: greyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Last seen
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding / 2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? greyColor.withValues(alpha: 0.5) : greyLight,
                        borderRadius: BorderRadius.circular(defaultRadius / 2),
                      ),
                      child: FutureBuilder<User?>(
                        future: UserApi.getUser(user.userId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          // Get user
                          final User? updatedUser = snapshot.data;

                          if (updatedUser == null) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                              "${updatedUser.lastActive?.getLastSeenTime}");
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Get.to(() => ProfilePageForRoom(
                              userID: user.userId,
                              userName: user.fullname,
                              userImage: user.photoUrl,
                            ));
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                                width: 1,
                              ),
                              boxShadow: isDarkMode ? null : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                SvgIcon(
                                  'assets/icons/broadcast.svg',
                                  width: 24,
                                  height: 24,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                 const SizedBox(width: 12),
                                 Text(
                                   'Room Profile',
                                   style: TextStyle(
                                     fontSize: 16,
                                     fontWeight: FontWeight.w600,
                                     color: isDarkMode ? Colors.white : Colors.black87,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 StreamBuilder<User>(
                                   stream: UserApi.getUserUpdates(user.userId),
                                   initialData: user,
                                   builder: (context, snapshot) {
                                     final updatedUser = snapshot.data ?? user;
                                     final sendingLevelVal = updatedUser.sendingLevel?.level;
                                     final receivingLevelVal = updatedUser.receivingLevel?.level;
                                     
                                     return Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         if (sendingLevelVal != null) ...[
                                           _buildSingleLevelBadge('sending_config', sendingLevelVal),
                                           const SizedBox(width: 4),
                                         ],
                                         if (receivingLevelVal != null) ...[
                                           _buildSingleLevelBadge('receiving_config', receivingLevelVal),
                                         ],
                                       ],
                                     );
                                   },
                                 ),
                                 const Spacer(),
                                 Text(
                                   'See more',
                                   style: TextStyle(
                                     fontSize: 14,
                                     color: Colors.grey[500],
                                   ),
                                 ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions: video call, voice call and message
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding,
                      ),
                      child: Obx(() {
                        final AppInfo appInfo = AppController.instance.appInfo;
                        final bool isOfficial = user.userId == 'official_team' || user.userId.startsWith('official_channel_') || user.userType == 'channel';

                        if (isOfficial) {
                          return const SizedBox.shrink();
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Voice call
                            if (appInfo.allowVoiceCall && Get.find<GlobalSettingsService>().isAudioCallEnabled.value)
                              ActionButton(
                                icon: IconlyBold.call,
                                title: 'audio'.tr,
                                onPress: () => CallHelper.makeCall(
                                    isVideo: false, user: user),
                              ),

                            // Video call
                            if (appInfo.allowVideoCall && Get.find<GlobalSettingsService>().isVideoCallEnabled.value)
                              ActionButton(
                                icon: IconlyBold.video,
                                title: 'video'.tr,
                                onPress: () => CallHelper.makeCall(
                                    isVideo: true, user: user),
                              ),

                            // Message
                            ActionButton(
                              icon: IconlyBold.chat,
                              title: 'message'.tr,
                              onPress: () {
                                if (isGroup) {
                                  // Go to message page
                                  RoutesHelper.toMessages(user: user).then((_) {
                                    // Close group messages page
                                    Get.back();
                                    // Close group details page
                                    Get.back();
                                    // Close the current page
                                    Get.back();
                                  });
                                } else {
                                  // If 1-to-1 just close this page and return to messages page
                                  Get.back();
                                }
                              },
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description card
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  user.bio,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const Divider(),

              // Other info card
              ListTile(
                horizontalTitleGap: 8,
                leading: const Icon(IconlyLight.lock),
                title: Text('encrypted_message'.tr),
              ),
              const SizedBox(height: 8),
              if (!(user.userId == 'official_team' || user.userId.startsWith('official_channel_') || user.userType == 'channel')) ...[
                Obx(() {
                  final bool isBlocked = controller.isBlocked.value;

                  return ListTile(
                    onTap: () => controller.toggleBlockUser(),
                    horizontalTitleGap: 8,
                    leading:
                        const Icon(IconlyLight.closeSquare, color: errorColor),
                    title: Text(
                      "${isBlocked ? 'unblock'.tr : 'block'.tr} ${user.fullname}",
                      style: const TextStyle(color: errorColor),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ListTile(
                  onTap: () => reportController.reportDialog(
                    type: ReportType.user,
                    userId: user.userId,
                  ),
                  horizontalTitleGap: 8,
                  leading: const Icon(IconlyLight.infoSquare, color: errorColor),
                  title: Text(
                    "${'report'.tr} ${user.fullname}",
                    style: const TextStyle(color: errorColor),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleLevelBadge(String configDoc, int levelNumber) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('level_configurations')
          .doc(configDoc)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['levels'] == null) {
          return const SizedBox.shrink();
        }

        final levels = List<Map<String, dynamic>>.from(data['levels']);
        String? imageUrl;
        for (final lvl in levels) {
          if (lvl['levelNumber']?.toString() == levelNumber.toString()) {
            imageUrl = lvl['imageUrl'] as String?;
            break;
          }
        }

        if (imageUrl == null || imageUrl.isEmpty) {
          return const SizedBox.shrink();
        }

        return CachedNetworkImage(
          imageUrl: imageUrl,
          height: 14,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        );
      },
    );
  }
}
