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
import 'package:get_storage/get_storage.dart';

const MethodChannel _appVisibilityChannel = MethodChannel('com.imchatapp/app_visibility');

Future<void> _showIncomingCallNotification(RemoteMessage message) async {
  final callData = message.data['call'] != null 
      ? jsonDecode(message.data['call']) 
      : {};
  final String callId = callData['callerId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
  final String callerName = callData['callerName'] ?? 'Incoming Call';
  final String avatarUrl = callData['callerPhotoUrl'] ?? '';
  final String? pushAgoraToken = callData['agoraToken'];

  // If push notification contains pre-generated Agora token, cache it immediately (0ms delay)!
  if (pushAgoraToken != null && pushAgoraToken.isNotEmpty) {
    import_agora.AgoraTokenService.instance.cachePreGeneratedToken(
      channelName: callId,
      token: pushAgoraToken,
    );
  } else {
    // Pre-fetch Agora token in the background so it's instantly available in cache when answered!
    try {
      import_agora.AgoraTokenService.instance.generateToken(channelName: callId, uid: 0);
    } catch (_) {}
  }

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
  
  final isFollowerLive = message.data['type'] == 'follower_room';
  final title = message.data['title'] ?? (isFollowerLive ? 'User is on live!' : 'New Message');
  final body = message.data['body'] ?? (isFollowerLive ? "Let's have fun together!!🤘🤟" : '');
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

  final androidDetails = isFollowerLive
      ? AndroidNotificationDetails(
          'live_room_alerts',
          'Live Room Alerts',
          channelDescription: 'Notifications when followed hosts start a live voice room',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.status,
          largeIcon: avatarPath != null ? FilePathAndroidBitmap(avatarPath) : null,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'imChat Live',
          ),
        )
      : AndroidNotificationDetails(
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
  } else if (message.data['type'] == 'message' || message.data['type'] == 'group' || message.data['type'] == 'follower_room') {
    await _showCustomChatNotification(message);
  }
}

abstract class FirebaseMessagingService {
  static final Map<String, DateTime> _acceptedCallTimestamps = <String, DateTime>{};

