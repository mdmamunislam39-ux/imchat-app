import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/services/rtc_engine_manager.dart';
import 'package:chat_messenger/services/livekit_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';

class GroupCallController extends GetxController {
  final Call call;

  // Constructor
  GroupCallController({required this.call});

  bool get isLiveKit =>
      Get.isRegistered<RtcEngineManager>() &&
      Get.find<RtcEngineManager>().isLiveKitActive;

  LiveKitService get livekitService =>
      Get.isRegistered<LiveKitService>()
          ? Get.find<LiveKitService>()
          : Get.put(LiveKitService(), permanent: true);

  // Vars
  Timer? _timer;
  RxInt seconds = RxInt(0);
  Rxn<int> remoteUid = Rxn();
  RxBool isLocalUserJoined = RxBool(false);
  RxBool speaker = RxBool(true);
  RxBool mute = RxBool(false);

  // Agora SDK engine
  late RtcEngine engine;

  ////////// add new/////////////////
  // Add state field
  RxString callState = ''.obs;
  RxBool isMinimized = false.obs;
  final RxBool isLoading = RxBool(false);
  RxList remoteUsers = [].obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? callSubscription;

  @override
  void onInit() {
    if (isLiveKit) {
      _initLiveKitGroupCall();
    } else {
      _initAgora();
    }
    _listenToCallState();
    super.onInit();
  }

  Future<void> _initLiveKitGroupCall() async {
    try {
      if (call.isVideo) {
        await [Permission.microphone, Permission.camera].request();
      } else {
        await Permission.microphone.request();
      }

      playRingtone();

      final myUid = AuthController.instance.currentUser.userId;
      final myName = AuthController.instance.currentUser.fullname;
      final roomName = call.callerId;
      final url = Get.find<RtcEngineManager>().livekitServerUrl;

      final token = await livekitService.generateToken(
        roomName: roomName,
        identity: myUid,
        userName: myName,
      );

      livekitService.onParticipantJoined = (participant) {
        remoteUsers.add(participant.identity);
        remoteUid.value = 1;
        _startTimer();
        stopRingtone();
      };

      livekitService.onParticipantLeft = (participant) {
        remoteUsers.remove(participant.identity);
        if (remoteUsers.isEmpty) {
          onEndCall();
        }
      };

      final success = await livekitService.connectToRoom(
        url: url,
        token: token,
        enableAudio: true,
        enableVideo: call.isVideo,
        autoPublishMic: true,
      );

      if (success) {
        isLocalUserJoined.value = true;
        mute.value = false;
        debugPrint('🚀 [LiveKit Group Call] Connected successfully');
      } else {
        debugPrint('⚠️ [LiveKit Group Call] Failed to join LiveKit room');
        AppStyle().failedSnackBar(message: 'Failed to connect to LiveKit WebRTC server');
        onEndCall();
      }
    } catch (e) {
      debugPrint('❌ [LiveKit Group Call] Error: $e');
      AppStyle().failedSnackBar(message: 'LiveKit Group Call Error: $e');
      onEndCall();
    }
  }

