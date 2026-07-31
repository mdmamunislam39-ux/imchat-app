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
        initialNotificationTitle: 'Audio Room Active',
        initialNotificationContent: 'You are connected to an audio room',
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

  /// Stop the service
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      debugPrint('🔄 [BackgroundService] Stopping background service...');
      service.invoke('stopService');
    }
  }
}

/// Entry point for background execution
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter_background_service v2+
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
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
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