  static void _markCallAccepted(String id) {
    if (id.isEmpty) return;
    _acceptedCallTimestamps[id] = DateTime.now();
    try {
      GetStorage().write('call_accepted_$id', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static bool _isCallRecentlyAccepted(String id) {
    if (id.isEmpty) return false;
    final inMemTime = _acceptedCallTimestamps[id];
    if (inMemTime != null) {
      if (DateTime.now().difference(inMemTime).inSeconds < 60) {
        return true;
      }
    }
    try {
      final storedMs = GetStorage().read<int>('call_accepted_$id');
      if (storedMs != null) {
        final diff = DateTime.now().millisecondsSinceEpoch - storedMs;
        if (diff < 60000) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Tracks the currently active 1-to-1 chat user ID when user is on MessageScreen
  static String? activeChatUserId;

  /// Tracks the currently active group ID when user is on MessageScreen
  static String? activeGroupId;

  static Map<String, dynamic>? _extractCallData(dynamic rawCall) {
    if (rawCall == null) return null;
    if (rawCall is Map) return Map<String, dynamic>.from(rawCall);
    if (rawCall is String && rawCall.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCall);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('Error decoding rawCall: $e');
      }
    }
    return null;
  }

  static Future<void> _handleCallAccept(Map<String, dynamic> payload) async {
    try {
      // Bring app to foreground and wake screen if in background
      _appVisibilityChannel.invokeMethod('wakeScreen').catchError((_) {});
      _appVisibilityChannel.invokeMethod('bringToForeground').catchError((_) {});

      final callData = _extractCallData(payload['call']);
      if (callData == null) return;
      final callerId = callData['callerId']?.toString();
      if (callerId == null || callerId.isEmpty) return;

      _markCallAccepted(callerId);
      
      final String? pushAgoraToken = callData['agoraToken'];
      if (pushAgoraToken != null && pushAgoraToken.isNotEmpty) {
        import_agora.AgoraTokenService.instance.cachePreGeneratedToken(
          channelName: callerId,
          token: pushAgoraToken,
        );
      }

      final isGroup = callData['receiverId'] == 'group_call';
      final Call callObj = Call.fromMap(data: callData);
      
      void navigateToAcceptedCall() {
        if (isGroup) {
          final currentUser = AuthController.instance.currentUser;
          Get.off(() => GroupCallScreen(isVideo: callObj.isVideo, call: callObj));
          
          FirebaseFirestore.instance.collection('GroupCalls').doc(callerId).get().then((docSnapshot) {
            if (docSnapshot.exists) {
              docSnapshot.reference.update({
                'state': 'running',
                'receiverName': FieldValue.arrayUnion([currentUser.fullname]),
              });
            }
          }).catchError((_) {});
        } else {
          if (callObj.isVideo) {
            Get.offNamed(AppRoutes.videoCall, arguments: {'call': callObj});
          } else {
            Get.offNamed(AppRoutes.voiceCall, arguments: {'call': callObj});
          }
          
          FirebaseFirestore.instance.collection('Calls').doc(callerId).update({
            'state': 'running',
          }).catchError((_) {});
        }
      }

      if (Get.key.currentState != null) {
        navigateToAcceptedCall();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => navigateToAcceptedCall());
      }
    } catch (e) {
      debugPrint('Error accepting call from CallKit: $e');
    }
  }

  static Future<void> _handleCallDecline(Map<String, dynamic> payload) async {
    try {
      final callData = _extractCallData(payload['call']);
      if (callData == null) return;
      final callerId = callData['callerId']?.toString();
      if (callerId == null || callerId.isEmpty) return;

      if (_isCallRecentlyAccepted(callerId)) {
        debugPrint('Skipping decline: Call $callerId was recently accepted.');
        return;
      }

      final isGroup = payload['type'] == 'group_call' || callData['receiverId'] == 'group_call';
      if (!isGroup) {
        final docRef = FirebaseFirestore.instance.collection('Calls').doc(callerId);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final currentState = docSnap.data()?['state'];
          if (currentState == 'running' || currentState == 'ended') {
            debugPrint('Skipping decline: Firestore Call $callerId state is already $currentState');
            return;
          }
        }
        await docRef.update({
          'state': 'decline',
        }).catchError((_) {});
        Future.delayed(const Duration(seconds: 3), () {
          docRef.delete().catchError((_) {});
        });
      }
    } catch (e) {
      debugPrint('Error declining call from CallKit: $e');
    }
  }

  static Future<void> _handleCallDeclineById(String callerId) async {
    try {
      if (callerId.isEmpty) return;
      if (_isCallRecentlyAccepted(callerId)) {
        debugPrint('Skipping timeout decline: Call $callerId was recently accepted.');
        return;
      }

      final callDocRef = FirebaseFirestore.instance.collection('Calls').doc(callerId);
      final groupDocRef = FirebaseFirestore.instance.collection('GroupCalls').doc(callerId);
      
      final callSnap = await callDocRef.get();
      if (callSnap.exists) {
        final currentState = callSnap.data()?['state'];
        if (currentState == 'running' || currentState == 'ended') {
          debugPrint('Skipping timeout decline: Call $callerId is already $currentState');
          return;
        }
      }

      await callDocRef.update({
        'state': 'missed',
      }).catchError((_) {});
      await groupDocRef.update({
        'state': 'missed',
      }).catchError((_) {});
      Future.delayed(const Duration(seconds: 3), () {
        callDocRef.delete().catchError((_) {});
        groupDocRef.delete().catchError((_) {});
      });
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
          final id = event.callKitParams.id;
          if (id.isNotEmpty) _markCallAccepted(id);
          _handleCallAccept(Map<String, dynamic>.from(extra));
        }
      } else if (event is CallEventActionCallDecline) {
        debugPrint('CallKit: ACTION_CALL_DECLINE');
        final id = event.callKitParams.id;
        if (id.isNotEmpty && _isCallRecentlyAccepted(id)) {
          debugPrint('CallKit: Ignoring ACTION_CALL_DECLINE because call $id was recently accepted.');
          return;
        }
        final extra = event.callKitParams.extra;
        if (extra != null) {
          _handleCallDecline(Map<String, dynamic>.from(extra));
        } else if (id.isNotEmpty) {
          _handleCallDeclineById(id);
        }
      } else if (event is CallEventActionCallTimeout) {
        debugPrint('CallKit: ACTION_CALL_TIMEOUT');
        final id = event.id;
        if (id.isNotEmpty && _isCallRecentlyAccepted(id)) {
          debugPrint('CallKit: Ignoring ACTION_CALL_TIMEOUT because call $id was recently accepted.');
          return;
        }
        _handleCallDeclineById(event.id);
      }
    });

