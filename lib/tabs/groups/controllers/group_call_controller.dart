import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:chat_messenger/services/agora_service.dart';

class GroupCallController extends GetxController {
  final Call call;

  // Constructor
  GroupCallController({required this.call});

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
    _initAgora();
    _listenToCallState();
    super.onInit();
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

      final agoraService = Get.isRegistered<AgoraService>()
          ? Get.find<AgoraService>()
          : Get.put(AgoraService());
      if (agoraService.engine == null) {
        await agoraService.initialize();
      }

      // Force leave any existing channel (like Voice Room) to avoid ERR_ALREADY_IN_USE on the shared engine
      await agoraService.leaveChannel();

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
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] conn:${connection.toJson()}, token: $token');
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
    engine.setEnableSpeakerphone(newValue);
  }

  // Toggle mute
  void onToggleMute() async {
    final bool newValue = mute.value = !mute.value;
    await engine.muteLocalAudioStream(newValue);
    await engine.updateChannelMediaOptions(
      ChannelMediaOptions(publishMicrophoneTrack: !newValue),
    );
  }

  // End the call and pass the value
  void onEndCall() {
    FlutterCallkitIncoming.endAllCalls();
    try {
      if (_eventHandler != null) {
        engine.unregisterEventHandler(_eventHandler!);
      }
      engine.leaveChannel();
      AgoraService().setupEventHandlers();
    } catch (e) {
      debugPrint('Error leaving group call: $e');
    }
    if (call.isCaller) {
      FirebaseFirestore.instance
          .collection('GroupCalls')
          .doc(call.callerId)
          .update({'state': 'ended'}).catchError((_) {});
    }
    Get.back(result: remoteUid.value);
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
