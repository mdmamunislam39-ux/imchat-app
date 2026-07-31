import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Service for gift economy config (bean splits, conversion rates) and withdrawals.
class GiftEconomyService {
  static final GiftEconomyService _instance = GiftEconomyService._internal();
  factory GiftEconomyService() => _instance;
  GiftEconomyService._internal();

  static GiftEconomyService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Cached config
  Map<String, dynamic>? _cachedConfig;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Default config values
  static const Map<String, dynamic> _defaults = {
    'hostReceiverRate': 0.70,
    'hostAgencyRate': 0.10,
    'normalReceiverRate': 0.50,
    'beanToDiamondRate': 1.0,
  };

  /// Get gift economy config from platform_config/gift_conversion.
  /// Caches for 5 minutes; falls back to defaults on error.
  Future<Map<String, dynamic>> getConfig() async {
    if (_cachedConfig != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedConfig!;
    }

    try {
      final doc = await _firestore
          .collection('platform_config')
          .doc('gift_conversion')
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedConfig = {..._defaults, ...doc.data()!};
      } else {
        _cachedConfig = Map.from(_defaults);
      }
      _cacheTimestamp = DateTime.now();
      debugPrint('💎 GiftEconomyService: Config loaded: $_cachedConfig');
      return _cachedConfig!;
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error loading config: $e');
      return Map.from(_defaults);
    }
  }

  /// Clear cached config (useful after admin updates).
  void clearCache() {
    _cachedConfig = null;
    _cacheTimestamp = null;
  }

  /// Check if user can withdraw (no existing pending withdrawal).
  Future<bool> canUserWithdraw(String userId) async {
    try {
      final query = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      return query.docs.isEmpty;
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error checking withdrawal: $e');
      return false;
    }
  }

  /// Create a withdrawal request. Deducts beans in a Firestore transaction
  /// and creates a withdrawal doc with status 'pending'.
  Future<bool> createWithdrawalRequest({
    required String userId,
    required String username,
    required String userType,
    required int amount,
    required String accountNumber,
    String note = '',
  }) async {
    try {
      final userRef = _firestore.collection('Users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception('User not found');

        final currentBeans = userDoc.data()?['beans'] ?? 0;
        if (currentBeans < amount) {
          throw Exception('Insufficient beans');
        }

        // Deduct beans (escrow)
        transaction.update(userRef, {
          'beans': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create withdrawal doc
        final withdrawalId = _uuid.v4();
        transaction.set(
          _firestore.collection('withdrawals').doc(withdrawalId),
          {
            'id': withdrawalId,
            'userId': userId,
            'username': username,
            'userType': userType,
            'amount': amount,
            'accountNumber': accountNumber,
            'note': note,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint(
          '✅ GiftEconomyService: Withdrawal request created for $amount beans');
      return true;
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error creating withdrawal: $e');
      rethrow;
    }
  }

  /// Get user's withdrawal history ordered by createdAt desc.
  Future<List<Map<String, dynamic>>> getUserWithdrawals(String userId) async {
    try {
      final query = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error fetching withdrawals: $e');
      return [];
    }
  }

  /// Get sum of pending withdrawal amounts for a user.
  Future<int> getPendingWithdrawalAmount(String userId) async {
    try {
      final query = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      int total = 0;
      for (final doc in query.docs) {
        total += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint(
          '❌ GiftEconomyService: Error fetching pending withdrawals: $e');
      return 0;
    }
  }
}
