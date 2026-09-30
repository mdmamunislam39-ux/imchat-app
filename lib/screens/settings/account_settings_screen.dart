import 'package:chat_messenger/api/auth_api.dart';
import 'package:chat_messenger/components/svg_icon.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/screens/settings/update_phone_screen.dart';
import 'package:chat_messenger/models/user.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final RxBool _isActionLoading = false.obs;

  bool _isProviderLinked(String providerId) {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == providerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: CustomAppBar(
        title: Text('Account Settings'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.12),
                      primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Binding'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bind both Phone and Google to log in seamlessly with either method anytime.'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Connected Accounts'.tr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 14),

              // Phone Number Binding Card
              Obx(() {
                final user = AuthController.instance.currentUser;
                final bool hasPhone = user.number.isNotEmpty || _isProviderLinked('phone');
                final String phoneText = user.number.isNotEmpty
                    ? user.number
                    : (auth.FirebaseAuth.instance.currentUser?.phoneNumber ?? '');

                return _buildBindingCard(
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_android_rounded, color: Colors.blue, size: 24),
                  ),
                  title: 'Phone Number'.tr,
                  subtitle: hasPhone && phoneText.isNotEmpty ? phoneText : 'Not connected'.tr,
                  isLinked: hasPhone && phoneText.isNotEmpty,
                  actionButton: ElevatedButton(
                    onPressed: () {
                      Get.to(() => const UpdatePhoneScreen())?.then((_) {
                        setState(() {});
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (hasPhone && phoneText.isNotEmpty)
                          ? Colors.grey.withValues(alpha: 0.12)
                          : primaryColor,
                      foregroundColor: (hasPhone && phoneText.isNotEmpty)
                          ? Colors.black87
                          : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      (hasPhone && phoneText.isNotEmpty) ? 'Change'.tr : 'Bind Now'.tr,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Google Account Binding Card
              Obx(() {
                final user = AuthController.instance.currentUser;
                final bool isGoogleLinked = _isProviderLinked('google.com') ||
                    user.googleLinked ||
                    (user.email.isNotEmpty && user.loginProvider == LoginProvider.google);
                final String emailText = user.email.isNotEmpty
                    ? user.email
                    : (auth.FirebaseAuth.instance.currentUser?.email ?? '');

                return _buildBindingCard(
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgIcon(
                      'assets/icons/google_login.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  title: 'Google Account'.tr,
                  subtitle: isGoogleLinked && emailText.isNotEmpty
                      ? emailText
                      : (isGoogleLinked ? 'Connected'.tr : 'Not connected'.tr),
                  isLinked: isGoogleLinked,
                  actionButton: isGoogleLinked
                      ? OutlinedButton(
                          onPressed: _isActionLoading.value
                              ? null
                              : () {
                                  DialogHelper.showAlertDialog(
                                    icon: const Icon(Icons.link_off, color: Colors.red, size: 40),
                                    title: Text('Unlink Google Account'.tr),
                                    content: Text(
                                      'Are you sure you want to unlink your Google account?'.tr,
                                      textAlign: TextAlign.center,
                                    ),
                                    actionText: 'Unlink'.tr,
                                    action: () async {
                                      Get.back();
                                      _isActionLoading.value = true;
                                      final success = await AuthApi.unlinkGoogleAccount();
                                      _isActionLoading.value = false;
                                      if (success) {
                                        setState(() {});
                                      }
                                    },
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Unlink'.tr,
                            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _isActionLoading.value
                              ? null
                              : () async {
                                  _isActionLoading.value = true;
                                  final success = await AuthApi.linkGoogleAccount();
                                  _isActionLoading.value = false;
                                  if (success) {
                                    setState(() {});
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Bind Google'.tr,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBindingCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required bool isLinked,
    required Widget actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLinked
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLinked ? 'Linked'.tr : 'Unlinked'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLinked ? Colors.green[700] : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isLinked ? Colors.black54 : Colors.grey[400],
                    fontWeight: isLinked ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          actionButton,
        ],
      ),
    );
  }
}
