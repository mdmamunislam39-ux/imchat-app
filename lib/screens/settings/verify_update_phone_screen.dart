import 'package:chat_messenger/screens/settings/controller/update_phone_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class VerifyUpdatePhoneScreen extends StatelessWidget {
  final String verificationId;
  final String number;

  const VerifyUpdatePhoneScreen({
    super.key,
    required this.verificationId,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final UpdatePhoneController controller = Get.find<UpdatePhoneController>();
    controller.startTimer();

    final size = MediaQuery.of(context).size;

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
                SizedBox(height: size.height * 0.03),

                // Back Button
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

                const SizedBox(height: 10),

                // Lottie animation
                Lottie.asset('assets/file/code.json', height: 150),

                const SizedBox(height: 16),

                // Title
                const Text(
                  'Verify & Bind Number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    children: [
                      TextSpan(text: 'Enter the 6-digit OTP code sent to '.tr),
                      TextSpan(
                        text: maskedNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // 6-digit PIN boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => _buildCodeBox(index, context, controller),
                  ),
                ),

                const SizedBox(height: 30),

                // Timer & Resend
                Obx(
                  () => controller.isTimerActive.value
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Resend code in ${controller.timerText}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        )
                      : TextButton(
                          onPressed: () {
                            controller.sendOtp();
                            controller.startTimer();
                          },
                          child: Text(
                            'Resend Code'.tr,
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 36),

                // Submit Button
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.verifyOtp(number),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: controller.isLoading.value
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
                                Icon(Icons.check_circle_outline_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Verify & Bind',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(
      int index, BuildContext context, UpdatePhoneController controller) {
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: controller.activeIndex.value == index
              ? const Color(0xFF6C63FF)
              : Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller.otpControllers[index],
          focusNode: controller.focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 5) {
                FocusScope.of(context)
                    .requestFocus(controller.focusNodes[index + 1]);
                controller.activeIndex.value = index + 1;
              } else {
                controller.focusNodes[index].unfocus();
                // Auto verify when 6th digit is entered
                controller.verifyOtp(number);
              }
            } else {
              if (index > 0) {
                FocusScope.of(context)
                    .requestFocus(controller.focusNodes[index - 1]);
                controller.activeIndex.value = index - 1;
              }
            }
          },
          onTap: () {
            controller.activeIndex.value = index;
          },
        ),
      ),
    );
  }
}
