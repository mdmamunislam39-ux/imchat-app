import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class GlobalSettingsService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reactive variables for real-time UI updates
  final RxString agoraAppId = 'c74eafbb98784225bae6be9b7e7f6225'.obs;
  final RxString agoraCertificate = 'eb4c5875fba74804b9d348882d7365f0'.obs;
  final RxBool isVoiceRoomEnabled = true.obs;
  final RxBool isAudioCallEnabled = true.obs;
  final RxBool isVideoCallEnabled = true.obs;
  final RxBool isGroupCallEnabled = true.obs;
  final RxBool isLiveVideoRoomEnabled = true.obs;

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

  // Family Levels (Added for family screen avatar frames)
  final RxList<Map<String, dynamic>> familyLevels =
      <Map<String, dynamic>>[].obs;

  Future<GlobalSettingsService> init() async {
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

    // Listen to changes in real-time on settings/global (Section 2)
    _firestore.collection('settings').doc('global').snapshots().listen(
        (snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseData(snapshot.data()!);
      }
    }, onError: (e) {
      debugPrint('Error listening to settings/global: $e');
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

    return this;
  }

  void _parseData(Map<String, dynamic> data) {
    // Agora App ID and Certificate are hardcoded and should not be overridden by Firebase
    // to prevent connectivity issues caused by mismatched or stale credentials.
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
}
