import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'blocked_users_screen.dart';
import 'controller/privacy_settings_controller.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PrivacySettingsController());
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final sectionTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Privacy Settings'.tr),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ================= SECTION 1: Online & Activity =================
            _buildSectionHeader('Online & Activity Status'.tr, sectionTextColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.wifi,
                      iconColor: Colors.green,
                      title: 'Show Online Status'.tr,
                      subtitle: 'Allow others to see when you are online'.tr,
                      value: controller.showOnlineStatus.value,
                      onChanged: controller.toggleShowOnlineStatus,
                      showDivider: true,
                    ),
                  ),
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.access_time_filled,
                      iconColor: Colors.blue,
                      title: 'Show Last Seen'.tr,
                      subtitle: 'Display your recent active time on profile'.tr,
                      value: controller.showLastSeen.value,
                      onChanged: controller.toggleShowLastSeen,
                      showDivider: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ================= SECTION 2: Profile & Assets =================
            _buildSectionHeader('Profile & Asset Privacy'.tr, sectionTextColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.military_tech,
                      iconColor: Colors.amber.shade700,
                      title: 'Hide Wealth & Badges'.tr,
                      subtitle: 'Hide spending badges and wealth level from profile'.tr,
                      value: controller.hideWealthLevel.value,
                      onChanged: controller.toggleHideWealthLevel,
                      showDivider: true,
                    ),
                  ),
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.card_giftcard,
                      iconColor: Colors.pink,
                      title: 'Hide Gift Wall'.tr,
                      subtitle: 'Prevent visitors from seeing your received gifts'.tr,
                      value: controller.hideGiftWall.value,
                      onChanged: controller.toggleHideGiftWall,
                      showDivider: true,
                    ),
                  ),
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.location_off,
                      iconColor: Colors.orange,
                      title: 'Hide Country / Location'.tr,
                      subtitle: 'Do not display your flag and city on profile'.tr,
                      value: controller.hideLocation.value,
                      onChanged: controller.toggleHideLocation,
                      showDivider: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ================= SECTION 3: Interactions & Permissions =================
            _buildSectionHeader('Interaction & Permissions'.tr, sectionTextColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Obx(
                    () => _buildOptionTile(
                      context: context,
                      icon: Icons.chat_bubble_outline,
                      iconColor: primaryColor,
                      title: 'Who Can Send Direct Messages'.tr,
                      currentValue: _getPermissionLabel(controller.whoCanMessage.value),
                      onTap: () => _showPermissionPicker(
                        context: context,
                        title: 'Who Can Send Direct Messages'.tr,
                        selectedValue: controller.whoCanMessage.value,
                        onSelect: controller.setWhoCanMessage,
                      ),
                      showDivider: true,
                    ),
                  ),
                  Obx(
                    () => _buildOptionTile(
                      context: context,
                      icon: Icons.call_outlined,
                      iconColor: Colors.teal,
                      title: 'Who Can Call Me'.tr,
                      currentValue: _getPermissionLabel(controller.whoCanCall.value),
                      onTap: () => _showPermissionPicker(
                        context: context,
                        title: 'Who Can Call Me'.tr,
                        selectedValue: controller.whoCanCall.value,
                        onSelect: controller.setWhoCanCall,
                      ),
                      showDivider: true,
                    ),
                  ),
                  Obx(
                    () => _buildSwitchTile(
                      icon: Icons.group_add_outlined,
                      iconColor: Colors.indigo,
                      title: 'Allow Room Invites'.tr,
                      subtitle: 'Allow friends and users to invite you to rooms'.tr,
                      value: controller.allowRoomInvites.value,
                      onChanged: controller.toggleAllowRoomInvites,
                      showDivider: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ================= SECTION 4: Blocked Users =================
            _buildSectionHeader('Security & Restrictions'.tr, sectionTextColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block, color: Colors.red, size: 22),
                ),
                title: Text(
                  'Blocked Users'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Manage and unblock restricted accounts'.tr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => Get.to(() => const BlockedUsersScreen()),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: CupertinoSwitch(
            value: value,
            activeTrackColor: primaryColor,
            onChanged: onChanged,
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 64, endIndent: 16),
      ],
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String currentValue,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentValue,
                style: const TextStyle(
                  fontSize: 13,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 64, endIndent: 16),
      ],
    );
  }

  String _getPermissionLabel(String value) {
    switch (value) {
      case 'friends':
        return 'Friends Only'.tr;
      case 'nobody':
        return 'Nobody'.tr;
      case 'everyone':
      default:
        return 'Everyone'.tr;
    }
  }

  void _showPermissionPicker({
    required BuildContext context,
    required String title,
    required String selectedValue,
    required Function(String) onSelect,
  }) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRadioOption(
              label: 'Everyone'.tr,
              value: 'everyone',
              selectedValue: selectedValue,
              onSelect: onSelect,
            ),
            _buildRadioOption(
              label: 'Friends Only'.tr,
              value: 'friends',
              selectedValue: selectedValue,
              onSelect: onSelect,
            ),
            _buildRadioOption(
              label: 'Nobody'.tr,
              value: 'nobody',
              selectedValue: selectedValue,
              onSelect: onSelect,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildRadioOption({
    required String label,
    required String value,
    required String selectedValue,
    required Function(String) onSelect,
  }) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: () {
        onSelect(value);
        Get.back();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : null,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: primaryColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
