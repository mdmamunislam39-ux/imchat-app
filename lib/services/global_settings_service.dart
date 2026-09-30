import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class GlobalSettingsService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _telemetryTimer;

  // Reactive variables for real-time UI updates
  final RxString agoraAppId = 'c74eafbb98784225bae6be9b7e7f6225'.obs;
  final RxString agoraCertificate = ''.obs;
  final RxBool isVoiceRoomEnabled = true.obs;
  final RxBool isAudioCallEnabled = true.obs;
  final RxBool isVideoCallEnabled = true.obs;
  final RxBool isGroupCallEnabled = true.obs;
  final RxBool isLiveVideoRoomEnabled = true.obs;

  // LiveKit & Dual-Engine RTC Switch Settings
  // 'AGORA' or 'LIVEKIT' (or 'VPS') - Switched to 'LIVEKIT' with your server endpoint
  final RxString activeRtcEngine = 'LIVEKIT'.obs;
  final RxString livekitServerUrl = 'https://live.imchat.tech'.obs;
  final RxString livekitApiKey = 'imchat_prod'.obs;
  final RxString livekitApiSecret = 'Lk9pR4vT7xQ2mN8cY6sJ3wH5zA1dF0gB'.obs;
  final RxBool autoFailoverRtcToAgora = false.obs;

  // Dual-Engine Database/Backend Switch Settings (Firebase vs VPS PostgreSQL)
  // Default is 'FIREBASE' for full Firestore chat, rooms, and realtime data
  final RxString activeBackendEngine = 'FIREBASE'.obs;
  final RxString vpsBaseUrl = 'http://76.13.187.233:3000'.obs;
  final RxString vpsSocketUrl = 'http://76.13.187.233:3000'.obs;
  final RxBool autoFailoverBackendToFirebase = true.obs;

  // Additional settings from Section 2
  final RxString gameApiUrl = 'https://api.foodspin.com'.obs;
  final RxInt premiumRoomIdPrice = 500.obs;
  final RxBool maintenanceMode = false.obs;

  // Invitation & Ad Reward Settings
  final RxInt invitationRewardDiamonds = 100.obs;
  final RxString admobAppId = ''.obs;
  final RxString admobAdUnitId = ''.obs;
  final RxInt adRewardDiamonds = 10.obs;
  final RxInt maxAdsPerDay = 5.obs;
  final RxString videoCompletionType = 'full_video'.obs;
  final RxInt adVideoWatchSeconds = 0.obs;

  // Voice Room Global Rules (managed via Admin Panel)
  final RxString audioRoomRules =
      "There are a lot of very interested friends here. Let's chat together."
          .obs;

  // Family Levels (Added for family screen avatar frames)
  final RxList<Map<String, dynamic>> familyLevels =
      <Map<String, dynamic>>[].obs;

  Future<GlobalSettingsService> init() async {
    // Listen to changes on system_configs/audio_room_rules for all voice rooms
    _firestore
        .collection('system_configs')
        .doc('audio_room_rules')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final text = snapshot.data()!['rulesText'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          audioRoomRules.value = text;
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to system_configs/audio_room_rules: $e');
    });

    // Listen to changes in real-time on global_settings/app_settings (original)
    _firestore
        .collection('global_settings')
        .doc('app_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to global_settings/app_settings: $e');
    });

    // Listen to changes in real-time on global_settings/server_config (Admin Panel Realtime Server Setup)
    _firestore
        .collection('global_settings')
        .doc('server_config')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to global_settings/server_config: $e');
    });

    // Listen to changes in real-time on settings/global (Section 2)
    _firestore.collection('settings').doc('global').snapshots().listen(
        (snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to settings/global: $e');
    });

    // Listen to changes on system_configs/rtc_engine_settings for dynamic RTC Engine Switching
    _firestore
        .collection('system_configs')
        .doc('rtc_engine_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to system_configs/rtc_engine_settings: $e');
    });

    // Listen to changes on system_configs/vps_settings for dynamic VPS endpoints
    _firestore
        .collection('system_configs')
        .doc('vps_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to system_configs/vps_settings: $e');
    });

    // Listen to family levels
    _firestore
        .collection('settings')
        .doc('global')
        .collection('family_levels')
        .snapshots()
        .listen((snapshot) {
      final levels = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort levels by levelNumber
      levels.sort(
          (a, b) => (a['levelNumber'] ?? 0).compareTo(b['levelNumber'] ?? 0));

      familyLevels.assignAll(levels);
    }, onError: (e) {
      debugPrint('Error listening to family levels: $e');
    });

    // Start Real-Time Telemetry Heartbeat for Admin Panel Monitoring
    startTelemetryHeartbeat();

    return this;
  }

  void _parseData(Map<String, dynamic> data) {
    // Dynamically update Agora credentials in real-time from Firebase Admin Panel
    if (data.containsKey('agoraAppId') && data['agoraAppId'] != null) {
      final val = data['agoraAppId'].toString().trim();
      if (val.isNotEmpty) {
        agoraAppId.value = val;
      }
    }
    if (data.containsKey('agoraAppCertificate') && data['agoraAppCertificate'] != null) {
      final val = data['agoraAppCertificate'].toString().trim();
      if (val.isNotEmpty) {
        agoraCertificate.value = val;
      }
    } else if (data.containsKey('agoraCertificate') && data['agoraCertificate'] != null) {
      final val = data['agoraCertificate'].toString().trim();
      if (val.isNotEmpty) {
        agoraCertificate.value = val;
      }
    }
    if (data.containsKey('isVoiceRoomEnabled')) {
      isVoiceRoomEnabled.value = data['isVoiceRoomEnabled'] ?? true;
    }
    if (data.containsKey('isAudioCallEnabled')) {
      isAudioCallEnabled.value = data['isAudioCallEnabled'] ?? true;
    }
    if (data.containsKey('isVideoCallEnabled')) {
      isVideoCallEnabled.value = data['isVideoCallEnabled'] ?? true;
    }
    if (data.containsKey('isGroupCallEnabled')) {
      isGroupCallEnabled.value = data['isGroupCallEnabled'] ?? true;
    }
    if (data.containsKey('isLiveVideoRoomEnabled')) {
      isLiveVideoRoomEnabled.value = data['isLiveVideoRoomEnabled'] ?? true;
    }
    // Parse Active RTC Engine (AGORA / LIVEKIT / VPS)
    if (data.containsKey('activeRtcEngine') && data['activeRtcEngine'] != null) {
      final engine = data['activeRtcEngine'].toString().trim().toUpperCase();
      if (engine.isNotEmpty) {
        activeRtcEngine.value = engine;
      }
    }
    // Parse LiveKit Server URL (or vpsRtcEndpoint from server_config)
    if (data.containsKey('livekitServerUrl') && data['livekitServerUrl'] != null) {
      livekitServerUrl.value = data['livekitServerUrl'].toString().trim();
    } else if (data.containsKey('vpsRtcEndpoint') && data['vpsRtcEndpoint'] != null) {
      livekitServerUrl.value = data['vpsRtcEndpoint'].toString().trim();
    }
    // Parse LiveKit Keys
    if (data.containsKey('livekitApiKey') && data['livekitApiKey'] != null) {
      livekitApiKey.value = data['livekitApiKey'].toString().trim();
    } else if (data.containsKey('vpsRtcAuthToken') && data['vpsRtcAuthToken'] != null) {
      livekitApiKey.value = data['vpsRtcAuthToken'].toString().trim();
    }
    if (data.containsKey('livekitApiSecret') && data['livekitApiSecret'] != null) {
      livekitApiSecret.value = data['livekitApiSecret'].toString().trim();
    }
    if (data.containsKey('autoFailoverRtcToAgora') && data['autoFailoverRtcToAgora'] != null) {
      autoFailoverRtcToAgora.value = data['autoFailoverRtcToAgora'] == true;
    }
    // Parse Active Backend Engine (FIREBASE vs VPS)
    if (data.containsKey('activeBackendEngine') && data['activeBackendEngine'] != null) {
      final engine = data['activeBackendEngine'].toString().trim().toUpperCase();
      if (engine.isNotEmpty) {
        activeBackendEngine.value = engine;
      }
    }
    // Parse VPS Base URL (REST API)
    if (data.containsKey('vpsBaseUrl') && data['vpsBaseUrl'] != null) {
      vpsBaseUrl.value = data['vpsBaseUrl'].toString().trim();
    } else if (data.containsKey('vpsApiEndpoint') && data['vpsApiEndpoint'] != null) {
      vpsBaseUrl.value = data['vpsApiEndpoint'].toString().trim();
    }
    // Parse VPS Socket URL (WebSocket)
    if (data.containsKey('vpsSocketUrl') && data['vpsSocketUrl'] != null) {
      vpsSocketUrl.value = data['vpsSocketUrl'].toString().trim();
    } else if (data.containsKey('vpsWsEndpoint') && data['vpsWsEndpoint'] != null) {
      vpsSocketUrl.value = data['vpsWsEndpoint'].toString().trim();
    }
    if (data.containsKey('autoFailoverBackendToFirebase') && data['autoFailoverBackendToFirebase'] != null) {
      autoFailoverBackendToFirebase.value = data['autoFailoverBackendToFirebase'] == true;
    }
    if (data.containsKey('gameApiUrl')) {
      gameApiUrl.value = data['gameApiUrl'] ?? '';
    }
    if (data.containsKey('premiumRoomIdPrice')) {
      final val = data['premiumRoomIdPrice'];
      if (val is int) {
        premiumRoomIdPrice.value = val;
      } else if (val is num) {
        premiumRoomIdPrice.value = val.toInt();
      }
    }
    if (data.containsKey('maintenanceMode')) {
      maintenanceMode.value = data['maintenanceMode'] ?? false;
    }
    if (data.containsKey('invitationRewardDiamonds')) {
      final val = data['invitationRewardDiamonds'];
      if (val is int) {
        invitationRewardDiamonds.value = val;
      } else if (val is num) {
        invitationRewardDiamonds.value = val.toInt();
      }
    }
    if (data.containsKey('admobAppId')) {
      admobAppId.value = data['admobAppId'] ?? '';
    }
    if (data.containsKey('admobAdUnitId')) {
      admobAdUnitId.value = data['admobAdUnitId'] ?? '';
    }
    if (data.containsKey('adRewardDiamonds')) {
      final val = data['adRewardDiamonds'];
      if (val is int) {
        adRewardDiamonds.value = val;
      } else if (val is num) {
        adRewardDiamonds.value = val.toInt();
      }
    }
    if (data.containsKey('maxAdsPerDay')) {
      final val = data['maxAdsPerDay'];
      if (val is int) {
        maxAdsPerDay.value = val;
      } else if (val is num) {
        maxAdsPerDay.value = val.toInt();
      }
    }
    if (data.containsKey('videoCompletionType')) {
      videoCompletionType.value = data['videoCompletionType'] ?? 'full_video';
    }
    if (data.containsKey('adVideoWatchSeconds')) {
      final val = data['adVideoWatchSeconds'];
      if (val is int) {
        adVideoWatchSeconds.value = val;
      } else if (val is num) {
        adVideoWatchSeconds.value = val.toInt();
      }
    }
  }

  Future<void> updateAudioRoomRules(String newRules) async {
    await _firestore
        .collection('system_configs')
        .doc('audio_room_rules')
        .set({
      'rulesText': newRules,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    audioRoomRules.value = newRules;
  }

  /// Starts periodic telemetry pulse to Firestore for Real-Time Admin Monitoring
  void startTelemetryHeartbeat({String? userId, String? userName, String? activeScreen}) {
    _publishTelemetry(userId: userId, userName: userName, activeScreen: activeScreen);
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _publishTelemetry(userId: userId, userName: userName, activeScreen: activeScreen);
    });
  }

  void _publishTelemetry({String? userId, String? userName, String? activeScreen}) {
    try {
      final platformName = defaultTargetPlatform.name;
      final docId = userId != null && userId.isNotEmpty ? userId : 'client_${platformName}_node';
      _firestore.collection('system_telemetry').doc(docId).set({
        'userId': userId ?? 'app_user',
        'userName': userName ?? 'Mobile User ($platformName)',
        'platform': platformName,
        'activeRtcEngine': activeRtcEngine.value,
        'activeBackendEngine': activeBackendEngine.value,
        'livekitServerUrl': livekitServerUrl.value,
        'vpsBaseUrl': vpsBaseUrl.value,
        'agoraAppId': agoraAppId.value,
        'activeScreen': activeScreen ?? 'Online (App Active)',
        'latency': 25,
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'status': 'ONLINE',
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
