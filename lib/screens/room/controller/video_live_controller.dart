import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoLiveController extends GetxController {
  final String roomId;
  final bool isBroadcaster;
  
  VideoLiveController({required this.roomId, required this.isBroadcaster});

  late RtcEngine engine;
  RxBool isJoined = false.obs;
  RxList<int> remoteUids = <int>[].obs;
  RxInt localUid = 0.obs;

  RxBool isCameraOff = false.obs;
  RxBool isMicOff = false.obs;
  RxBool remoteCameraOff = false.obs;
  
  RxString broadcasterPhotoUrl = ''.obs;
  RxString broadcasterFrameUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint('Error enabling wakelock in VideoLiveController: $e');
    }
    _fetchBroadcasterInfo();
    _initAgora();
  }

  Future<void> _fetchBroadcasterInfo() async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('audio_rooms_v2').doc(roomId).get();
      if (roomDoc.exists) {
        final creatorId = roomDoc.data()?['creatorId'];
        if (creatorId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
          if (userDoc.exists) {
            broadcasterPhotoUrl.value = userDoc.data()?['photoUrl'] ?? '';
            broadcasterFrameUrl.value = userDoc.data()?['profileFrameUrl'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching broadcaster info: $e');
    }
  }

  @override
  void onClose() {
    AgoraService().dispose();
    if (isBroadcaster) {
      FirebaseFirestore.instance.collection('voice_room_messages').doc(roomId).delete();
    }
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint('Error disabling wakelock in VideoLiveController: $e');
    }
    super.onClose();
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    final agoraService = AgoraService();
    await agoraService.initialize();
    engine = agoraService.engine!;

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Video Live: Local user joined");
          isJoined.value = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Video Live: Remote user $remoteUid joined");
          remoteUids.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Video Live: Remote user $remoteUid left");
          remoteUids.remove(remoteUid);
        },
        onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
          debugPrint("Video Live: Remote user $remoteUid video muted: $muted");
          if (remoteUids.isNotEmpty && remoteUid == remoteUids.first) {
            remoteCameraOff.value = muted;
          }
        },
      ),
    );

    await engine.enableVideo();
    await engine.startPreview();

    // Set client role
    await engine.setClientRole(
      role: isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
    );

    // Generate Token and Join Channel
    try {
      final tokenInfo = await AgoraTokenService.instance.generateToken(
        channelName: roomId, 
        role: isBroadcaster ? 'publisher' : 'subscriber', 
        uid: 0
      );
      
      await engine.joinChannel(
        token: tokenInfo?.token ?? '',
        channelId: roomId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          publishCameraTrack: isBroadcaster,
          publishMicrophoneTrack: isBroadcaster,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint("Video Live: Error joining channel: $e");
    }
  }

  void leaveRoom() {
    Get.back();
  }

  void toggleCamera() {
    isCameraOff.value = !isCameraOff.value;
    engine.muteLocalVideoStream(isCameraOff.value);
  }

  void toggleMic() {
    isMicOff.value = !isMicOff.value;
    engine.muteLocalAudioStream(isMicOff.value);
  }
}
