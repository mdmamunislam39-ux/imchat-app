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
        if (snapshot.exists) {
          // Get the 'state' field from Firestore document
          String state = snapshot.data()?['state'] ?? '';
          if (state == 'decline' || state == 'missed' || state == 'ended') {
            onEndCall();
          }
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
    callSubscription.cancel();
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
        // Permissions granted, proceed with video call
        // Play the ringtone sound ASAP.
        _playRingtone();

        final agoraService = Get.isRegistered<AgoraService>()
            ? Get.find<AgoraService>()
            : Get.put(AgoraService());
        await agoraService.initialize();

        // Force leave any existing channel (like Voice Room) to avoid ERR_ALREADY_IN_USE on the shared engine
        await agoraService.leaveChannel();

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
            seconds.value = 0;
            _timer?.cancel();
            // Close the call page
            Future(() => Get.back());
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

          // Optimize for poor network conditions
          await engine.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 480, height: 360),
              frameRate: 15,
              bitrate: 400,
              degradationPreference: DegradationPreference.maintainFramerate,
            ),
          );

          // Auto-fallback to audio if network becomes too weak
          await engine.setLocalPublishFallbackOption(
              StreamFallbackOptions.streamFallbackOptionAudioOnly);
          await engine.setRemoteSubscribeFallbackOption(
              StreamFallbackOptions.streamFallbackOptionAudioOnly);

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
        Future.delayed(const Duration(seconds: 2), () {
          onEndCall();
        });
      }
    } catch (e) {
      debugPrint('❌ [CallController] _initAgora failed: $e');
      AppStyle().failedSnackBar(message: 'Call initialization failed: $e');
      Future.delayed(const Duration(seconds: 2), () {
        onEndCall();
      });
    }
  }

  // Auto end call if user doesn't join within 45 seconds
  void _startAutoEndCallTimer() {
    _autoEndCallTimer = Timer(const Duration(seconds: 45), () {
      if (remoteUid.value == null) {
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
        });
        onEndCall();
        Future.delayed(Duration(seconds: 2), () {
          FirebaseFirestore.instance
              .collection('Calls')
              .doc(call.callerId)
              .delete();
        });
        debugPrint("User did not join within 30 seconds. Ending call.");
        // Automatically end the call if no user joins
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

  // End the call and pass the value
  void onEndCall() {
    if (_isCallEnded) return;
    _isCallEnded = true;

    // Close the call screen INSTANTLY for nanosecond response time
    Get.back(result: remoteUid.value);

    // Run all heavy cleanup asynchronously in the background
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
        debugPrint('Engine not initialized, skipping leaveChannel');
      }

      FlutterCallkitIncoming.endAllCalls();

      if (call.isCaller) {
        String finalState = remoteUid.value == null ? 'missed' : 'ended';
        final docRef =
            FirebaseFirestore.instance.collection('Calls').doc(call.callerId);

        docRef.update({'state': finalState}).catchError((_) {});

        Future.delayed(const Duration(milliseconds: 500), () {
          docRef.delete().catchError((_) {});
        });
      } else {
        FirebaseFirestore.instance
            .collection('Calls')
            .doc(call.callerId)
            .update({'state': 'ended'}).catchError((_) {});
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
