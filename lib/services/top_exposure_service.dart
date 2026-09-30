import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/grab_the_top_service.dart';

/// Model representing an active Top Exposure state
class TopExposure {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;
  final String giftId;
  final String giftName;
  final String giftPngUrl;
  final int giftCredits;
  final int quantity;
  final int totalDiamonds;
  final String roomId;
  final String roomName;
  final int durationSeconds;
  final DateTime expiresAt;
  final DateTime createdAt;

  TopExposure({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
    required this.giftId,
    required this.giftName,
    required this.giftPngUrl,
    required this.giftCredits,
    required this.quantity,
    required this.totalDiamonds,
    required this.roomId,
    required this.roomName,
    required this.durationSeconds,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory TopExposure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseDate(data['createdAt']);
    final expiresAt = parseDate(data['expiresAt']);

    return TopExposure(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonymous',
      senderImageUrl: data['senderImageUrl'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Host',
      receiverImageUrl: data['receiverImageUrl'],
      giftId: data['giftId'] ?? '',
      giftName: data['giftName'] ?? 'Gift',
      giftPngUrl: data['giftPngUrl'] ?? '',
      giftCredits: (data['giftCredits'] ?? 0) as int,
      quantity: (data['quantity'] ?? 1) as int,
      totalDiamonds: (data['totalDiamonds'] ?? 0) as int,
      roomId: data['roomId'] ?? '',
      roomName: data['roomName'] ?? 'Voice Room',
      durationSeconds: (data['durationSeconds'] ?? 180) as int,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImageUrl': receiverImageUrl,
      'giftId': giftId,
      'giftName': giftName,
      'giftPngUrl': giftPngUrl,
      'giftCredits': giftCredits,
      'quantity': quantity,
      'totalDiamonds': totalDiamonds,
      'roomId': roomId,
      'roomName': roomName,
      'durationSeconds': durationSeconds,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Service to manage top exposure configs and real-time state
class TopExposureService extends GetxController {
  static TopExposureService get instance {
    if (!Get.isRegistered<TopExposureService>()) {
      return Get.put(TopExposureService(), permanent: true);
    }
    return Get.find<TopExposureService>();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configurable parameters
  final RxList<String> specificGiftIds = <String>[].obs;
  final RxInt minDiamonds = 600.obs; // Default 600 diamonds
  final RxInt defaultDurationSeconds = 180.obs; // Default 180 seconds

  // Active exposure state
  final Rxn<TopExposure> activeTopExposure = Rxn<TopExposure>();
  StreamSubscription<DocumentSnapshot>? _subscription;
  StreamSubscription<DocumentSnapshot>? _configSubscription;

  @override
  void onInit() {
    super.onInit();
    _startListening();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _configSubscription?.cancel();
    super.onClose();
  }

  /// Listen to global_top_exposure/current document & platform_config/top_exposure in Firestore
  void _startListening() {
    _subscription = _firestore
        .collection('global_top_exposure')
        .doc('current')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final exposure = TopExposure.fromFirestore(doc);
        if (!exposure.isExpired) {
          activeTopExposure.value = exposure;
        } else {
          activeTopExposure.value = null;
        }
      } else {
        activeTopExposure.value = null;
      }
    }, onError: (err) {
      debugPrint('⚠️ [TopExposureService] Stream error: $err');
    });

    _configSubscription = _firestore
        .collection('platform_config')
        .doc('top_exposure')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['defaultDurationSeconds'] != null) {
          defaultDurationSeconds.value = (data['defaultDurationSeconds'] as num).toInt();
        }
        if (data['minDiamonds'] != null) {
          minDiamonds.value = (data['minDiamonds'] as num).toInt();
        }
        if (data['specificGiftIds'] is List) {
          specificGiftIds.assignAll(List<String>.from(data['specificGiftIds']));
        }
        debugPrint('🔥 [TopExposureService] Config updated real-time: duration=${defaultDurationSeconds.value}s, minDiamonds=${minDiamonds.value}');
      }
    }, onError: (err) {
      debugPrint('⚠️ [TopExposureService] Config stream error: $err');
    });
  }

  /// Configure specific gift IDs that qualify for Top Exposure
  void setSpecificGiftIds(List<String> giftIds) {
    specificGiftIds.assignAll(giftIds);
  }

  /// Add a specific gift ID to qualifying list
  void addSpecificGiftId(String giftId) {
    if (!specificGiftIds.contains(giftId)) {
      specificGiftIds.add(giftId);
    }
  }

  /// Configure minimum diamond threshold required
  void setMinDiamonds(int diamonds) {
    minDiamonds.value = diamonds;
  }

  /// Configure default duration seconds
  void setDefaultDurationSeconds(int seconds) {
    defaultDurationSeconds.value = seconds;
  }

  /// Calculate exposure duration for a given gift and diamond count,
  /// prioritizing showing time set in Admin Panel (per gift, per rule, or default).
  int getDurationForGift({
    required String giftId,
    required int totalDiamonds,
    int? giftShowingTime,
    String? giftName,
    int quantity = 1,
  }) {
    // 1. Explicit showing time attached directly to the gift in Admin Panel
    if (giftShowingTime != null && giftShowingTime > 0) {
      return giftShowingTime;
    }

    // 2. Check if a Grab The Top / Top Exposure rule from Admin Panel matches
    final activeRules = GrabTheTopService.instance.activeRules;
    for (final rule in activeRules) {
      final bool idMatch = rule.giftId.isNotEmpty &&
          (rule.giftId == giftId || giftId.contains(rule.giftId));
      final bool nameMatch = giftName != null &&
          rule.giftName.isNotEmpty &&
          giftName.toLowerCase().contains(rule.giftName.toLowerCase());

      if ((idMatch || nameMatch) && quantity >= rule.minGiftCount) {
        if (rule.showingTimeSeconds > 0) {
          return rule.showingTimeSeconds;
        }
      }
    }

    // 3. Fallback to default duration configured in real-time from Admin Panel
    return defaultDurationSeconds.value;
  }

  /// Check if a gift transaction qualifies and trigger Top Exposure
  Future<bool> checkAndTriggerTopExposure({
    required String giftId,
    required String giftName,
    required String giftPngUrl,
    required int giftCredits,
    required int quantity,
    required int totalDiamonds,
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required String receiverId,
    required String receiverName,
    required String? receiverImageUrl,
    required String roomId,
    String? roomName,
    int? giftShowingTime,
  }) async {
    // Qualification rule:
    // ONLY qualify and trigger if this gift and quantity matches an active rule configured in Admin Panel!
    final matchedRule = GrabTheTopService.instance.findMatchingRule(
      giftId: giftId,
      giftName: giftName,
      quantity: quantity,
    );

    if (matchedRule == null) {
      debugPrint('[TopExposureService] Gift "$giftName" (ID: $giftId, Qty: $quantity) does not match any active Grab The Top rule. Skipping.');
      return false;
    }

    final durationSec = matchedRule.showingTimeSeconds > 0
        ? matchedRule.showingTimeSeconds
        : (giftShowingTime != null && giftShowingTime > 0 ? giftShowingTime : defaultDurationSeconds.value);
    final now = DateTime.now();
    final expiresAt = now.add(Duration(seconds: durationSec));
    final exposureId = 'exp_${now.millisecondsSinceEpoch}';

    final newExposure = TopExposure(
      id: exposureId,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverImageUrl: receiverImageUrl,
      giftId: giftId,
      giftName: giftName,
      giftPngUrl: giftPngUrl,
      giftCredits: giftCredits,
      quantity: quantity,
      totalDiamonds: totalDiamonds,
      roomId: roomId,
      roomName: roomName ?? 'Voice Room',
      durationSeconds: durationSec,
      expiresAt: expiresAt,
      createdAt: now,
    );

    final mapData = newExposure.toMap();
    mapData['id'] = exposureId;

    try {
      await _firestore
          .collection('global_top_exposure')
          .doc('current')
          .set(mapData);

      activeTopExposure.value = newExposure;
      debugPrint('🔥 [TopExposureService] Top exposure triggered by $senderName in room $roomId ($durationSec s)!');
      return true;
    } catch (e) {
      debugPrint('❌ [TopExposureService] Error setting top exposure: $e');
      return false;
    }
  }
}
