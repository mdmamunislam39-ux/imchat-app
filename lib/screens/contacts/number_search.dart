import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'controllers/contact_search_controller.dart';

class NumberSearchScreen extends StatelessWidget {
  const NumberSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContactSearchController());

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text("Add Friends"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Mode Selector Toggle: Phone Number vs User ID
            Obx(() => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => controller.changeSearchMode(0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: controller.searchMode.value == 0
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              'Phone Number',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: controller.searchMode.value == 0
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => controller.changeSearchMode(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: controller.searchMode.value == 1
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              'User ID',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: controller.searchMode.value == 1
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            // Search Fields (Phone Number or User ID)
            Obx(() {
              if (controller.searchMode.value == 0) {
                // Phone Number Search
                return Form(
                  key: controller.formKey,
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (val) {
                          controller.countryCode.value = val.toString();
                          controller.isoCountryCode.value = val.code!;
                        },
                        textStyle: TextStyle(fontSize: 16, color: primaryColor),
                        dialogTextStyle: TextStyle(fontSize: 12, color: primaryColor),
                        initialSelection: 'BD',
                        favorite: ['+39', 'US'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: TextFormField(
                            autofocus: true,
                            onFieldSubmitted: (_) => controller.searchContactForNumber(),
                            textInputAction: TextInputAction.search,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "number can't be null";
                              }
                              return null;
                            },
                            inputFormatters: AppHelper.usernameFormatter,
                            controller: controller.numberController,
                            decoration: InputDecoration(
                              hintText: 'search phone number',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () => controller.searchContactForNumber(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // User ID Search
                return Form(
                  key: controller.formKey3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      autofocus: true,
                      onFieldSubmitted: (_) => controller.searchContactForUserId(),
                      textInputAction: TextInputAction.search,
                      controller: controller.userIdController,
                      decoration: InputDecoration(
                        hintText: 'enter User ID or Search ID',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => controller.searchContactForUserId(),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }),

            // Search Result
            Obx(() {
              if (controller.isLoading.value) {
                return const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: LoadingIndicator(size: 50),
                );
              } else if (controller.contact.value == null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: NoData(
                    iconData: IconlyLight.search,
                    text: 'search'.tr,
                  ),
                );
              }

              final User user = controller.contact.value!;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Get.to(() => ProfilePageForRoom(
                              userID: user.userId,
                              userName: user.fullname,
                              userImage: user.photoUrl,
                            ));
                      },
                      leading: CachedCircleAvatar(
                        imageUrl: user.photoUrl,
                        radius: 28,
                        frameId: user.customization?.selectedFrameId,
                        frameScale: 1.3,
                      ),
                      title: Text(
                        user.fullname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          user.searchId.isNotEmpty
                              ? 'ID: ${user.searchId}'
                              : 'ID: ${user.userId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      trailing: controller.searchMode.value == 0
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                FocusScope.of(context).unfocus();
                                await ContactApi.addContact(
                                  userId: user.userId,
                                  showMsg: true,
                                );
                              },
                              icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                              label: const Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Get.to(() => ProfilePageForRoom(
                                      userID: user.userId,
                                      userName: user.fullname,
                                      userImage: user.photoUrl,
                                    ));
                              },
                              icon: const Icon(Icons.account_circle, size: 16, color: Colors.white),
                              label: const Text(
                                'Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0099FF),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      controller.searchMode.value == 0
                          ? 'Added via phone number: will be added directly to contact list.'
                          : 'Added via User ID: tap to view profile & send friend request.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
