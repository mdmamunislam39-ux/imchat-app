import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart' hide User;
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/services/device_session_service.dart';

abstract class AuthApi {
  static final AuthController _authController = AuthController.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '518076067996-48s6rn0q2qe4197hp9a5f9fvb1kibrd3.apps.googleusercontent.com',
  );

  static Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      DialogHelper.showProcessingDialog();
      
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Send email verification
      await sendEmailVerification(userCredential.user!);
    } catch (e) {
      DialogHelper.closeDialog();
      
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_sign_up_with_email_and_password".trParams(
          {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> sendEmailVerification(User user) async {
    // Check status
    if (!user.emailVerified) {
      await user.sendEmailVerification();
      // Go to verify email screen
      Future(() => Get.offAllNamed(AppRoutes.verifyEmail));
      // Sign-out the user to ensure the email is verified first.
      await _firebaseAuth.signOut();
    }
  }

  static Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Get User
      User user = userCredential.user!;

      // Check verification status
      if (!user.emailVerified) {
        // Send email verification
        await sendEmailVerification(user);

        return;
      }

      // Set login provider
      _authController.provider = LoginProvider.email;

      // Check account in database
      await _authController.checkUserAccount();
      //
    } catch (e) {
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_sign_in_with_email_and_password".trParams(
          {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> requestPasswordRecovery(String email) async {
    try {
      // Send request
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      // Success message
      DialogHelper.showAlertDialog(
        icon: const Icon(Icons.check_circle, color: primaryColor),
        title: Text('success'.tr),
        content: Text(
          "password_reset_email_sent_successfully".tr,
          style: const TextStyle(fontSize: 16),
        ),
        actionText: 'OKAY'.tr,
        action: () {
          // Close dialog
          Get.back();
          // Close page
          Get.back();
        },
      );
    } catch (e) {
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_send_password_reset_request".trParams(
          {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      DialogHelper.showProcessingDialog();

      // Clear any previous cached account session so user can pick account
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        DialogHelper.closeDialog();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);

      // Set login provider
      _authController.provider = LoginProvider.google;

      // Check user account in database
      await _authController.checkUserAccount();
    } on FirebaseAuthException catch (e) {
      DialogHelper.closeDialog();
      debugPrint('[AuthApi] FirebaseAuthException in signInWithGoogle: ${e.code} - ${e.message}');
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        e.message ?? 'Authentication failed. Please try again.',
      );
    } catch (e, stack) {
      DialogHelper.closeDialog();
      debugPrint('[AuthApi] Error in signInWithGoogle: $e\n$stack');
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_sign_in_with_google".trParams(
          {'error': e.toString()},
        ),
      );
    }
  }

  /// Links the current user with a Google account
  static Future<bool> linkGoogleAccount() async {
    try {
      DialogHelper.showProcessingDialog();

      // Sign out from GoogleSignIn cache to let user choose account
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        DialogHelper.closeDialog();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.linkWithCredential(credential);

        // Update in Firestore
        await UserApi.updateUserData(
          userId: currentUser.uid,
          data: {
            'email': googleUser.email,
            'user_email': googleUser.email,
            'google_linked': true,
          },
          isSet: true,
        );

        // Update local memory user
        final appUser = _authController.currentUser;
        appUser.email = googleUser.email;
        appUser.googleLinked = true;

        DialogHelper.closeDialog();
        DialogHelper.showSnackbarMessage(
          SnackMsgType.success,
          'Google account linked successfully!',
        );
        return true;
      }
      DialogHelper.closeDialog();
      return false;
    } on FirebaseAuthException catch (e) {
      DialogHelper.closeDialog();
      debugPrint('[AuthApi] linkGoogleAccount FirebaseAuthException: ${e.code} - ${e.message}');
      String msg = e.message ?? e.toString();
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        msg = 'This Google account is already linked with another user account.';
      } else if (e.code == 'provider-already-linked') {
        msg = 'Google account is already linked to this user.';
      }
      DialogHelper.showSnackbarMessage(SnackMsgType.error, msg);
      return false;
    } catch (e, stack) {
      DialogHelper.closeDialog();
      debugPrint('[AuthApi] linkGoogleAccount Error: $e\n$stack');
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_sign_in_with_google".trParams(
          {'error': e.toString()},
        ),
      );
      return false;
    }
  }

  /// Unlinks Google account from current user
  static Future<bool> unlinkGoogleAccount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return false;

      // Make sure user has at least one other login provider
      if (currentUser.providerData.length <= 1) {
        DialogHelper.showSnackbarMessage(
          SnackMsgType.error,
          'You must keep at least one login method (e.g. Phone number) before unlinking Google.',
        );
        return false;
      }

      DialogHelper.showProcessingDialog();
      await currentUser.unlink('google.com');

      await UserApi.updateUserData(
        userId: currentUser.uid,
        data: {
          'google_linked': false,
        },
        isSet: true,
      );

      final appUser = _authController.currentUser;
      appUser.googleLinked = false;

      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(
        SnackMsgType.success,
        'Google account unlinked successfully.',
      );
      return true;
    } catch (e) {
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return false;
    }
  }

  //
  // LOGIN WITH APPLE - SECTION
  //
  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  static String _generateNonce([int length = 32]) {
    // Define 64 characters string
    const String charset64 =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    // Creates a cryptographically secure random number generator.
    final random = Random.secure();
    return List.generate(
        length, (_) => charset64[random.nextInt(charset64.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  static String _sha256ofString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Send sign in request
  static Future<void> signInWithApple() async {
    try {
      // Check iOS Platform
      if (!Platform.isIOS) {
        DialogHelper.showSnackbarMessage(
            SnackMsgType.error, 'login_with_apple_not_available'.tr);
        return;
      }
      // To prevent replay attacks with the credential returned from Apple, we
      // include a nonce in the credential request. When signing in in with
      // Firebase, the nonce in the id token returned by Apple, is expected to
      // match the sha256 hash of `rawNonce`.
      final String rawNonce = _generateNonce();
      final String nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Get Apple User Fullname
      final String appleUserName =
          "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}";

      final AuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      // Start loading
      DialogHelper.showProcessingDialog(barrierDismissible: false);
      //
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Update Firebase User display name
      await userCredential.user!.updateDisplayName(appleUserName);

      // Set login provider
      _authController.provider = LoginProvider.apple;

      // Check user account in database
      await _authController.checkUserAccount();
    } catch (e) {
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_sign_in_with_apple".trParams(
          {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> signOut() async {
    try {
      await DeviceSessionService.deactivateCurrentSession();
      await Get.deleteAll(force: true);
    //  await GoogleSignIn().signOut();
      await _firebaseAuth.signOut();
      Get.offAllNamed(AppRoutes.phoneSignIn);

      debugPrint('signOut() -> success');
    } catch (e) {
      debugPrint('signOut() -> error: $e');
    }
  }


}
