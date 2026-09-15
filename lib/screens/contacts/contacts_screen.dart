import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/floating_button.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/screens/contacts/controllers/contact_controller.dart';
import 'package:chat_messenger/screens/contacts/friend_request_screen.dart';
import 'package:chat_messenger/tabs/calls/call_hsitory_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/groups_screen.dart';
import 'package:get/get.dart';

import 'components/contact_card.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({
    super.key,
    this.showAppBar = false,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final ContactController controller = Get.isRegistered<ContactController>()
        ? Get.find<ContactController>()
        : Get.put(ContactController());

    final content = Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: LoadingIndicator());
      }

      final currentUser = AuthController.instance.currentUser;
      final sorted = controller.sortedContacts;

      // Build unified contact items list including "Message yourself" if not in contacts
      final List<User> displayList = [];
      if (currentUser.userId.isNotEmpty) {
        final hasSelf = sorted.any((u) => u.userId == currentUser.userId);
        if (!hasSelf) {
          displayList.add(currentUser);
        }
      }
      displayList.addAll(sorted);

      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. New Contacts
          _buildShortcutRow(
            icon: Icons.person_add_alt_1_outlined,
            iconColor: const Color(0xFF00897B),
            iconBg: const Color(0xFFE0F2F1),
            title: 'New Contacts',
            badgeCount: controller.pendingRequestsCount.value,
            onTap: () => Get.to(() => const FriendRequestScreen()),
          ),

          // 2. Call History
          _buildShortcutRow(
            icon: Icons.phone_callback_outlined,
            iconColor: const Color(0xFF00ACC1),
            iconBg: const Color(0xFFE0F7FA),
            title: 'Call History',
            onTap: () => Get.to(() => const CallHistoryScreen()),
          ),

          // 3. Groups
          _buildShortcutRow(
            icon: Icons.people_outline,
            iconColor: const Color(0xFF43A047),
            iconBg: const Color(0xFFE8F5E9),
            title: 'Groups',
            onTap: () => Get.to(() => const GroupsScreen()),
          ),

          // Divider and "Sort by status"
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort by status',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                InkWell(
                  onTap: () => controller.toggleSort(),
                  child: const Icon(
                    Icons.tune,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Contact Cards
          ...displayList.map((user) => ContactCard(
                user: user,
                onPress: () {
                  RoutesHelper.toMessages(user: user);
                },
              )),
          const SizedBox(height: 16),
        ],
      );
    });

    if (!showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: Text("contacts".tr),
        actions: [
          IconButton(
            icon: const Icon(IconlyLight.search, color: Colors.white),
            onPressed: () => Get.toNamed(AppRoutes.contactSearch),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
      floatingActionButton: FloatingButton(
        icon: IconlyBold.addUser,
        onPress: () => Get.toNamed(AppRoutes.contactSearch),
      ),
    );
  }

  Widget _buildShortcutRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.grey,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
