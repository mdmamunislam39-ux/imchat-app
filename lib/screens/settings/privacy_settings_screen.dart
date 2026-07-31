import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Privacy Settings'.tr),
      ),
      body: Center(
        child: Text('Privacy settings coming soon.'),
      ),
    );
  }
}
