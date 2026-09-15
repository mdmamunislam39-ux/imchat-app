import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:chat_messenger/main.dart';
import 'package:chat_messenger/routes/app_routes.dart';

class CallController extends GetxController {
  // Parameter
  final Call call;

  // Constructor
  CallController({required this.call});

  // Vars
  Timer? _timer;
  RxInt seconds = RxInt(0);
  Rxn<int> remoteUid = Rxn();
  RxBool isLocalUserJoined = RxBool(false);
  RxBool speaker = RxBool(true);
  RxBool mute = RxBool(false);
  RxBool switchCamera = RxBool(false);
  RxBool isCameraOn = true.obs;
  Timer? _autoEndCallTimer;
  RxBool isOnline = false.obs;
  // Agora SDK engine
  late RtcEngine engine;

  bool _isCallEnded = false;

  ////////// add new/////////////////
  // Add state field
  //  RxString callState = ''.obs;
  RxBool isMinimized = false.obs;
  final RxBool isLoading = RxBool(false);
  RxBool isRemoteVideoMuted = false.obs;

  // Firestore listener stream
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      callSubscription;

  void _listenToCallState() {
    // Listen to Firestore changes
    try {
      callSubscription = FirebaseFirestore.instance
          .collection('Calls')
          .doc(call.callerId) // or use receiverId based on your logic
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists) {
          // Call document deleted or cancelled
          onEndCall(endReason: seconds.value > 0 ? 'completed' : 'canceled');
          return;
        }
        // Get the 'state' field from Firestore document
        String state = snapshot.data()?['state'] ?? '';
        if (state == 'decline') {
          onEndCall(endReason: 'rejected');
        } else if (state == 'missed') {
          onEndCall(endReason: 'missed');
        } else if (state == 'cancel') {
          onEndCall(endReason: 'canceled');
        } else if (state == 'ended') {
          onEndCall(endReason: (seconds.value > 0 || remoteUid.value != null) ? 'completed' : 'ended');
        }
      });
    } catch (e) {
      AppStyle().failedSnackBar(message: e.toString());
    }
  }

  Future<void> fetchDocumentField() async {
    try {
      // Replace 'collectionName' and 'documentId' with your actual values
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(call.receiverId)
          .get();

      if (documentSnapshot.exists) {
        // Access specific field data
        isOnline.value = documentSnapshot.get('isOnline');
      } else {
        debugPrint('Document does not exist!');
      }
    } catch (e) {
      debugPrint('Error fetching document: $e');
    }
  }

  @override
  void onInit() {
    _initAgora();
    _listenToCallState();
    _startAutoEndCallTimer();
    fetchDocumentField();
    super.onInit();
  }

  RtcEngineEventHandler? _eventHandler;

  @override
  void onClose() {
    try {
      if (_eventHandler != null) {
        engine.unregisterEventHandler(_eventHandler!);
      }
    } catch (e) {
      debugPrint('Engine skip unregister');
    }
    // Restore the shared AgoraService event handler that was overridden
    try {
      Get.find<AgoraService>().setupEventHandlers();
    } catch (e) {
      debugPrint('Error restoring AgoraService event handlers: $e');
    }
    _timer = null;
    _stopRingtone();
    try {
      callSubscription.cancel();
    } catch (_) {}
    _cancelAutoEndCallTimer();
    // Stop background service
    try {
      BackgroundService().stopService();
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }
    super.onClose();
  }

  Future<void> _initAgora() async {
    try {
      // retrieve permissions safely (check isGranted first so background doesn't fail)
      bool permissionsGranted = false;
      bool micGranted = await Permission.microphone.isGranted;
      bool camGranted = call.isVideo ? await Permission.camera.isGranted : true;

      if (!micGranted || !camGranted) {
        if (call.isVideo) {
          Map<Permission, PermissionStatus> statuses =
              await [Permission.microphone, Permission.camera].request();
          micGranted = statuses[Permission.microphone]?.isGranted ?? false;
          camGranted = statuses[Permission.camera]?.isGranted ?? false;
        } else {
          final status = await Permission.microphone.request();
          micGranted = status.isGranted;
        }
      }
      permissionsGranted = micGranted && (call.isVideo ? camGranted : true);

      if (permissionsGranted) {
        // Permissions granted, proceed with video call
        // Play the ringtone sound ASAP.
        _playRingtone();

        final agoraService = AgoraService();
        agoraService.setChannelMode(
            call.isVideo ? AgoraChannelMode.videoCall : AgoraChannelMode.audioCall);
        if (agoraService.isConnected || agoraService.isConnecting) {
          try {
            await agoraService.engine?.leaveChannel();
          } catch (_) {}
        }
        await agoraService.initialize();

        engine = agoraService.engine!;

        _eventHandler = RtcEngineEventHandler(
          onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) {
            debugPrint(
                "Remote video state changed: uid: $uid, state: $state, reason: $reason");
            if (state == RemoteVideoState.remoteVideoStateStopped) {
              isRemoteVideoMuted.value = true;
            } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
              isRemoteVideoMuted.value = false;
            }
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
            debugPrint("local user ${connection.localUid} joined");
            isLocalUserJoined.value = true;

            // Ensure audio is properly routed and unmuted
            await engine.enableAudio();
            await engine.enableLocalAudio(true);
            await engine.muteLocalAudioStream(false);
            await engine.muteAllRemoteAudioStreams(false);
            await engine.setEnableSpeakerphone(speaker.value);

            // Start background service to ensure call continuity when minimized
            try {
              BackgroundService().startService();
            } catch (e) {
              debugPrint('Error starting background service: $e');
            }
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            debugPrint("remote user $uid joined");
            remoteUid.value = uid;
            _startTimer();
            _stopRingtone();
            _cancelAutoEndCallTimer();
          },
          onUserOffline: (RtcConnection connection, int uid,
              UserOfflineReasonType reason) {
            debugPrint("remote user $uid left channel");
            remoteUid.value = null;
            _timer?.cancel();
            onEndCall(endReason: (seconds.value > 0) ? 'completed' : 'ended');
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
                debugPrint('[onTokenPrivilegeWillExpire] Call token renewed successfully');
              }
            } catch (e) {
              debugPrint('[onTokenPrivilegeWillExpire] Failed to renew call token: $e');
            }
          },
          onRequestToken: (RtcConnection connection) async {
            debugPrint('[onRequestToken] Call token requested, renewing...');
            try {
              final renewed = await AgoraTokenService.instance.refreshToken(
                channelName: call.callerId,
                uid: 0,
                currentToken: '',
              );
              if (renewed != null && renewed.token.isNotEmpty) {
                await engine.renewToken(renewed.token);
                debugPrint('[onRequestToken] Call token renewed successfully');
              }
            } catch (e) {
              debugPrint('[onRequestToken] Failed to renew call token: $e');
            }
          },
        );

        engine.registerEventHandler(_eventHandler!);

        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        // Check the call type
        if (call.isVideo) {
          await engine.enableVideo();

          // Optimize for poor network conditions
          await engine.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 480, height: 360),
              frameRate: 15,
              bitrate: 400,
              degradationPreference: DegradationPreference.maintainFramerate,
            ),
          );

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

        // End the call automatically if permissions are denied so the app doesn't hang
        Future.delayed(const Duration(seconds: 4), () {
          if (!_isCallEnded && !isLocalUserJoined.value) {
            onEndCall();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [CallController] _initAgora failed: $e');
      AppStyle().failedSnackBar(message: 'Call initialization failed: $e');
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isCallEnded && !isLocalUserJoined.value) {
          onEndCall();
        }
      });
    }
  }

  // Auto end call if user doesn't join within 45 seconds
  void _startAutoEndCallTimer() {
    _autoEndCallTimer = Timer(const Duration(seconds: 45), () {
      if (remoteUid.value == null) {
        try {
          FirebaseFirestore.instance
              .collection('Calls')
              .doc(call.callerId)
              .update({
            'callerId': call.callerId,
            'callerName': call.callerName,
            'callerPhotoUrl': call.callerPhotoUrl,
            // Set receiver info
            'receiverName': call.receiverName,
            'receiverPhotoUrl': call.receiverPhotoUrl,
            'receiverId': call.receiverId,
            'state': 'missed'
          }).catchError((_) {});
        } catch (_) {}
        onEndCall(endReason: 'missed');
        Future.delayed(const Duration(seconds: 3), () {
          FirebaseFirestore.instance
              .collection('Calls')
              .doc(call.callerId)
              .delete()
              .catchError((_) {});
        });
        debugPrint("User did not join within 45 seconds. Ending call.");
      }
    });
  }

  void _cancelAutoEndCallTimer() {
    _autoEndCallTimer?.cancel();
  }

  // Toggle phone speaker
  void onToggleSpeaker() {
    final bool newValue = speaker.value = !speaker.value;
    engine.setEnableSpeakerphone(newValue);
    // engine.stopCameraCapture(VideoSourceType.videoSourceCamera);
  }

  //camera on and off
  void toggleCamera() {
    // final bool newValue = isCameraOn.value = !isCameraOn.value;
    // setState(() {
    isCameraOn.value = !isCameraOn.value; // Toggle camera state
    // });

    if (isCameraOn.value) {
      engine.enableLocalVideo(true); // Turn the camera on
    } else {
      engine.enableLocalVideo(false); // Turn the camera off
    }
  }

  // Toggle mute
  void onToggleMute() async {
    final bool newValue = mute.value = !mute.value;
    await engine.muteLocalAudioStream(newValue);
    await engine.updateChannelMediaOptions(
      ChannelMediaOptions(publishMicrophoneTrack: !newValue),
    );
  }

  // Switch Camera -> front/rear
  void onSwitchCamera() {
    switchCamera.value = !switchCamera.value;
    engine.switchCamera();
  }

  // Count the call duration
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++);
  }

  String _endReason = '';

  void _closeCallScreen() {
    final Map<String, dynamic> resultMap = {
      'status': _endReason.isNotEmpty
          ? _endReason
          : (seconds.value > 0 || remoteUid.value != null
              ? 'completed'
              : (call.isCaller ? 'canceled' : 'rejected')),
      'duration': seconds.value,
      'isVideo': call.isVideo,
      'remoteUid': remoteUid.value,
    };

    try {
      final nav = navigatorKey.currentState ?? Get.key.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop(resultMap);
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    } catch (e) {
      debugPrint('Error closing call screen: $e');
      try {
        Get.offAllNamed(AppRoutes.home);
      } catch (_) {}
    }
  }

  // End the call and pass the value
  void onEndCall({String? endReason}) {
    try {
      GetStorage().remove('callIsActive');
    } catch (e) {
      debugPrint('Safe GetStorage ignored: $e');
    }

    if (endReason != null && endReason.isNotEmpty) {
      _endReason = endReason;
    } else if (_endReason.isEmpty) {
      if (seconds.value > 0 || remoteUid.value != null) {
        _endReason = 'completed';
      } else if (call.isCaller) {
        _endReason = 'canceled';
      } else {
        _endReason = 'rejected';
      }
    }

    if (_isCallEnded) {
      _closeCallScreen();
      return;
    }
    _isCallEnded = true;

    // 1. Send Firestore state update IMMEDIATELY in real-time
    try {
      final String finalState = (call.isCaller && remoteUid.value == null)
          ? (_endReason == 'rejected'
              ? 'decline'
              : (_endReason == 'missed' ? 'missed' : 'cancel'))
          : 'ended';
      final docRef =
          FirebaseFirestore.instance.collection('Calls').doc(call.callerId);
      docRef.update({'state': finalState}).catchError((_) {});

      // Safe delayed delete to ensure both devices receive the snapshot event
      Future.delayed(const Duration(seconds: 3), () {
        docRef.delete().catchError((_) {});
      });
    } catch (e) {
      debugPrint('Error updating call state in Firestore: $e');
    }

    // 2. Stop timers & ringtone immediately
    _stopRingtone();
    _cancelAutoEndCallTimer();
    _timer?.cancel();

    // 3. Immediately close the call screen UI safely
    _closeCallScreen();

    // 4. Run heavy cleanup asynchronously in the background
    Future(() async {
      // Clear wake screen flags so the app doesn't stay over the lock screen
      const MethodChannel('com.imchatapp/app_visibility')
          .invokeMethod('clearWakeScreen')
          .catchError((_) {});

      // Explicitly leave channel and restore global AgoraService event handlers
      try {
        if (_eventHandler != null) {
          engine.unregisterEventHandler(_eventHandler!);
        }
        await engine.leaveChannel().catchError((_) {});
        AgoraService().setupEventHandlers();
      } catch (e) {
        debugPrint('Engine leaveChannel error: $e');
      }

      FlutterCallkitIncoming.endAllCalls().catchError((_) {});

      // Stop background service
      try {
        BackgroundService().stopService();
      } catch (e) {
        debugPrint('Error stopping background service: $e');
      }
    });
  }

  // Play Ringtone for outgoing call
  Future<void> _playRingtone() async {
    if (call.isCaller) {
      await FlutterRingtonePlayer().play(
          fromAsset: 'assets/sounds/phone-calling.mp3',
          looping: true, // Android only - API >= 28
          volume: 0.5, // Android only - API >= 28
          asAlarm: false);
      debugPrint('Ringtone played!');
    }
  }

  Future<void> _stopRingtone() async {
    if (call.isCaller) {
      await FlutterRingtonePlayer().stop();
      debugPrint('Ringtone stopped!');
    }
  }
}
