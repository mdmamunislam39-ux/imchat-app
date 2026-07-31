import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/screens/auth/signin/controller/signin_controller.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class PhoneVerificationScreen extends GetView<SignInController> {
  PhoneVerificationScreen({super.key});

  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final RxString countryCode = '+880'.obs;
  final RxString isoCountryCode = 'BD'.obs;
  final RxString formattedPreview = ''.obs;
  final RxBool isSubmitting = false.obs;

  /// Strips leading zeros and builds the full international number
  String _formatNumber(String raw) {
    String cleaned = raw.trim();
    // Remove all leading zeros
    while (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return countryCode.value + cleaned;
  }

  /// Updates the live preview as the user types
  void _onPhoneChanged(String value) {
    if (value.trim().isEmpty) {
      formattedPreview.value = '';
    } else {
      formattedPreview.value = _formatNumber(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D2B),
              Color(0xFF1A1A3E),
              Color(0xFF0D0D2B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.06),

                  // Lottie animation
                  Lottie.asset('assets/file/phone.json', height: 180),

                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Welcome to imChat',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter your phone number to get started',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Phone input card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone Number',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Country code picker
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: CountryCodePicker(
                                onChanged: (value) {
                                  countryCode.value = value.toString();
                                  isoCountryCode.value = value.code!;
                                  // Re-trigger preview
                                  _onPhoneChanged(_phoneController.text);
                                },
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                dialogTextStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                initialSelection: 'BD',
                                favorite: const ['+880', 'BD'],
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                alignLeft: false,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Phone number input
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(13),
                                ],
                                onChanged: _onPhoneChanged,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return "Please enter your number";
                                  }
                                  // Strip zeros for validation
                                  String cleaned = val.trim();
                                  while (cleaned.startsWith('0')) {
                                    cleaned = cleaned.substring(1);
                                  }
                                  if (cleaned.length < 7) {
                                    return 'Number is too short';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Phone number',
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.08),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6C63FF),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Live formatted preview
                        const SizedBox(height: 14),
                        Obx(() {
                          if (formattedPreview.value.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_forwarded_rounded,
                                  size: 16,
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formattedPreview.value,
                                  style: const TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Submit button
                  Obx(() => SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isSubmitting.value
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    isSubmitting.value = true;
                                    try {
                                      final number = _formatNumber(
                                          _phoneController.text);
                                      await controller.phoneAuthSendOtp(
                                              context, number);
                                    } catch (e) {
                                      AppStyle().failedSnackBar(
                                          message:
                                              'Failed to send OTP. Please try again.');
                                    } finally {
                                      isSubmitting.value = false;
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isSubmitting.value
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Send OTP',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      )),

                  const SizedBox(height: 20),
                  Text(
                    'We will send you a verification code',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  SizedBox(height: size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
