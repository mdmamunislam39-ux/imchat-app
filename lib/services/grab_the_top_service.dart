import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/models/grab_the_top_model.dart';

class GrabTheTopService {
  GrabTheTopService._privateConstructor() {
    _listenToConfigAndRules();
  }
  static final GrabTheTopService instance = GrabTheTopService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isFeatureEnabled = true;
  int _defaultShowingTimeSeconds = 10;
  List<GrabTheTopRule> _activeRules = [];
  StreamSubscription<DocumentSnapshot>? _configSubscription;
  StreamSubscription<QuerySnapshot>? _rulesSubscription;

  bool get isFeatureEnabled => _isFeatureEnabled;
  int get defaultShowingTimeSeconds => _defaultShowingTimeSeconds;
  List<GrabTheTopRule> get activeRules => List.unmodifiable(_activeRules);

  void initialize() {
    _listenToConfigAndRules();
  }

  void _listenToConfigAndRules() {
    _configSubscription?.cancel();
    _configSubscription = _firestore
        .collection('platform_config')
        .doc('grab_the_top')
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        _isFeatureEnabled = data['isFeatureEnabled'] ?? true;
        _defaultShowingTimeSeconds = (data['defaultShowingTimeSeconds'] ?? data['showingTimeSeconds'] ?? 10) as int;
        debugPrint('[GrabTheTopService] Config updated: featureEnabled=$_isFeatureEnabled, defaultShowingTime=${_defaultShowingTimeSeconds}s');
      }
    });

    _rulesSubscription?.cancel();
    _rulesSubscription = _firestore
        .collection('platform_config')
        .doc('grab_the_top')
        .collection('rules')
        .snapshots()
        .listen((snap) {
      final loaded = snap.docs
          .map((doc) => GrabTheTopRule.fromFirestore(doc))
          .where((r) => r.isActive)
          .toList();
      _activeRules = loaded;
      debugPrint('[GrabTheTopService] Loaded ${_activeRules.length} active Grab The Top rules.');
    });
  }

  /// Check if sent gift & quantity matches any active rule configured in Admin Panel.
  /// ONLY returns a rule if the gift name/id and quantity strictly match an active rule.
  GrabTheTopRule? findMatchingRule({
    required String giftId,
    required String giftName,
    required int quantity,
  }) {
    if (!_isFeatureEnabled) return null;

    final cleanGiftId = giftId.trim();
    final cleanGiftName = giftName.trim().toLowerCase();

    for (final rule in _activeRules) {
      if (!rule.isActive) continue;

      final ruleGiftId = rule.giftId.trim();
      final ruleGiftName = rule.giftName.trim().toLowerCase();

      bool matchesGift = false;

      // 1. Exact gift ID match
      if (ruleGiftId.isNotEmpty && cleanGiftId.isNotEmpty) {
        if (ruleGiftId == cleanGiftId || cleanGiftId.contains(ruleGiftId)) {
          matchesGift = true;
        }
      }

      // 2. Gift Name match (case-insensitive exact or substring)
      if (!matchesGift && ruleGiftName.isNotEmpty && cleanGiftName.isNotEmpty) {
        if (ruleGiftName == cleanGiftName ||
            cleanGiftName.contains(ruleGiftName) ||
            ruleGiftName.contains(cleanGiftName)) {
          matchesGift = true;
        }
      }

      // 3. Minimum quantity check
      if (matchesGift && quantity >= rule.minGiftCount) {
        return rule;
      }
    }

    return null;
  }

  /// Check if sent gift & quantity matches any active rule, and trigger real-time top seat event.
  /// ONLY triggers if gift strictly matches an active Admin Panel rule and meets the minimum quantity!
  Future<void> checkAndTriggerGrabTheTop({
    required String giftId,
    required String giftName,
    required String giftPngUrl,
    required int quantity,
    required String senderId,
    required String senderName,
    String? senderImageUrl,
    required String receiverId,
    required String receiverName,
    String? receiverImageUrl,
    required String roomId,
  }) async {
    if (!_isFeatureEnabled) return;

    // Reload rules if empty
    if (_activeRules.isEmpty) {
      final snap = await _firestore
          .collection('platform_config')
          .doc('grab_the_top')
          .collection('rules')
          .get();
      _activeRules = snap.docs
          .map((doc) => GrabTheTopRule.fromFirestore(doc))
          .where((r) => r.isActive)
          .toList();
    }

    // Only proceed if a rule configured in Admin Panel matches!
    final GrabTheTopRule? matchedRule = findMatchingRule(
      giftId: giftId,
      giftName: giftName,
      quantity: quantity,
    );

    if (matchedRule == null) {
      debugPrint('[GrabTheTopService] Gift "$giftName" (ID: $giftId, Qty: $quantity) does not match any active Grab The Top rule. Skipping.');
      return;
    }

    final int duration = matchedRule.showingTimeSeconds > 0
        ? matchedRule.showingTimeSeconds
        : _defaultShowingTimeSeconds;

    debugPrint('[GrabTheTopService] MATCHED rule (${matchedRule.giftName} min ${matchedRule.minGiftCount}x)! Triggering Top Seat for $senderName -> $receiverName (Gift: $giftName x$quantity, Duration: ${duration}s)');

    final expiresAt = DateTime.now().add(Duration(seconds: duration));

    final eventData = {
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImageUrl': receiverImageUrl,
      'giftId': giftId,
      'giftName': giftName,
      'giftPngUrl': giftPngUrl,
      'quantity': quantity,
      'roomId': roomId,
      'showingTimeSeconds': duration,
      'bannerTitle': matchedRule.bannerTitle,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save to grab_the_top_events collection
    await _firestore.collection('grab_the_top_events').add(eventData);

    // Also write to active_grab_the_top doc for room
    await _firestore.collection('active_grab_the_top').doc(roomId).set(eventData);
  }

  /// Real-time stream listener for room top seat event
  Stream<ActiveGrabTheTopEvent?> streamRoomGrabTheTop(String roomId) {
    return _firestore
        .collection('active_grab_the_top')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final event = ActiveGrabTheTopEvent.fromFirestore(doc);
      return event.isExpired ? null : event;
    });
  }
}