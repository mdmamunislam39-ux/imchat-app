import 'package:flutter/material.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/helper/call_helper.dart';
import 'package:get/get.dart';

import '../controllers/contact_controller.dart';

class ContactCard extends GetView<ContactController> {
  const ContactCard({
    super.key,
    required this.user,
    required this.onPress,
  });

  final User user;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthController.instance.currentUser;
    final bool isSelf = user.userId == currentUser.userId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      onTap: onPress,
      onLongPress: isSelf ? null : () => controller.deleteContact(user),
      leading: CachedCircleAvatar(
        imageUrl: user.photoUrl,
        radius: 22,
        isOnline: user.isOnline,
        lastActive: user.lastActive?.millisecondsSinceEpoch,
        showFrame: false,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isSelf ? '${user.fullname}(You)' : user.fullname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          if (user.isVerified == true ||
              user.userId == 'official_team' ||
              user.userId.startsWith('official_channel_') ||
              user.userType == 'channel') ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified,
              size: 16,
              color: Colors.blue,
            ),
          ],
        ],
      ),
      subtitle: Text(
        isSelf
            ? 'Message yourself'
            : (user.isOnline ? 'Online' : 'Offline'),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color
              ?.withValues(alpha: 0.6) ??
              Colors.grey,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, color: Color(0xFF1E88E5)),
        onPressed: () {
          CallHelper.makeCall(isVideo: false, user: user);
        },
      ),
    );
  }
}

