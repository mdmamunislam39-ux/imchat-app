import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'global_settings_service.dart';
import 'vps_api_service.dart';
import 'background_service.dart';

/// Service for managing WebRTC sessions via LiveKit (Self-hosted VPS or LiveKit Cloud)
class LiveKitService extends GetxService {
  final GlobalSettingsService _settings = Get.find<GlobalSettingsService>();
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  // Reactive state
  final RxBool isConnected = false.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isMicMuted = true.obs;
  final RxBool isCameraEnabled = false.obs;
  final RxString currentRoomName = ''.obs;
  final RxList<String> activeSpeakers = <String>[].obs;
  final RxList<Participant> remoteParticipants = <Participant>[].obs;

  // Reactive track holders for Video Call UI rendering
  final Rxn<VideoTrack> localVideoTrack = Rxn<VideoTrack>();
  final Rxn<VideoTrack> remoteVideoTrack = Rxn<VideoTrack>();

  // Callbacks
  Function(List<String> speakers)? onActiveSpeakersChanged;
  Function(Participant participant)? onParticipantJoined;
  Function(Participant participant)? onParticipantLeft;
  Function(TrackPublication publication, Participant participant)? onTrackSubscribed;
  Function(TrackPublication publication, Participant participant)? onTrackUnsubscribed;
  Function(dynamic error)? onConnectionError;

  Room? get room => _room;
  LocalParticipant? get localParticipant => _room?.localParticipant;

  /// Generate or fetch a LiveKit Room Access Token
  Future<String> generateToken({
    required String roomName,
    required String identity,
    String userName = 'User',
  }) async {
    // 1. Try requesting token from VPS backend
    try {
      if (Get.isRegistered<VpsApiService>()) {
        final vpsApi = Get.find<VpsApiService>();
        if (vpsApi.baseUrl.isNotEmpty) {
          final res = await vpsApi.post('/api/rtc/livekit-token', body: {
            'roomName': roomName,
            'identity': identity,
            'userName': userName,
          }, requireAuth: false);
          if (res is Map && res['token'] != null) {
            return res['token'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[LiveKitService] VPS token fetch notice: $e');
    }

    // 2. Client-side JWT Generator fallback using Admin configured keys
    final apiKey = _settings.livekitApiKey.value.trim().isNotEmpty
        ? _settings.livekitApiKey.value.trim()
        : 'imchat_prod';
    final apiSecret = _settings.livekitApiSecret.value.trim().isNotEmpty
        ? _settings.livekitApiSecret.value.trim()
        : 'Lk9pR4vT7xQ2mN8cY6sJ3wH5zA1dF0gB';

    return _createClientJwt(
      apiKey: apiKey,
      apiSecret: apiSecret,
      identity: identity,
      userName: userName,
      roomName: roomName,
    );
  }

  String _createClientJwt({
    required String apiKey,
    required String apiSecret,
    required String identity,
    required String userName,
    required String roomName,
  }) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'exp': nowSec + 86400,
      'iss': apiKey,
      'nbf': nowSec - 5,
      'sub': identity,
      'name': userName,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': true,
        'canSubscribe': true,
      },
    };

    String base64UrlEncodeNoPadding(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    final headerBase64 = base64UrlEncodeNoPadding(utf8.encode(jsonEncode(header)));
    final payloadBase64 = base64UrlEncodeNoPadding(utf8.encode(jsonEncode(payload)));
    final signatureInput = '$headerBase64.$payloadBase64';

    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final digest = hmac.convert(utf8.encode(signatureInput));
    final signatureBase64 = base64UrlEncodeNoPadding(digest.bytes);

    return '$signatureInput.$signatureBase64';
  }

  /// Connect to LiveKit Room using Server WebSocket URL and Access Token
  Future<bool> connectToRoom({
    required String url,
    required String token,
    bool enableAudio = true,
    bool enableVideo = false,
    bool autoPublishMic = false,
  }) async {
    try {
      if (isConnected.value) {
        await leaveRoom();
      }

      isConnecting.value = true;
      String connectUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
      if (!connectUrl.startsWith('ws://') &&
          !connectUrl.startsWith('wss://') &&
          !connectUrl.startsWith('http://') &&
          !connectUrl.startsWith('https://')) {
        connectUrl = 'wss://$connectUrl';
      }
      debugPrint('[LiveKitService] Connecting to $connectUrl...');

      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: const AudioPublishOptions(
          name: 'microphone',
        ),
        defaultVideoPublishOptions: const VideoPublishOptions(
          name: 'camera',
          simulcast: true,
        ),
      );

      _room = Room(roomOptions: roomOptions);
      _listener = _room!.createListener();

      _setupListeners();

      await _room!.connect(
        connectUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
        ),
      );

      isConnected.value = true;
      isConnecting.value = false;
      currentRoomName.value = _room?.name ?? '';

      // Update initial remote participants
      _updateParticipantsList();

      // Fire joined callback and resolve subscribed tracks for already connected participants
      if (_room!.remoteParticipants.isNotEmpty) {
        for (final p in _room!.remoteParticipants.values) {
          try {
            onParticipantJoined?.call(p);
            for (final pub in p.videoTrackPublications) {
              if (pub.subscribed && pub.track is VideoTrack) {
                remoteVideoTrack.value = pub.track as VideoTrack;
              }
            }
          } catch (_) {}
        }
      }

      // Configure initial audio/video state
      if (enableAudio && autoPublishMic) {
        await setMicrophoneEnabled(true);
      } else {
        await setMicrophoneEnabled(false);
      }

      if (enableVideo) {
        await setCameraEnabled(true);
        final localPub = _room?.localParticipant?.videoTrackPublications.firstOrNull;
        if (localPub?.track is VideoTrack) {
          localVideoTrack.value = localPub!.track as VideoTrack;
        }
      }

      debugPrint('[LiveKitService] Connected successfully to room: ${_room?.name}');

      // Start Background Foreground Service for audio continuity & notification bar
      try {
        await BackgroundService().startCallService(
          title: 'VoiceRoom is running now',
          content: 'click back to the VoiceRoom',
        );
      } catch (bgErr) {
        debugPrint('[LiveKitService] BackgroundService start error: $bgErr');
      }

      return true;
    } catch (e) {
      debugPrint('[LiveKitService] Error connecting to room: $e');
      isConnecting.value = false;
      isConnected.value = false;
      onConnectionError?.call(e);
      return false;
    }
  }

