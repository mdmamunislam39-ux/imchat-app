import 'package:chat_messenger/screens/settings/controller/update_phone_controller.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';

class UpdatePhoneScreen extends StatelessWidget {
  const UpdatePhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UpdatePhoneController());

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Change Phone Number'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your new phone number'.tr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We will send you a 6-digit verification code to confirm your new number.'.tr,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              Form(
                key: controller.phoneFormKey,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (country) {
                          controller.countryCode.value = country.dialCode ?? '+880';
                          controller.isoCountryCode.value = country.code ?? 'BD';
                          controller.onPhoneChanged(controller.numberController.text);
                        },
                        initialSelection: 'BD',
                        favorite: const ['+880', 'BD'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: const TextStyle(color: Colors.black87),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: controller.numberController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.black87),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onChanged: controller.onPhoneChanged,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            if (value.length < 6) {
                              return 'Invalid phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Obx(() => Center(
                    child: Text(
                      controller.formattedPreview.value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: primaryColor,
                      ),
                    ),
                  )),
              const Spacer(),
              Obx(() {
                return SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.sendOtp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Send OTP'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
}
