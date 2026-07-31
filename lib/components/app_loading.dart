
import 'package:chat_messenger/config/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppStyle{

   InputBorder defalutBorder = OutlineInputBorder(borderSide: BorderSide(color: primaryColor),borderRadius: BorderRadius.circular(10));
   InputBorder errorBorder = OutlineInputBorder(borderSide: BorderSide(color: primaryColor),borderRadius: BorderRadius.circular(10));

  SnackbarController? successSnackBar({
    required String message,
  }) {
    if (Get.overlayContext == null) return null;
    try {
      return Get.showSnackbar(GetSnackBar(
        title: "Success",
        message: message,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      debugPrint("Error showing success snackbar: $e");
      return null;
    }
  }

  SnackbarController? failedSnackBar({
    required String message,
  }) {
    if (Get.overlayContext == null) {
      debugPrint("Failed SnackBar (No Overlay): $message");
      return null;
    }
    try {
      return Get.showSnackbar(GetSnackBar(
        title: "Failed",
        message: message,
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      debugPrint("Error showing failed snackbar: $e");
      return null;
    }
  }
 void progressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Image.asset(
            "assets/file/loading.gif",
            height: 150,
          ),
        );
      },
      barrierDismissible: false,
    );
  }
}