  void _setupListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('[LiveKitService] Disconnected from room: ${event.reason}');
        isConnected.value = false;
        currentRoomName.value = '';
        activeSpeakers.clear();
        remoteParticipants.clear();
        localVideoTrack.value = null;
        remoteVideoTrack.value = null;
        try {
          BackgroundService().stopService();
        } catch (_) {}
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint('[LiveKitService] Participant joined: ${event.participant.identity}');
        _updateParticipantsList();
        onParticipantJoined?.call(event.participant);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('[LiveKitService] Participant left: ${event.participant.identity}');
        _updateParticipantsList();
        remoteVideoTrack.value = null;
        onParticipantLeft?.call(event.participant);
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final speakers = event.speakers.map((p) => p.identity).toList();
        activeSpeakers.assignAll(speakers);
        onActiveSpeakersChanged?.call(speakers);
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint('[LiveKitService] Track subscribed: ${event.track.kind}');
        if (event.track is VideoTrack) {
          remoteVideoTrack.value = event.track as VideoTrack;
        }
        onTrackSubscribed?.call(event.publication, event.participant);
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint('[LiveKitService] Track unsubscribed: ${event.track.kind}');
        if (event.track == remoteVideoTrack.value) {
          remoteVideoTrack.value = null;
        }
        onTrackUnsubscribed?.call(event.publication, event.participant);
      })
      ..on<LocalTrackPublishedEvent>((event) {
        debugPrint('[LiveKitService] Local track published: ${event.publication.kind}');
        if (event.publication.track is VideoTrack) {
          localVideoTrack.value = event.publication.track as VideoTrack;
        }
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        debugPrint('[LiveKitService] Local track unpublished: ${event.publication.kind}');
        if (event.publication.kind == TrackType.VIDEO) {
          localVideoTrack.value = null;
        }
      });
  }

  void _updateParticipantsList() {
    if (_room == null) {
      remoteParticipants.clear();
      return;
    }
    remoteParticipants.assignAll(_room!.remoteParticipants.values);
  }

  /// Toggle Microphone
  Future<void> setMicrophoneEnabled(bool enabled) async {
    try {
      if (enabled) {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          final res = await Permission.microphone.request();
          if (!res.isGranted) {
            debugPrint('[LiveKitService] Mic permission not granted');
            isMicMuted.value = true;
            return;
          }
        }
      }
      isMicMuted.value = !enabled;
      if (_room?.localParticipant != null) {
        await _room!.localParticipant!.setMicrophoneEnabled(enabled);
        for (final pub in _room!.localParticipant!.audioTrackPublications) {
          try {
            if (enabled) {
              await pub.unmute();
            } else {
              await pub.mute();
            }
          } catch (_) {}
        }
        debugPrint('[LiveKitService] Microphone set to: $enabled');
        try {
          BackgroundService().updateNotificationInfo(
            title: 'Voice Room: ${_room?.name ?? "Active"}',
            content: isMicMuted.value ? 'Voice Room in progress (Muted)' : 'Voice Room active',
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LiveKitService] Error setting microphone: $e');
    }
  }

  /// Toggle or set Loudspeaker (Speakerphone)
  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    try {
      await Hardware.instance.setSpeakerphoneOn(enabled);
      debugPrint('[LiveKitService] Speakerphone set to: $enabled');
    } catch (e) {
      debugPrint('[LiveKitService] Error setting speakerphone: $e');
    }
  }

  /// Toggle Camera
  Future<void> setCameraEnabled(bool enabled) async {
    try {
      if (_room?.localParticipant != null) {
        await _room!.localParticipant!.setCameraEnabled(enabled);
        isCameraEnabled.value = enabled;
        debugPrint('[LiveKitService] Camera set to: $enabled');
      }
    } catch (e) {
      debugPrint('[LiveKitService] Error setting camera: $e');
    }
  }

  /// Switch Front/Back Camera
  Future<void> switchCamera() async {
    try {
      final videoTrack = _room?.localParticipant?.videoTrackPublications
          .firstOrNull
          ?.track;
      if (videoTrack is LocalVideoTrack) {
        final options = videoTrack.currentOptions;
        CameraPosition newSource = CameraPosition.back;
        if (options is CameraCaptureOptions) {
          newSource = options.cameraPosition == CameraPosition.front
              ? CameraPosition.back
              : CameraPosition.front;
        }
        await videoTrack.restartTrack(
          CameraCaptureOptions(cameraPosition: newSource),
        );
        debugPrint('[LiveKitService] Switched camera to $newSource');
      }
    } catch (e) {
      debugPrint('[LiveKitService] Error switching camera: $e');
    }
  }

  /// Leave Room and release resources
  Future<void> leaveRoom() async {
    try {
      if (_listener != null) {
        await _listener!.dispose();
        _listener = null;
      }
      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
      }
      isConnected.value = false;
      isConnecting.value = false;
      isMicMuted.value = true;
      isCameraEnabled.value = false;
      currentRoomName.value = '';
      activeSpeakers.clear();
      remoteParticipants.clear();
      localVideoTrack.value = null;
      remoteVideoTrack.value = null;
      try {
        await BackgroundService().stopService();
      } catch (_) {}
      debugPrint('[LiveKitService] Left room successfully');
    } catch (e) {
      debugPrint('[LiveKitService] Error leaving room: $e');
    }
  }

  @override
  void onClose() {
    leaveRoom();
    super.onClose();
  }
}
