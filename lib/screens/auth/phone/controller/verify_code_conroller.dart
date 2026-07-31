
import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/screens/auth/signin/controller/signin_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VerifyCodeController extends GetxController {
  final SignInController authController = Get.find<SignInController>();
  var timerMaxSeconds = 60;
  var currentSeconds = 0.obs;
  var isTimerActive = true.obs;
  var code = ''.obs;

  List<TextEditingController> controllers = 
      List.generate(6, (index) => TextEditingController());
  List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());
  Timer? timer;
  var activeIndex = 0.obs;
  var currentVerificationId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    for (int i = 0; i < 6; i++) {
      focusNodes[i].addListener(() {
        if (focusNodes[i].hasFocus) {
          activeIndex.value = i;
        }
      });
    }
    startTimer();
  }

  String get timerText {
    int remainingSeconds = timerMaxSeconds - currentSeconds.value;
    return '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')} : ${(remainingSeconds % 60).toString().padLeft(2, '0')}';
  }

  var isSubmitting = false.obs;

  // Start the countdown timer
  void startTimer() {
    stopTimer();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentSeconds.value = timer.tick;
      if (timer.tick >= timerMaxSeconds) {
        timer.cancel();
        isTimerActive.value = false;
      }
    });
  }

  // Stop the timer
  void stopTimer() {
    timer?.cancel();
  }

  // Resend OTP
  Future<void> resendOtp(BuildContext context, String number) async {
    stopTimer();
    isSubmitting.value = true;
    try {
      await authController.phoneAuthSendOtp(context, number, isResend: true);
      currentSeconds.value = 0;
      isTimerActive.value = true;
      startTimer();
    } finally {
      isSubmitting.value = false;
    }
  }

  // Verify the OTP code
  Future<void> verifyOtp(String initialVerificationId, BuildContext context, dynamic number) async {
    // Prefer the new verification ID if available, otherwise fallback to the initial one
    String vId = currentVerificationId.value.isNotEmpty ? currentVerificationId.value : initialVerificationId;

    code.value = controllers.map((c) => c.text).join('');
    if (code.value.isEmpty || code.value.length < 6) {
      AppStyle().failedSnackBar(message: "Please enter the full 6-digit OTP code");
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    
    // Show a full screen loading dialog so the user knows it's processing
    AppStyle().progressDialog(context);
    
    try {
      String result = await authController.phoneAuthVerifyOtp(
          vId, code.value, context);

      if (result == "success") {
        Get.back(); // Dismiss the progress dialog
        String uid = FirebaseAuth.instance.currentUser!.uid;
        var doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        if (doc.exists) {
          // User exists in Firestore
          await AuthController.instance.checkUserAccount();
        } else {
          // New user, doesn't exist in Firestore
          Get.offAllNamed('/signup', arguments: {'number': number});
        }
      } else {
        Get.back(); // Dismiss the progress dialog
        AppStyle().failedSnackBar(message: "OTP code didn't match: $result");
      }
    } catch (e) {
      Get.back(); // Dismiss the progress dialog
      debugPrint("OTP Verification Error: $e");
      AppStyle().failedSnackBar(
          message: "Something went wrong: $e");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    stopTimer();
    for (var controller in controllers) {
      controller.dispose();
    }
    super.onClose();
  }
}