    // Check for active accepted calls on cold start
    try {
      final dynamic activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is List && activeCalls.isNotEmpty) {
        for (final item in activeCalls) {
          if (item is Map && (item['isAccepted'] == true || item['accepted'] == true)) {
            final extra = item['extra'];
            if (extra != null) {
              final id = item['id']?.toString() ?? '';
              if (id.isNotEmpty) _markCallAccepted(id);
              _handleCallAccept(Map<String, dynamic>.from(extra));
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking active CallKit calls: $e');
    }

    // Initialize Local Notifications for Android with click listener
    final flnp = FlutterLocalNotificationsPlugin();
    await flnp.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final dynamic payloadData = jsonDecode(response.payload!);
            if (payloadData is Map) {
              NotificationHelper.onNotificationClick(
                openRoute: true,
                payload: Map<String, dynamic>.from(payloadData),
              );
            }
          } catch (e) {
            debugPrint('Error parsing local notification payload on click: $e');
          }
        }
      },
    );

    // Check cold start from local notification
    try {
      final launchDetails = await flnp.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          final dynamic payloadData = jsonDecode(payload);
          if (payloadData is Map) {
            NotificationHelper.onNotificationClick(
              openRoute: true,
              payload: Map<String, dynamic>.from(payloadData),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking local notification launch details: $e');
    }

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
        final rawCall = message.data['call'];
        final Map<String, dynamic> callMap = rawCall is Map
            ? Map<String, dynamic>.from(rawCall)
            : (rawCall is String && rawCall.isNotEmpty
                ? (jsonDecode(rawCall) is Map ? Map<String, dynamic>.from(jsonDecode(rawCall)) : {})
                : {});

        final String? senderId = message.data['senderId'] ?? callMap['senderId'];
        final String? msgGroupId = message.data['groupId'] ?? callMap['groupId'];

        // If the user is currently on the active chat screen with this sender or group, do not show in-app banner/snackbar!
        final bool isCurrentChat = (message.data['type'] == 'message' &&
                activeChatUserId != null &&
                senderId != null &&
                activeChatUserId == senderId) ||
            (message.data['type'] == 'group' &&
                activeGroupId != null &&
                msgGroupId != null &&
                activeGroupId == msgGroupId);

        if (isCurrentChat) {
          debugPrint('Notification suppressed: User is actively chatting with $senderId / $msgGroupId');
          return;
        }

        // Show a gentle in-app banner for new messages instead of forcefully opening the chat screen
        final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
        final body = message.data['message'] ?? message.notification?.body ?? 'You received a new message.';
        
        _showSafeSnackbar(
          title: title,
          message: body,
          duration: const Duration(seconds: 4),
          onTap: (_) {
            NotificationHelper.onNotificationClick(payload: message.data);
          },
        );
      } else if (message.data['type'] == 'room_invite') {
        final title = message.data['title'] ?? message.notification?.title ?? 'Room Invitation';
        final body = message.data['message'] ?? message.notification?.body ?? 'You are invited to join a voice room.';
        final Map<String, dynamic> callData = message.data['call'] != null
            ? (message.data['call'] is String ? Map<String, dynamic>.from(jsonDecode(message.data['call'])) : Map<String, dynamic>.from(message.data['call']))
            : {};
        final roomId = callData['roomId'] ?? '';
        
        _showSafeSnackbar(
          title: title,
          message: body,
          duration: const Duration(seconds: 10),
          mainButton: TextButton(
            onPressed: () {
              if (Get.isSnackbarOpen == true) Get.back();
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
      } else if (message.data['type'] == 'follower_room') {
        final title = message.data['title'] ?? message.notification?.title ?? 'Live Room Alert';
        final body = message.data['body'] ?? message.data['message'] ?? message.notification?.body ?? "Let's have fun together!!🤘🤟";
        final dynamic rawCall = message.data['call'];
        final Map<String, dynamic> callData = rawCall is Map
            ? Map<String, dynamic>.from(rawCall)
            : (rawCall is String && rawCall.isNotEmpty
                ? (jsonDecode(rawCall) is Map ? Map<String, dynamic>.from(jsonDecode(rawCall)) : {})
                : {});
        final roomId = callData['roomId'] ?? message.data['roomId'] ?? '';

        _showSafeSnackbar(
          title: title,
          message: body,
          duration: const Duration(seconds: 8),
          mainButton: TextButton(
            onPressed: () {
              if (Get.isSnackbarOpen == true) Get.back();
              if (roomId.isNotEmpty) {
                AudioRoomsV2Integration.joinRoomById(roomId);
              }
            },
            child: const Text('Join Live', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
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

  static void _showSafeSnackbar({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    TextButton? mainButton,
    void Function(GetSnackBar)? onTap,
  }) {
    try {
      final context = Get.overlayContext ?? Get.context;
      if (context == null) return;
      if (Overlay.maybeOf(context) == null) return;

      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(10),
        duration: duration,
        mainButton: mainButton,
        onTap: onTap,
      );
    } catch (e) {
      debugPrint('[FirebaseMessagingService] Safe snackbar notice: $e');
    }
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

