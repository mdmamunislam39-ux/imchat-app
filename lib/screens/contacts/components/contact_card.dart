import 'package:flutter/material.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: defaultPadding / 2, vertical: defaultPadding / 2),
      onTap: onPress,
      leading: CachedCircleAvatar(
        imageUrl: user.photoUrl,
        radius: 28,
        frameId: user.customization?.selectedFrameId,
        frameScale: 1.3,
      ),
      title: Text(user.fullname),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: defaultPadding / 2),
        child: Text(
          '@${user.number}',
          style: TextStyle(
            color:
                Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.64),
          ),
        ),
      ),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          PopupMenuItem(
            onTap: () => controller.deleteContact(user),
            child: Text('delete_this_contact'.tr),
          ),
        ],
      ),
    );
  }
}
