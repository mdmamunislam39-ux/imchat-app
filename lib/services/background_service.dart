import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to handle background execution
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  /// Initialize the background service
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure notification for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'audio_room_channel', // id
      'Audio Room Service', // title
      description: 'Used for keeping audio room active in background',
      importance: Importance.low, // Low importance to avoid sound
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // Auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'audio_room_channel',
        initialNotificationTitle: 'VoiceRoom is running now',
        initialNotificationContent: 'click back to the VoiceRoom',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // Auto start service
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the service
  Future<void> startService() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      debugPrint('🔄 [BackgroundService] Starting background service...');
      await service.startService();
    }
  }

  /// Start the service with specific notification details for a call / room
  Future<void> startCallService({
    String? title,
    String? content,
  }) async {
    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        debugPrint('🔄 [BackgroundService] Starting call background service ($title)...');
        await service.startService();
      }
      final notifTitle = (title != null && title.isNotEmpty) ? title : 'VoiceRoom is running now';
      final notifContent = (content != null && content.isNotEmpty) ? content : 'click back to the VoiceRoom';
      await updateNotificationInfo(title: notifTitle, content: notifContent);
    } catch (e) {
      debugPrint('🔄 [BackgroundService] Error starting call service: $e');
    }
  }

  /// Stop the service
  Future<void> stopService() async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        debugPrint('🔄 [BackgroundService] Stopping background service...');
        service.invoke('stopService');
      }
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(id: 888);
    } catch (e) {
      debugPrint(
          '🔄 [BackgroundService] Error stopping background service: $e');
    }
  }

  /// Update the background notification title and content dynamically
  Future<void> updateNotificationInfo({
    String? title,
    String? content,
  }) async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('updateNotification', {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
        });
      }
    } catch (e) {
      debugPrint('🔄 [BackgroundService] Error updating notification: $e');
    }
  }
}

/// Entry point for background execution
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    debugPrint('🔄 [BackgroundService] Plugin registrant notice: $e');
  }

  // For flutter_background_service v2+
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('updateNotification').listen((event) {
      if (event != null) {
        final title = event['title'] as String? ?? 'Call in progress';
        final content = event['content'] as String? ?? 'Connected';
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    });
  }

  service.on('stopService').listen((event) async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(id: 888);
    } catch (_) {}
    service.stopSelf();
  });

  // Bring to foreground
  Timer.periodic(const Duration(seconds: 45), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Ping to keep alive
        debugPrint(
            '🔄 [BackgroundService] Service heartbeat: ${DateTime.now()}');

        // Update notification if needed
        // service.setForegroundNotificationInfo(
        //   title: "Audio Room Active",
        //   content: "Connected to room (Heartbeat: ${DateTime.now().minute}:${DateTime.now().second})",
        // );
      }
    }
  });
}

/// Handling iOS background execution
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
  return true;
}
