import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:chat_messenger/services/agora_token_service.dart' as import_agora;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/notification_helper.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:get/get.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

const MethodChannel _appVisibilityChannel = MethodChannel('com.imchatapp/app_visibility');

Future<void> _showIncomingCallNotification(RemoteMessage message) async {
  final callData = message.data['call'] != null 
      ? jsonDecode(message.data['call']) 
      : {};
  final String callId = callData['callerId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
  final String callerName = callData['callerName'] ?? 'Incoming Call';
  final String avatarUrl = callData['callerPhotoUrl'] ?? '';

  // Pre-fetch Agora token in the background so it's instantly available in cache when answered!
  try {
    import_agora.AgoraTokenService.instance.generateToken(channelName: callId, uid: 0);
  } catch (_) {}

  CallKitParams callKitParams = CallKitParams(
    id: callId,
    nameCaller: callerName,
    appName: 'imChat',
    avatar: avatarUrl,
    handle: 'imChat Video/Audio Call',
    type: 0,
    missedCallNotification: const NotificationParams(
      showNotification: true,
      isShowCallback: false,
      subtitle: 'Missed call',
      callbackText: 'Call back',
    ),
    duration: 45000,
    extra: message.data,
    android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: avatarUrl.isNotEmpty ? avatarUrl : 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        textAccept: 'Accept',
        textDecline: 'Decline',
    ),
    ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
}

Future<void> _showCustomChatNotification(RemoteMessage message) async {
  if (!Platform.isAndroid) return; // iOS handles notification block natively
  
  final title = message.data['title'] ?? 'New Message';
  final body = message.data['body'] ?? '';
  final senderAvatar = message.data['senderAvatar'] ?? '';

  String? avatarPath;
  if (senderAvatar.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(senderAvatar));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(response.bodyBytes);
        avatarPath = file.path;
      }
    } catch (e) {
      debugPrint('Failed to load avatar: $e');
    }
  }

  final androidDetails = AndroidNotificationDetails(
    'chat_messages',
    'Chat Messages',
    channelDescription: 'Notifications for chat and group messages',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    category: AndroidNotificationCategory.message,
    largeIcon: avatarPath != null ? FilePathAndroidBitmap(avatarPath) : null,
    styleInformation: MessagingStyleInformation(
      Person(
        name: title,
        icon: avatarPath != null ? BitmapFilePathAndroidIcon(avatarPath) : null,
      ),
      messages: [
        Message(body, DateTime.now(), null),
      ],
    ),
  );

  final details = NotificationDetails(android: androidDetails);
  final flnp = FlutterLocalNotificationsPlugin();
  
  await flnp.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher')
    ),
  );

  await flnp.show(
    id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title: title,
    body: body,
    notificationDetails: details,
    payload: jsonEncode(message.data),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase already initialized or error: $e');
  }

  debugPrint('Handling background message: ${message.messageId} -> data: ${message.data}');

  if (message.data['type'] == 'call') {
    await _showIncomingCallNotification(message);
  } else if (message.data['type'] == 'message' || message.data['type'] == 'group') {
    await _showCustomChatNotification(message);
  }
}

