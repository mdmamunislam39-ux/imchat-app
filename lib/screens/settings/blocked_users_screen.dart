import 'package:chat_messenger/api/block_api.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthController.instance.currentUser.userId;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('blocked_users'.tr.isNotEmpty ? 'blocked_users'.tr : 'Blocked Users'),
      ),
      body: StreamBuilder<List<String>>(
        stream: BlockApi.getBlockedUserIds(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final blockedUserIds = snapshot.data ?? [];

          if (blockedUserIds.isEmpty) {
            return Center(
              child: NoData(
                iconData: Icons.block,
                text: 'no_blocked_users'.tr.isNotEmpty ? 'no_blocked_users'.tr : 'No blocked users',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: blockedUserIds.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final userId = blockedUserIds[index];
              return FutureBuilder<User?>(
                future: UserApi.getUser(userId),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data;
                  final displayName = user?.fullname.isNotEmpty == true
                      ? user!.fullname
                      : 'User ID: $userId';
                  final photoUrl = user?.photoUrl ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CachedCircleAvatar(
                          imageUrl: photoUrl,
                          radius: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user != null && user.searchId.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${user.searchId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            DialogHelper.showAlertDialog(
                              icon: const Icon(Icons.lock_open, color: primaryColor, size: 48),
                              title: Text('unblock'.tr),
                              content: Text(
                                '${'unblock'.tr} $displayName?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15),
                              ),
                              actionText: 'unblock'.tr,
                              action: () async {
                                Get.back(); // close dialog
                                await BlockApi.unblockUser(
                                  currentUserId: currentUserId,
                                  otherUserId: userId,
                                );
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          ),
                          child: Text(
                            'unblock'.tr,
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
