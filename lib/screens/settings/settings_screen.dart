import 'package:chat_messenger/api/auth_api.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';

import 'privacy_settings_screen.dart';
import 'account_settings_screen.dart';
import 'manage_devices_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Settings'.tr),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: primaryColor),
            title: Text('Privacy Settings'.tr),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Get.to(() => const PrivacySettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: primaryColor),
            title: Text('Account Settings'.tr),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Get.to(() => const AccountSettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.devices, color: primaryColor),
            title: Text('Manage Devices'.tr),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Get.to(() => const ManageDevicesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('log_out'.tr, style: const TextStyle(color: Colors.red)),
            onTap: () {
              DialogHelper.showAlertDialog(
                icon: const Icon(Icons.logout, color: Colors.red, size: 50),
                title: Text('log_out'.tr),
                content: Text(
                  'Are you sure you want to log out?'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                actionText: 'log_out'.tr,
                action: () {
                  Get.back(); // close dialog
                  AuthApi.signOut();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
