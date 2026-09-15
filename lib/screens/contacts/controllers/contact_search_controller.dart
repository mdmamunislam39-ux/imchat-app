import 'package:flutter/material.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

class ContactSearchController extends GetxController {
  final RxBool isLoading = RxBool(false);
  final RxBool isLoading2 = RxBool(false);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> formKey2 = GlobalKey<FormState>();
  final GlobalKey<FormState> formKey3 = GlobalKey<FormState>();

  final TextEditingController numberController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController userIdController = TextEditingController();

  Rxn<User> contact = Rxn();
  RxString countryCode = '+880'.obs;
  RxString isoCountryCode = 'BD'.obs;
  RxInt searchMode = 0.obs; // 0 = Phone Number, 1 = User ID

  void changeSearchMode(int mode) {
    searchMode.value = mode;
    contact.value = null;
  }

  Future<void> searchContactForNumber() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    final User? result = await ContactApi.searchContactForNumber(
      numberController.text.trim(),
      countryCode: countryCode.value,
    );
    if (result != null) {
      contact.value = result;
    } else {
      contact.value = null;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "contact_not_found".tr);
    }
    isLoading.value = false;
  }

  Future<void> searchContactForUserId() async {
    if (userIdController.text.trim().isEmpty) return;

    isLoading.value = true;
    final User? result = await ContactApi.searchContactForUserId(userIdController.text.trim());
    if (result != null) {
      contact.value = result;
    } else {
      contact.value = null;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "contact_not_found".tr);
    }
    isLoading.value = false;
  }

  Future<void> searchContactForName() async {
    if (!formKey2.currentState!.validate()) return;

    isLoading2.value = true;
    final User? result = await ContactApi.searchContactForName(usernameController.text.trim());
    if (result != null) {
      contact.value = result;
    } else {
      contact.value = null;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "contact_not_found".tr);
    }
    isLoading2.value = false;
  }

  @override
  void onClose() {
    numberController.dispose();
    usernameController.dispose();
    userIdController.dispose();
    super.onClose();
  }
}
