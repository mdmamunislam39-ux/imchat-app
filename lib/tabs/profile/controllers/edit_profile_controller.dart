import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';

class EditProfileController extends GetxController {
  // Vars
  final RxBool isLoading = RxBool(false);
  final RxBool isExtended = RxBool(false);
  final Rxn<File> photoFile = Rxn();
  final RxList<File> newBackgroundFiles = RxList<File>([]);
  final RxList<String> retainedBackgroundUrls = RxList<String>([]);

  final nameController = TextEditingController();
  final bioController = TextEditingController();
  
  final RxString name = RxString('');
  final RxString bio = RxString('');
  final RxString gender = RxString('');
  final RxString birthday = RxString('');
  final RxString country = RxString('');

  @override
  void onInit() {
    loadInitialData();
    super.onInit();
  }

  @override
  void onClose() {
    nameController.dispose();
    bioController.dispose();
    super.onClose();
  }

  void loadInitialData() {
    final User currentUser = AuthController.instance.currentUser;
    
    photoFile.value = null;
    newBackgroundFiles.clear();
    retainedBackgroundUrls.clear();

    nameController.text = currentUser.fullname;
    name.value = currentUser.fullname;
    bioController.text = currentUser.bio;
    bio.value = currentUser.bio;
    gender.value = currentUser.gender;
    birthday.value = currentUser.birthday;
    country.value = currentUser.country;
    
    // Load existing backgrounds
    if (currentUser.homePageBackgrounds.isNotEmpty) {
      retainedBackgroundUrls.assignAll(currentUser.homePageBackgrounds);
    } else if (currentUser.homePageBackground.isNotEmpty) {
      retainedBackgroundUrls.assignAll([currentUser.homePageBackground]);
    }
  }

  Future<void> updateAccount() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;

      // Update user account
      final result = await UserApi.updateAccount(
        photoFile: photoFile.value,
        newBackgroundFiles: newBackgroundFiles.toList(),
        retainedBackgroundUrls: retainedBackgroundUrls.toList(),
        fullname: name.value.trim(),
        bio: bio.value.trim(),
        gender: gender.value,
        birthday: birthday.value,
        country: country.value,
      );

      // Check result
      if (result == true) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        Get.back(); // close the edit profile screen

        // Show success message
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'account_updated_successfully'.tr);
      } else {
        // Show error message
        debugPrint('EditProfile Error: $result');
        DialogHelper.showSnackbarMessage(SnackMsgType.error, result.toString());
      }
    } catch (e) {
      debugPrint('EditProfile Exception: $e');
      DialogHelper.showSnackbarMessage(SnackMsgType.error, 'Error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