  void _listenToCallState() {
    callSubscription = FirebaseFirestore.instance
        .collection('GroupCalls')
        .doc(call.callerId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        String state = snapshot.data()?['state'] ?? '';
        if (state == 'ended' || state == 'decline' || state == 'missed') {
          if (!call.isCaller) {
            onEndCall();
          }
        }
      }
    });
  }

  RtcEngineEventHandler? _eventHandler;

  @override
  void onClose() {
    _timer = null;
    callSubscription?.cancel();
    try {
      if (_eventHandler != null) {
        engine.unregisterEventHandler(_eventHandler!);
      }
    } catch (e) {
      debugPrint('Engine skip unregister');
    }
    try {
      BackgroundService().stopService();
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }
    // Clear wake screen flags so the app doesn't stay over the lock screen
    const MethodChannel('com.imchatapp/app_visibility')
        .invokeMethod('clearWakeScreen')
        .catchError((_) {});

    // Restore the shared AgoraService event handler that was overridden
    try {
      Get.find<AgoraService>().setupEventHandlers();
    } catch (e) {
      debugPrint('Error restoring AgoraService event handlers: $e');
    }
    super.onClose();
  }

  Future<void> _initAgora() async {
    // retrieve permissions
    bool permissionsGranted = false;
    if (call.isVideo) {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.microphone, Permission.camera].request();
      permissionsGranted = statuses[Permission.camera]!.isGranted &&
          statuses[Permission.microphone]!.isGranted;
    } else {
      final status = await Permission.microphone.request();
      permissionsGranted = status.isGranted;
    }

    if (permissionsGranted) {
      playRingtone();

      final agoraService = AgoraService();
      agoraService.setChannelMode(AgoraChannelMode.groupCall);
      if (agoraService.isConnected || agoraService.isConnecting) {
        try {
          await agoraService.engine?.leaveChannel();
        } catch (_) {}
      }
      await agoraService.initialize();

      engine = agoraService.engine!;

      _eventHandler = RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          debugPrint("local user ${connection.localUid} joined");
          isLocalUserJoined.value = true;

          // Ensure audio is properly routed and unmuted
          await engine.enableAudio();
          await engine.enableLocalAudio(true);
          await engine.muteLocalAudioStream(false);
          await engine.muteAllRemoteAudioStreams(false);
          await engine.setEnableSpeakerphone(speaker.value);

          try {
            BackgroundService().startService();
          } catch (e) {
            debugPrint('Error starting background service: $e');
          }
        },
        onLeaveChannel: (connection, stats) {
          debugPrint("local user ${connection.localUid} leave");
          // remoteUsers.remove(remoteUid.value);
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          debugPrint("remote user $uid joined");
          remoteUid.value = uid;
          if (!remoteUsers.contains(uid)) {
            remoteUsers.add(uid);
          }
          _startTimer();
          stopRingtone();
        },
        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          debugPrint("remote user $uid left channel");
          remoteUsers.remove(uid);
          seconds.value = 0;
          _timer?.cancel();
          // Close the call page
          //Future(() => Get.back());
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
          debugPrint(
              '[onTokenPrivilegeWillExpire] conn:${connection.toJson()}, token: $token');
          try {
            final renewed = await AgoraTokenService.instance.refreshToken(
              channelName: call.callerId,
              uid: 0,
              currentToken: token,
            );
            if (renewed != null && renewed.token.isNotEmpty) {
              await engine.renewToken(renewed.token);
              debugPrint('[onTokenPrivilegeWillExpire] Group call token renewed successfully');
            }
          } catch (e) {
            debugPrint('[onTokenPrivilegeWillExpire] Failed to renew group call token: $e');
          }
        },
        onRequestToken: (RtcConnection connection) async {
          debugPrint('[onRequestToken] Group call token requested, renewing...');
          try {
            final renewed = await AgoraTokenService.instance.refreshToken(
              channelName: call.callerId,
              uid: 0,
              currentToken: '',
            );
            if (renewed != null && renewed.token.isNotEmpty) {
              await engine.renewToken(renewed.token);
              debugPrint('[onRequestToken] Group call token renewed successfully');
            }
          } catch (e) {
            debugPrint('[onRequestToken] Failed to renew group call token: $e');
          }
        },
      );

      engine.registerEventHandler(_eventHandler!);

      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      // Check the call type
      if (call.isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.enableAudio();
      }

      // Generate dynamic token
      final tokenResponse = await AgoraTokenService.instance.generateToken(
        channelName: call.callerId,
        uid: 0,
      );
      final tokenToUse = tokenResponse?.token ?? '';

      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      mute.value = false;

      await engine.joinChannel(
        token: tokenToUse,
        channelId: call.callerId,
        uid: 0,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: call.isVideo,
          publishMicrophoneTrack: true,
          publishCameraTrack: call.isVideo,
        ),
      );
    } else {
      // Permissions not granted, handle accordingly
      AppStyle().failedSnackBar(
          message: 'Please allow camera and microphone permission');
    }
  }

  // Toggle phone speaker
  void onToggleSpeaker() {
    final bool newValue = speaker.value = !speaker.value;
    if (!isLiveKit) {
      try {
        engine.setEnableSpeakerphone(newValue);
      } catch (e) {
        debugPrint('Agora speaker error: $e');
      }
    }
  }

  // Toggle mute
  void onToggleMute() async {
    final bool newValue = mute.value = !mute.value;
    if (isLiveKit) {
      await livekitService.setMicrophoneEnabled(!newValue);
    } else {
      try {
        await engine.muteLocalAudioStream(newValue);
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(publishMicrophoneTrack: !newValue),
        );
      } catch (e) {
        debugPrint('Agora mute error: $e');
      }
    }
  }

  // End the call and pass the value
  void onEndCall() {
    try {
      GetStorage().remove('groupIsActive');
    } catch (_) {}
    FlutterCallkitIncoming.endAllCalls();
    try {
      if (isLiveKit) {
        livekitService.leaveRoom();
      } else {
        if (_eventHandler != null) {
          engine.unregisterEventHandler(_eventHandler!);
        }
        engine.leaveChannel();
        AgoraService().setupEventHandlers();
      }
    } catch (e) {
      debugPrint('Error leaving group call: $e');
    }
    if (call.isCaller) {
      FirebaseFirestore.instance
          .collection('GroupCalls')
          .doc(call.callerId)
          .update({'state': 'ended'}).catchError((_) {});
    }
    try {
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back(result: remoteUid.value);
      } else {
        Get.offAll(() => HomeScreen());
      }
    } catch (_) {
      Get.offAll(() => HomeScreen());
    }
  }

  // Play Ringtone for outgoing call
  Future<void> playRingtone() async {
    if (call.isCaller) {
      await FlutterRingtonePlayer().play(
          fromAsset: 'assets/sounds/phone-calling.mp3',
          looping: true, // Android only - API >= 28
          volume: 0.5, // Android only - API >= 28
          asAlarm: false);
      debugPrint('Ringtone played!');
    }
  }

  Future<void> stopRingtone() async {
    if (call.isCaller) {
      await FlutterRingtonePlayer().stop();
      debugPrint('Ringtone stopped!');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++);
  }
}
