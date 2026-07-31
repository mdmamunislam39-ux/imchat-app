import 'package:flutter/foundation.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRoomController extends GetxController {
  final String initialData;
  VoiceRoomController(this.initialData);

  late RtcEngine _engine;
  final isJoined = false.obs;
  final users = [].obs;
  final User currentUser = AuthController.instance.currentUser;

  @override
  void onInit() {
    super.onInit();
    initializeAgora();
  }

  Future<void> initializeAgora() async {
    await [Permission.microphone].request();

    final agoraService = AgoraService();
    await agoraService.initialize();
    _engine = agoraService.engine!;

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (channel, elapsed) {
        isJoined.value = true;

        debugPrint("local user ${channel.localUid} joined");
        users.add({
          'name': currentUser.fullname,
          'image': currentUser.photoUrl,
          'uid': currentUser.userId
        });
      },
      onLeaveChannel: (connection, stats) {
        isJoined.value = false;
        users.clear();
        debugPrint("local user ${connection.localUid} leave");
        users.remove({
          'name': currentUser.fullname,
          'image': currentUser.photoUrl,
          'uid': currentUser.userId
        });
      },
      onUserJoined: (connection, uid, elapsed) {
        debugPrint('User $uid joined');
        users.add({
          'name': currentUser.fullname,
          'image': currentUser.photoUrl,
          'uid': uid
        });
        debugPrint(users.toString());
      },
      onUserOffline: (connection, uid, reason) {
        users.removeWhere((user) => user['uid'] == uid);
        debugPrint('User $uid left');
        debugPrint(users.toString());
      },
    ));

    // Dynamic Token Generation
    final tokenResponse = await AgoraTokenService.instance.generateToken(
      channelName: 'abcd1',
      uid: 0,
    );
    final tokenToUse = tokenResponse?.token ?? '';

    await _engine.joinChannel(
      token: tokenToUse,
      channelId: 'abcd1',
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  void leaveRoom() {
    _engine.leaveChannel();
  }

  @override
  void onClose() {
    _engine.release();
    super.onClose();
  }
}
