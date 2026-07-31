import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/floating_button.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/screens/contacts/controllers/contact_controller.dart';
import 'package:get/get.dart';

import 'components/contact_card.dart';
import 'package:chat_messenger/screens/contacts/friend_request_screen.dart';
import 'package:chat_messenger/config/theme_config.dart';

class ContactsScreen extends GetView<ContactController> {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: Obx(() {
        // Check loading
        if (controller.isLoading.value) {
          return const LoadingIndicator();
        } else if (controller.contacts.isEmpty) {
          return NoData(
            iconData: IconlyBold.profile,
            text: 'no_contacts'.tr,
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemCount: controller.contacts.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: const Icon(IconlyBold.user3, color: primaryColor),
                ),
                title: Text(
                  'new_group'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Get.toNamed(AppRoutes.groups);
                },
              );
            }
            if (index == 1) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_add, color: Colors.orange),
                ),
                title: Text(
                  'add_request'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Get.to(() => const FriendRequestScreen());
                },
              );
            }
            
            final User user = controller.contacts[index - 2];
            return ContactCard(
              user: user,
              onPress: () {
                Get.back();
                RoutesHelper.toMessages(user: user);
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingButton(
        icon: IconlyBold.addUser,
        onPress: () => Get.toNamed(AppRoutes.contactSearch),
      ),
    );
  }
}
