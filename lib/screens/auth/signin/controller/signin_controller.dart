import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/screens/auth/phone/verify_code.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/auth_api.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/screens/auth/phone/controller/verify_code_conroller.dart';

class SignInController extends GetxController {
  // Controllers
  final GlobalKey<FormState> emailFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;

  ///////////////for phone//////////////
  final GlobalKey<FormState> phoneFormKey = GlobalKey<FormState>();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  ConfirmationResult? webConfirmationResult;

  @override
  void onInit() {
    debugPrint('SignInController() -> onInit');
    super.onInit();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    numberController.dispose();
    otpController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    obscurePassword.toggle();
  }

  Future<void> signInWithEmailAndPassword() async {
    // Process valid data
    if (emailFormKey.currentState!.validate()) {
      // Update loading
      isLoading.value = true;

      await AuthApi.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      isLoading.value = false;
    }
  }


  int? _lastResendToken;

  // for phone auth
  Future<String> phoneAuthSendOtp(BuildContext context, String phoneNumber, {bool isResend = false}) async {
    Completer<String> completer = Completer<String>();
    // Removed AppStyle().progressDialog(context) to prevent blocking the UI/reCAPTCHA
    try {
      // Clear stale sessions before a brand new request to prevent 'unusual activity' bans
      if (!isResend) {
        _lastResendToken = null;
        // Removed signOut() here as it might disrupt the Firebase Auth state
      }

      if (kIsWeb) {
        ConfirmationResult confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(phoneNumber);
        webConfirmationResult = confirmationResult;
        String result = "web_verification_id";
        if (!isResend) {
          Get.to(() => VerifyCodeScreen(
                verificatonId: result,
                number: phoneNumber,
              ));
        } else {
          if (Get.isRegistered<VerifyCodeController>()) {
            Get.find<VerifyCodeController>().currentVerificationId.value = result;
          }
        }
        if (!completer.isCompleted) completer.complete(result);
      } else {
        FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: isResend ? _lastResendToken : null,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-verification triggered (SIM available)
            try {
              await FirebaseAuth.instance.signInWithCredential(credential);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                var doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
                if (doc.exists) {
                  await AuthController.instance.checkUserAccount();
                } else {
                  Get.offAllNamed('/signup', arguments: {'number': phoneNumber});
                }
              }
              if (!completer.isCompleted) completer.complete("success");
            } catch (_) {}
          },
          verificationFailed: (FirebaseAuthException e) {
            if (e.code == 'invalid-phone-number') {
              AppStyle().failedSnackBar(message: "The provided phone number is not valid.");
            } else if (e.code == 'too-many-requests') {
              AppStyle().failedSnackBar(message: "Too many attempts. Please try again later or use a testing number.");
            } else {
              AppStyle().failedSnackBar(message: e.message ?? e.toString());
            }
            if (!completer.isCompleted) completer.completeError(e);
          },
          codeSent: (String verificationId, int? resendToken) async {
            _lastResendToken = resendToken;
            if (!isResend) {
              Get.to(() => VerifyCodeScreen(
                    verificatonId: verificationId,
                    number: phoneNumber,
                  ));
            } else {
              if (Get.isRegistered<VerifyCodeController>()) {
                Get.find<VerifyCodeController>().currentVerificationId.value = verificationId;
              }
            }
            if (!completer.isCompleted) completer.complete(verificationId);
          },
          timeout: const Duration(seconds: 60),
          codeAutoRetrievalTimeout: (String verificationId) {
             if (!completer.isCompleted) {
                // We don't necessarily want to throw an error on auto retrieval timeout.
                // It just means we have to rely on user entering the code manually.
                // However, if the code wasn't sent, then codeSent would not have fired.
                // We will just let it be, but if we haven't completed, we should complete to prevent hang.
                // Wait, codeAutoRetrievalTimeout is called after codeSent if SMS auto-retrieval fails.
                // If codeSent was called, completer is already completed!
             }
          },
        ).catchError((e) {
           AppStyle().failedSnackBar(message: e.toString());
           if (!completer.isCompleted) completer.completeError(e);
        });
      }
    } catch (e) {
      AppStyle().failedSnackBar(message: e.toString());
      if (!completer.isCompleted) completer.completeError(e);
    }
    
    // Add a 65-second timeout to the completer so it doesn't hang indefinitely if Firebase silently fails
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('OTP request timed out. Please check your internet connection or Firebase setup.'));
          AppStyle().failedSnackBar(message: "OTP Timeout! Please ensure SHA-1/SHA-256 are added in Firebase Console and Play Integrity API is enabled.");
        }
        return "timeout";
      },
    );
  }

  //phone auth verify otp
  Future<String> phoneAuthVerifyOtp(String verificationId, String smsCode, BuildContext context) async {
    String result = "An error is occurred";
    FirebaseAuth auth = FirebaseAuth.instance;
    // Removed AppStyle().progressDialog(context)
    try {
      if (kIsWeb && webConfirmationResult != null) {
        await webConfirmationResult!.confirm(smsCode);
        result = "success";
      } else {
        // Create a PhoneAuthCredential with the code
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId, smsCode: smsCode);

        // Sign the user in (or link) with the credential
        await auth.signInWithCredential(credential);
        result = "success";
      }
    } catch (e) {
      result = e.toString();
    }
    return result;
  }



  
}
