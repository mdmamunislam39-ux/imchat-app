import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/settings/update_phone_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Account Settings'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone Number'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: primaryColor),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Obx(() {
                        final user = AuthController.instance.currentUser;
                        return Text(
                          user.number.isNotEmpty ? user.number : 'Not set'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () {
                        Get.to(() => const UpdatePhoneScreen());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
