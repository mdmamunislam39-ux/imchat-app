import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';

class AdminInvitationRewardScreen extends StatefulWidget {
  const AdminInvitationRewardScreen({super.key});

  @override
  State<AdminInvitationRewardScreen> createState() => _AdminInvitationRewardScreenState();
}

class _AdminInvitationRewardScreenState extends State<AdminInvitationRewardScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<GlobalSettingsService>()) {
      _amountController.text = Get.find<GlobalSettingsService>().invitationRewardDiamonds.value.toString();
    } else {
      _amountController.text = '100';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final val = int.tryParse(_amountController.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid positive number')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('global_settings')
          .doc('app_settings')
          .set({
            'invitationRewardDiamonds': val,
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation reward updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        title: const Text('Configure Invitation Reward', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2D1F3F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invitation Diamond Bonus',
              style: TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is the amount of Diamonds that BOTH the referrer and the new user will receive when a valid referral code is submitted.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Reward Amount (Diamonds)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.diamond, color: Colors.purpleAccent),
                filled: true,
                fillColor: const Color(0xFF2D1F3F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purpleAccent, width: 2),
                )
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  )
                ),
                child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
