import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/services/firebase_messaging_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.notification.status;
    final fcmGranted = await FirebaseMessagingService.isNotificationPermissionGranted();
    if (mounted) {
      setState(() {
        _isPermissionGranted = status.isGranted || fcmGranted;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestOrTogglePermission() async {
    final status = await Permission.notification.status;

    if (status.isPermanentlyDenied) {
      // Open App Settings if permission was permanently denied by user
      await openAppSettings();
      return;
    }

    final granted = await FirebaseMessagingService.requestNotificationPermission();
    final pStatus = await Permission.notification.request();

    if (mounted) {
      setState(() {
        _isPermissionGranted = granted || pStatus.isGranted;
      });
    }

    if (!_isPermissionGranted && (pStatus.isPermanentlyDenied || pStatus.isDenied)) {
      Get.snackbar(
        'Notification Permission',
        'Please enable notifications in system settings to receive messages and call alerts.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        mainButton: TextButton(
          onPressed: () => openAppSettings(),
          child: const Text('Open Settings', style: TextStyle(color: Colors.amberAccent)),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      final flnp = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'Notifications for chat and group messages',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await flnp.show(
        id: 99999,
        title: 'imChat Notification Test',
        body: 'Notifications are working properly on your device! 🔔',
        notificationDetails: notifDetails,
      );

      Get.snackbar(
        'Success',
        'Test notification sent! Check your notification bar.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade800,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to show test notification: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('App Notification Permission'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isPermissionGranted
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPermissionGranted ? Icons.notifications_active : Icons.notifications_off,
                          color: _isPermissionGranted ? Colors.green : Colors.red,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App Notifications',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoading
                                  ? 'Checking...'
                                  : (_isPermissionGranted ? 'Allowed / Active' : 'Disabled / Not Allowed'),
                              style: TextStyle(
                                fontSize: 14,
                                color: _isPermissionGranted ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPermissionGranted,
                        activeColor: primaryColor,
                        onChanged: (val) => _requestOrTogglePermission(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Enable notifications to receive real-time messages, incoming voice/video calls, and live room alerts.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  if (!_isPermissionGranted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _requestOrTogglePermission,
                        icon: const Icon(Icons.settings),
                        label: const Text('Allow Notification Permission', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions Section
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.send_to_mobile, color: primaryColor),
                    title: const Text('Send Test Notification'),
                    subtitle: const Text('Verify that alerts appear properly on this device'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _sendTestNotification,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.app_settings_alt, color: Colors.blueAccent),
                    title: const Text('System App Settings'),
                    subtitle: const Text('Manage channel sounds, badges and system restrictions'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => openAppSettings(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

