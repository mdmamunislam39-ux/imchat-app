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
  final TextEditingController numberController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  Rxn<User> contact = Rxn();

  RxString countryCode = '+880'.obs;
  RxString isoCountryCode = 'BD'.obs;
  //RxInt selectedView = 0.obs;
  // void changeView(int index) {
  //   selectedView.value = index;
  // }

  Future<void> searchContactForNumber() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    final User? result = await ContactApi.searchContactForNumber( countryCode+numberController.text.trim());
    // Check the result
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
    // Check the result
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
    super.onClose();
  }
}
