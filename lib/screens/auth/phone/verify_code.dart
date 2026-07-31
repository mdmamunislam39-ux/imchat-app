import 'dart:ui';
import 'package:chat_messenger/screens/auth/phone/controller/verify_code_conroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class VerifyCodeScreen extends StatelessWidget {
  final String verificatonId;
  final String number;

  const VerifyCodeScreen({
    super.key,
    required this.verificatonId,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final VerifyCodeController controller = Get.put(VerifyCodeController());

    final size = MediaQuery.of(context).size;

    // Mask the phone number for display: show first 4 and last 2, mask rest
    String maskedNumber = number;
    if (number.length > 6) {
      maskedNumber =
          '${number.substring(0, 4)}${'*' * (number.length - 6)}${number.substring(number.length - 2)}';
    }

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
            child: Column(
              children: [
                SizedBox(height: size.height * 0.04),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Lottie animation
                Lottie.asset('assets/file/code.json', height: 160),

                const SizedBox(height: 20),

                // Title
                const Text(
                  'Verify Your Number',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maskedNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6C63FF),
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                // OTP Input boxes
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 50,
                        height: 60,
                        child: Obx(() {
                          bool isFocused = controller.activeIndex.value == index;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isFocused
                                        ? const Color(0xFF6C63FF)
                                        : const Color(0xFF6C63FF).withValues(alpha: 0.5),
                                    width: 1.5, // Crisp, stable border
                                  ),
                                  // Vivid light purple glassmorphism background
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.25), 
                                  boxShadow: isFocused
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6C63FF)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: TextField(
                              controller: controller.controllers[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // Light and clean text color
                              ),
                            focusNode: controller.focusNodes[index],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false, // Prevent global theme from adding a white background
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (value.length >= 6) {
                                // Autofill or paste
                                for (int i = 0; i < 6; i++) {
                                  controller.controllers[i].text = value[i];
                                }
                                controller.focusNodes[5].unfocus();
                                controller.verifyOtp(verificatonId, context, number);
                              } else if (value.isNotEmpty) {
                                // Ensure only 1 char is kept in THIS box if typing manually
                                if (value.length > 1) {
                                   controller.controllers[index].text = value.substring(value.length - 1);
                                }
                                controller.focusNodes[index].unfocus();
                                if (index < 5) {
                                  controller.focusNodes[index + 1].requestFocus();
                                } else {
                                  // Last digit entered — auto-verify
                                  controller.verifyOtp(verificatonId, context, number);
                                }
                              } else if (index > 0) {
                                controller.focusNodes[index - 1].requestFocus();
                              }
                            },
                                  ),
                                ),
                              ),
                            );
                          }),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // Timer / Resend
                Obx(() {
                  if (controller.isTimerActive.value) {
                    final remaining =
                        controller.timerMaxSeconds - controller.currentSeconds.value;
                    final progress =
                        controller.currentSeconds.value / controller.timerMaxSeconds;

                    return Column(
                      children: [
                        // Circular timer
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0 - progress,
                                strokeWidth: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6C63FF),
                                ),
                              ),
                              Text(
                                '${remaining}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Waiting for code...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }

                  // Timer expired — show resend
                  return GestureDetector(
                    onTap: () async {
                      await controller.resendOtp(context, number);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C63FF).withValues(alpha: 0.2),
                            const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF6C63FF),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Resend Code',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 30),

                // Verify button (fallback — auto-verify triggers on last digit)
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: controller.isSubmitting.value
                            ? null
                            : () async {
                                await controller.verifyOtp(
                                    verificatonId, context, number);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: controller.isSubmitting.value
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
                                  Icon(Icons.verified_user_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Verify & Continue',
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
                  'Code auto-fills when SIM is available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                SizedBox(height: size.height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
