import 'dart:io';

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/default_button.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'controllers/edit_profile_controller.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EditProfileController controller = Get.put(EditProfileController());
    final User currentUser = AuthController.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Personal Data'.tr,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Obx(() {
                final int totalImages = controller.retainedBackgroundUrls.length + controller.newBackgroundFiles.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${'Home Page Background'.tr} ($totalImages / 9)', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                );
              }),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Obx(() {
                  final int totalImages = controller.retainedBackgroundUrls.length + controller.newBackgroundFiles.length;
                  
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Retained Backgrounds
                        ...controller.retainedBackgroundUrls.map((url) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildImageSquare(
                              url: url,
                              onDelete: () => controller.retainedBackgroundUrls.remove(url),
                            ),
                          );
                        }),
                        
                        // New Background Files
                        ...controller.newBackgroundFiles.map((file) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildImageSquare(
                              file: file,
                              onDelete: () => controller.newBackgroundFiles.remove(file),
                            ),
                          );
                        }),
                        
                        // Add Button
                        if (totalImages < 9)
                          GestureDetector(
                            onTap: () async {
                              final File? resultFile = await DialogHelper.showPickImageDialog(isAvatar: false);
                              if (resultFile != null) {
                                controller.newBackgroundFiles.add(resultFile);
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              ),
                              child: const Icon(Icons.add, color: Colors.grey, size: 30),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Colors.black12),
              
              _buildListTile(
                title: 'Avatar'.tr,
                trailing: Obx(() {
                  if (controller.photoFile.value != null) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: FileImage(controller.photoFile.value!),
                    );
                  }
                  return CachedCircleAvatar(
                    imageUrl: currentUser.photoUrl,
                    radius: 20,
                  );
                }),
                onTap: () async {
                  final File? resultFile = await DialogHelper.showPickImageDialog(isAvatar: true);
                  if (resultFile != null) controller.photoFile.value = resultFile;
                },
              ),
              const Divider(height: 1, color: Colors.black12),

              Obx(() => _buildListTile(
                title: 'Nickname'.tr,
                trailingText: controller.name.value.isEmpty ? 'Set nickname'.tr : controller.name.value,
                onTap: () => _showEditDialog(context, 'Nickname'.tr, controller.nameController, (val) {
                  controller.nameController.text = val;
                  controller.name.value = val;
                }),
              )),
              const Divider(height: 1, color: Colors.black12),

              Obx(() => _buildListTile(
                title: 'Sex'.tr,
                trailingText: controller.gender.value.isEmpty ? 'Select'.tr : (controller.gender.value == 'Boy' ? 'Boy'.tr : (controller.gender.value == 'Girl' ? 'Girl'.tr : controller.gender.value)),
                onTap: () => _showGenderDialog(context, controller),
              )),
              const Divider(height: 1, color: Colors.black12),

              Obx(() => _buildListTile(
                title: 'Birthday'.tr,
                trailingText: controller.birthday.value.isEmpty ? 'Select'.tr : controller.birthday.value,
                onTap: () => _pickDate(context, controller),
              )),
              const Divider(height: 1, color: Colors.black12),

              CountryCodePicker(
                onChanged: (countryCode) {
                  controller.country.value = countryCode.name ?? '';
                },
                initialSelection: controller.country.value.isEmpty ? 'BD' : controller.country.value,
                showCountryOnly: true,
                showOnlyCountryWhenClosed: true,
                alignLeft: false,
                builder: (countryCode) {
                  return _buildListTile(
                    title: 'Country'.tr,
                    trailingText: countryCode?.name ?? (controller.country.value.isEmpty ? 'Select'.tr : controller.country.value),
                  );
                },
              ),
              const Divider(height: 1, color: Colors.black12),

              Obx(() => _buildListTile(
                title: 'Personal Signature'.tr,
                trailingText: controller.bio.value.isEmpty ? 'Set signature'.tr : controller.bio.value,
                onTap: () => _showEditDialog(context, 'Signature'.tr, controller.bioController, (val) {
                  controller.bioController.text = val;
                  controller.bio.value = val;
                }),
              )),
              const Divider(height: 1, color: Colors.black12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: DefaultButton(
              height: 45,
              isLoading: controller.isLoading.value,
              width: double.maxFinite,
              text: 'SAVE CHANGES'.tr,
              onPress: () async {
                await controller.updateAccount();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSquare({File? file, String? url, VoidCallback? onDelete}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
            image: file != null 
                ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                : (url != null && url.isNotEmpty
                    ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover)
                    : null),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListTile({required String title, String? trailingText, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          if (trailingText != null) 
            Text(trailingText, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, TextEditingController textController, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (context) {
        final tempController = TextEditingController(text: textController.text);
        return AlertDialog(
          title: Text('${'edit'.tr} $title'),
          content: TextField(
            controller: tempController,
            decoration: InputDecoration(hintText: '${'enter'.tr} $title'),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
            ElevatedButton(
              onPressed: () {
                onSave(tempController.text);
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('save'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showGenderDialog(BuildContext context, EditProfileController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Sex'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Boy'.tr),
                onTap: () {
                  controller.gender.value = 'Boy';
                  Get.back();
                },
              ),
              ListTile(
                title: Text('Girl'.tr),
                onTap: () {
                  controller.gender.value = 'Girl';
                  Get.back();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context, EditProfileController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      controller.birthday.value = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
