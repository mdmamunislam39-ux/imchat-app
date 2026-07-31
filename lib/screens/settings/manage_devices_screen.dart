import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import 'controller/manage_devices_controller.dart';
import '../../models/device_session_model.dart';

class ManageDevicesScreen extends StatelessWidget {
  const ManageDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ManageDevicesController());

    return Scaffold(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: const Text('Manage Devices'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (controller.currentSession.value != null) ...[
              _buildSectionTitle('Current Device'),
              _buildDeviceCard(
                context,
                controller.currentSession.value!,
                isCurrent: true,
                controller: controller,
              ),
              const SizedBox(height: 24),
            ],
            
            if (controller.otherActiveSessions.isNotEmpty) ...[
              _buildSectionTitle('Other Logged-in Devices'),
              ...controller.otherActiveSessions.map((session) => _buildDeviceCard(
                context,
                session,
                isCurrent: false,
                controller: controller,
              )),
              const SizedBox(height: 24),
            ],

            if (controller.loginHistory.isNotEmpty) ...[
              _buildSectionTitle('Recent Login History'),
              ...controller.loginHistory.map((session) => _buildHistoryCard(session)),
            ]
          ],
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DeviceSessionModel session, {required bool isCurrent, required ManageDevicesController controller}) {
    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  session.deviceType.toLowerCase().contains('web') ? Icons.computer : Icons.phone_android,
                  color: isCurrent ? Colors.green : Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        session.deviceType,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Currently Active',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Login Time', DateFormat('MMM d, yyyy h:mm a').format(session.loginTime)),
            _buildInfoRow('Last Active', timeago.format(session.lastActiveTime)),
            if (session.location != null) _buildInfoRow('Location', session.location!),
            if (!isCurrent) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showLogoutConfirmation(context, session, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Log Out Device'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DeviceSessionModel session) {
    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          session.deviceType.toLowerCase().contains('web') ? Icons.computer : Icons.phone_android,
          color: Colors.grey,
        ),
        title: Text(session.deviceName, style: const TextStyle(color: Colors.white)),
        subtitle: Text('Logged in: ${DateFormat('MMM d, h:mm a').format(session.loginTime)}\nLast active: ${timeago.format(session.lastActiveTime)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, DeviceSessionModel session, ManageDevicesController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'আপনি কি এই ডিভাইস থেকে অ্যাকাউন্ট লগআউট করতে চান?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.initiateLogoutFlow(context, session);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
