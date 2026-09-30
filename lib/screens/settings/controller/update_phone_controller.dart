import 'dart:async';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/settings/verify_update_phone_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UpdatePhoneController extends GetxController {
  final TextEditingController numberController = TextEditingController();
  final GlobalKey<FormState> phoneFormKey = GlobalKey<FormState>();

  final RxString countryCode = '+880'.obs;
  final RxString isoCountryCode = 'BD'.obs;
  final RxString formattedPreview = ''.obs;
  final RxBool isLoading = false.obs;

  // Verification Screen variables
  List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());
  var currentVerificationId = ''.obs;
  var activeIndex = 0.obs;
  var timerMaxSeconds = 60;
  var currentSeconds = 0.obs;
  var isTimerActive = true.obs;
  Timer? timer;

  @override
  void onInit() {
    super.onInit();
    for (int i = 0; i < 6; i++) {
      focusNodes[i].addListener(() {
        if (focusNodes[i].hasFocus) {
          otpControllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: otpControllers[i].text.length,
          );
        }
      });
    }
  }

  @override
  void onClose() {
    numberController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    timer?.cancel();
    super.onClose();
  }

  String _formatNumber(String raw) {
    String cleaned = raw.trim();
    while (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return countryCode.value + cleaned;
  }

  void onPhoneChanged(String value) {
    if (value.trim().isEmpty) {
      formattedPreview.value = '';
    } else {
      formattedPreview.value = _formatNumber(value);
    }
  }

  Future<void> sendOtp() async {
    if (!phoneFormKey.currentState!.validate()) return;
    
    final fullNumber = _formatNumber(numberController.text);
    final currentAppUser = AuthController.instance.currentUser;

    if (currentAppUser.number == fullNumber) {
      AppStyle().failedSnackBar(message: 'This phone number is already set to your account.');
      return;
    }

    isLoading.value = true;

    try {
      // 1. Check if this phone number is already taken by another account in Firestore
      final existingUsers = await FirebaseFirestore.instance
          .collection('Users')
          .where('number', isEqualTo: fullNumber)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        final doc = existingUsers.docs.first;
        if (doc.id != currentAppUser.userId) {
          isLoading.value = false;
          AppStyle().failedSnackBar(
            message: 'This phone number is already registered with another account.',
          );
          return;
        }
      }

      // 2. Request OTP from Firebase Auth
      FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          isLoading.value = false;
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final hasPhone = user.providerData.any((p) => p.providerId == 'phone');
              if (hasPhone) {
                await user.updatePhoneNumber(credential);
              } else {
                await user.linkWithCredential(credential);
              }
              await UserApi.updateUserData(
                userId: currentAppUser.userId,
                data: {
                  'number': fullNumber,
                  'phone_linked': true,
                },
                isSet: true,
              );
              currentAppUser.number = fullNumber;
              AppStyle().successSnackBar(message: 'Phone number linked successfully');
              Get.until((route) => Get.currentRoute == '/AccountSettingsScreen' || route.isFirst);
            }
          } catch (e) {
            AppStyle().failedSnackBar(message: 'Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          isLoading.value = false;
          String msg = e.message ?? e.toString();
          if (e.code == 'invalid-phone-number') {
            msg = 'The provided phone number is not valid.';
          } else if (e.code == 'too-many-requests') {
            msg = 'Too many requests. Please try again later.';
          }
          AppStyle().failedSnackBar(message: msg);
        },
        codeSent: (String verificationId, int? resendToken) {
          currentVerificationId.value = verificationId;
          isLoading.value = false;
          // Clear OTP boxes
          for (var c in otpControllers) {
            c.clear();
          }
          Get.to(() => VerifyUpdatePhoneScreen(
                verificationId: verificationId,
                number: fullNumber,
              ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          currentVerificationId.value = verificationId;
          isLoading.value = false;
        },
        timeout: const Duration(seconds: 60),
      ).catchError((e) {
        isLoading.value = false;
        AppStyle().failedSnackBar(message: e.toString());
      });
    } catch (e) {
      isLoading.value = false;
      AppStyle().failedSnackBar(message: e.toString());
    }
  }

  void startTimer() {
    currentSeconds.value = 0;
    isTimerActive.value = true;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSeconds.value >= timerMaxSeconds) {
        timer.cancel();
        isTimerActive.value = false;
      } else {
        currentSeconds.value++;
      }
    });
  }

  String get timerText {
    final int remainingSeconds = timerMaxSeconds - currentSeconds.value;
    final int minutes = remainingSeconds ~/ 60;
    final int seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> verifyOtp(String fullNumber) async {
    String smsCode = otpControllers.map((c) => c.text).join();
    if (smsCode.length < 6) {
      AppStyle().failedSnackBar(message: 'Please enter the complete 6-digit OTP code');
      return;
    }

    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final currentAppUser = AuthController.instance.currentUser;

      // 1. Strict duplicate check before binding
      final existingUsers = await FirebaseFirestore.instance
          .collection('Users')
          .where('number', isEqualTo: fullNumber)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty && existingUsers.docs.first.id != currentAppUser.userId) {
        isLoading.value = false;
        AppStyle().failedSnackBar(
          message: 'This phone number is already registered with another account.',
        );
        return;
      }

      // 2. Build credential from OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: currentVerificationId.value,
        smsCode: smsCode,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final hasPhone = user.providerData.any((p) => p.providerId == 'phone');
        if (hasPhone) {
          await user.updatePhoneNumber(credential);
        } else {
          await user.linkWithCredential(credential);
        }

        // 3. Update Firestore
        await UserApi.updateUserData(
          userId: currentAppUser.userId,
          data: {
            'number': fullNumber,
            'phone_linked': true,
          },
          isSet: true,
        );

        // 4. Update local memory state
        currentAppUser.number = fullNumber;

        isLoading.value = false;
        AppStyle().successSnackBar(message: 'Phone number verified and bound successfully!');

        // Navigate back to Account Settings
        Get.until((route) => Get.currentRoute == '/AccountSettingsScreen' || route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      String msg = e.message ?? e.toString();
      if (e.code == 'invalid-verification-code' || e.code == 'session-expired') {
        msg = 'Invalid OTP code. Please check and try again.';
      } else if (e.code == 'credential-already-in-use') {
        msg = 'This phone number is already associated with another account.';
      } else if (e.code == 'provider-already-linked') {
        msg = 'Phone number is already linked to this account.';
      }
      AppStyle().failedSnackBar(message: msg);
    } catch (e) {
      isLoading.value = false;
      AppStyle().failedSnackBar(message: e.toString());
    }
  }
}
