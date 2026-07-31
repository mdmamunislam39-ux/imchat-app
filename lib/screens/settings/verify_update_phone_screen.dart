import 'package:chat_messenger/screens/settings/controller/update_phone_controller.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/config/theme_config.dart';

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

    String maskedNumber = number;
    if (number.length > 6) {
      maskedNumber =
          '${number.substring(0, 4)}${'*' * (number.length - 6)}${number.substring(number.length - 2)}';
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Verify Phone'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Verification Code'.tr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  children: [
                    TextSpan(text: 'We have sent a 6-digit code to '.tr),
                    TextSpan(
                      text: maskedNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // OTP Input Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _buildCodeBox(index, context, controller),
                ),
              ),
              const SizedBox(height: 30),
              
              // Timer & Resend
              Center(
                child: Obx(
                  () => controller.isTimerActive.value
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 5),
                            Text(
                              'Resend code in ${controller.timerText}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
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
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ),
              const Spacer(),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => controller.verifyOtp(number),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Verify & Update'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index, BuildContext context, UpdatePhoneController controller) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: controller.activeIndex.value == index
              ? primaryColor
              : Colors.transparent,
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
                FocusScope.of(context).requestFocus(controller.focusNodes[index + 1]);
                controller.activeIndex.value = index + 1;
              } else {
                controller.focusNodes[index].unfocus();
                // Auto verify when last digit is entered
                controller.verifyOtp(number);
              }
            } else {
              if (index > 0) {
                FocusScope.of(context).requestFocus(controller.focusNodes[index - 1]);
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