abstract class FirebaseMessagingService {
  static Future<void> _handleCallAccept(Map<String, dynamic> payload) async {
    try {
      // Bring app to foreground and wake screen if in background
      _appVisibilityChannel.invokeMethod('wakeScreen').catchError((_) {});
      _appVisibilityChannel.invokeMethod('bringToForeground').catchError((_) {});

      final callData = payload['call'] != null ? jsonDecode(payload['call']) : null;
      if (callData == null) return;
      final callerId = callData['callerId'];
      if (callerId == null) return;
      
      final isGroup = callData['receiverId'] == 'group_call';
      final Call callObj = Call.fromMap(data: callData);
      
      if (isGroup) {
        final currentUser = AuthController.instance.currentUser;
        
        // Navigate immediately for fast UI feedback
        Get.off(() => GroupCallScreen(isVideo: callObj.isVideo, call: callObj));
        
        // Handle Firestore update in background
        FirebaseFirestore.instance.collection('GroupCalls').doc(callerId).get().then((docSnapshot) {
          if (docSnapshot.exists) {
            docSnapshot.reference.update({
              'state': 'running',
              'receiverName': FieldValue.arrayUnion([currentUser.fullname]),
            });
          }
        });
      } else {
        // Navigate immediately for fast UI feedback
        if (callObj.isVideo) {
          Get.offNamed(AppRoutes.videoCall, arguments: {'call': callObj});
        } else {
          Get.offNamed(AppRoutes.voiceCall, arguments: {'call': callObj});
        }
        
        // Handle Firestore update in background
        FirebaseFirestore.instance.collection('Calls').doc(callerId).get().then((docSnapshot) {
          if (docSnapshot.exists) {
            docSnapshot.reference.update({
              'state': 'running'
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error accepting call from CallKit: $e');
    }
  }

  static Future<void> _handleCallDecline(Map<String, dynamic> payload) async {
    try {
      final callData = payload['call'] != null ? jsonDecode(payload['call']) : null;
      if (callData == null) return;
      final callerId = callData['callerId'];
      if (callerId == null) return;

      final isGroup = payload['type'] == 'group_call';
      if (!isGroup) {
        await FirebaseFirestore.instance.collection('Calls').doc(callerId).update({
          'state': 'decline',
        });
      }
    } catch (e) {
      debugPrint('Error declining call from CallKit: $e');
    }
  }

  static Future<void> _handleCallDeclineById(String callerId) async {
    try {
      // In a timeout, we assume it's a regular call unless we fetch the doc.
      // Easiest is just to try updating Calls and GroupCalls.
      await FirebaseFirestore.instance.collection('Calls').doc(callerId).update({
        'state': 'missed',
      }).catchError((_) {});
      
      await FirebaseFirestore.instance.collection('GroupCalls').doc(callerId).update({
        'state': 'missed',
      }).catchError((_) {});
    } catch (e) {
      debugPrint('Error handling call timeout: $e');
    }
  }

  /// Initialize push notifications and background message handlers
  static Future<void> initFirebaseMessagingUpdates() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      
      if (event is CallEventActionCallAccept) {
        debugPrint('CallKit: ACTION_CALL_ACCEPT');
        final extra = event.callKitParams.extra;
        if (extra != null) {
          _handleCallAccept(Map<String, dynamic>.from(extra));
        }
      } else if (event is CallEventActionCallDecline) {
        debugPrint('CallKit: ACTION_CALL_DECLINE');
        final extra = event.callKitParams.extra;
        if (extra != null) {
          _handleCallDecline(Map<String, dynamic>.from(extra));
        }
      } else if (event is CallEventActionCallTimeout) {
        debugPrint('CallKit: ACTION_CALL_TIMEOUT');
        _handleCallDeclineById(event.id);
      }
    });

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('getInitialMessage() -> data: ${initialMessage.data}');
      NotificationHelper.onNotificationClick(
        openRoute: true,
        payload: initialMessage.data,
      );
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('onMessageOpenedApp() -> data: ${message.data}');
      NotificationHelper.onNotificationClick(
        openRoute: true,
        payload: message.data,
      );
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('onMessage() -> data: ${message.data}');
      if (message.data['type'] == 'call') {
        // App is in foreground, directly show the call screen!
        NotificationHelper.onNotificationClick(payload: message.data);
        
        try {
          await _appVisibilityChannel.invokeMethod('wakeScreen');
          await _appVisibilityChannel.invokeMethod('bringToForeground');
        } catch (e) {
          debugPrint('MethodChannel error: $e');
        }
      } else if (message.data['type'] == 'message' || message.data['type'] == 'group') {
        // Show a gentle in-app banner for new messages instead of forcefully opening the chat screen
        final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
        final body = message.data['message'] ?? message.notification?.body ?? 'You received a new message.';
        
        Get.snackbar(
          title,
          body,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 4),
          onTap: (_) {
             NotificationHelper.onNotificationClick(payload: message.data);
          },
        );
      } else if (message.data['type'] == 'room_invite') {
        final title = message.data['title'] ?? message.notification?.title ?? 'Room Invitation';
        final body = message.data['message'] ?? message.notification?.body ?? 'You are invited to join a voice room.';
        final Map<String, dynamic> callData = message.data['call'] != null
            ? Map<String, dynamic>.from(jsonDecode(message.data['call']))
            : {};
        final roomId = callData['roomId'] ?? '';
        
        Get.snackbar(
          title,
          body,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 10),
          mainButton: TextButton(
            onPressed: () {
              Get.back();
              if (roomId.isNotEmpty) {
                AudioRoomsV2Integration.joinRoomById(roomId);
              }
            },
            child: const Text('Join', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
          onTap: (_) {
            if (roomId.isNotEmpty) {
              AudioRoomsV2Integration.joinRoomById(roomId);
            }
          },
        );
      } else {
        // For other types, we might just want to show a toast or ignore, but do not force navigation
      }
    });

    _requestPushNotificationsForIOS();
  }

  static void _requestPushNotificationsForIOS() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final AuthorizationStatus status = settings.authorizationStatus;
      debugPrint('_requestPushNotificationsForIOS() -> status: $status');
    }
  }
}

