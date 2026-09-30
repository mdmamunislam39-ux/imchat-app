import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Service for gift economy config (bean splits, conversion rates) and withdrawals.
class GiftEconomyService {
  static final GiftEconomyService _instance = GiftEconomyService._internal();
  factory GiftEconomyService() => _instance;

  GiftEconomyService._internal() {
    _startListening();
  }

  static GiftEconomyService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Cached config
  Map<String, dynamic>? _cachedConfig;
  DateTime? _cacheTimestamp;
  StreamSubscription<DocumentSnapshot>? _configSub;

  DateTime? get cacheTimestamp => _cacheTimestamp;

  // Default config values
  static const Map<String, dynamic> _defaults = {
    'hostReceiverRate': 0.70,
    'hostAgencyRate': 0.10,
    'normalReceiverRate': 0.50,
    'beanToDiamondRate': 1.0,
    'beansPerUsd': 10000,
    'minWithdrawUsd': 20,
    'isWithdrawalEnabled': true,
    'withdrawPackages': [20, 75, 100, 200, 500, 800, 1000, 3000],
  };

  /// Rate: 1 USD = X Beans (e.g. 10,000)
  int get beansPerUsd =>
      (currentConfig['beansPerUsd'] as num?)?.toInt() ?? 10000;

  /// Minimum withdrawal amount in USD
  int get minWithdrawUsd =>
      (currentConfig['minWithdrawUsd'] as num?)?.toInt() ?? 20;

  /// Whether withdrawal feature is enabled or hidden by admin
  bool get isWithdrawalEnabled =>
      currentConfig['isWithdrawalEnabled'] as bool? ?? true;

  /// Seller diamond reward percentage
  int get sellerDiamondPercent =>
      (currentConfig['sellerDiamondPercent'] as num?)?.toInt() ?? 90;

  /// Available preset USD packages
  List<int> get withdrawPackages =>
      (currentConfig['withdrawPackages'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [20, 75, 100, 200, 500, 800, 1000, 3000];

  /// Start listening to platform_config/gift_conversion in real-time
  void _startListening() {
    try {
      _configSub?.cancel();
      _configSub = _firestore
          .collection('platform_config')
          .doc('gift_conversion')
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          _cachedConfig = {..._defaults, ...doc.data()!};
          _cacheTimestamp = DateTime.now();
          debugPrint('💎 [GiftEconomyService] Real-time config synced: $_cachedConfig');
        }
      }, onError: (e) {
        debugPrint('❌ [GiftEconomyService] Error in config snapshot: $e');
      });
    } catch (e) {
      debugPrint('❌ [GiftEconomyService] Failed to attach realtime listener: $e');
    }
  }

  /// Get gift economy config from platform_config/gift_conversion.
  /// Uses cached real-time snapshot data or fetches from Firestore if not yet cached.
  Future<Map<String, dynamic>> getConfig() async {
    if (_cachedConfig != null) {
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

  /// Synchronous getter for current config
  Map<String, dynamic> get currentConfig => _cachedConfig ?? _defaults;

  /// Calculate bean split for receiver, agency, and platform
  Map<String, int> calculateSplit({
    required int diamondAmount,
    required bool isHost,
    required bool hasAgency,
  }) {
    if (diamondAmount <= 0) {
      return {
        'beansToReceiver': 0,
        'beansToAgency': 0,
        'platformShare': 0,
      };
    }
    final config = currentConfig;
    final hostReceiverRate = (config['hostReceiverRate'] as num?)?.toDouble() ?? 0.70;
    final hostAgencyRate = (config['hostAgencyRate'] as num?)?.toDouble() ?? 0.10;
    final normalReceiverRate = (config['normalReceiverRate'] as num?)?.toDouble() ?? 0.50;

    if (isHost) {
      final beansToReceiver = (diamondAmount * hostReceiverRate).floor();
      final beansToAgency = hasAgency ? (diamondAmount * hostAgencyRate).floor() : 0;
      final platformShare = (diamondAmount - beansToReceiver - beansToAgency).clamp(0, diamondAmount);
      return {
        'beansToReceiver': beansToReceiver,
        'beansToAgency': beansToAgency,
        'platformShare': platformShare,
      };
    } else {
      final beansToReceiver = (diamondAmount * normalReceiverRate).floor();
      final platformShare = (diamondAmount - beansToReceiver).clamp(0, diamondAmount);
      return {
        'beansToReceiver': beansToReceiver,
        'beansToAgency': 0,
        'platformShare': platformShare,
      };
    }
  }

  /// Clear cached config and re-listen
  void clearCache() {
    _cachedConfig = null;
    _cacheTimestamp = null;
    _startListening();
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

  /// Create a bean withdrawal request with dealer info and USD amount.
  Future<bool> createBeanWithdrawalRequest({
    required String userId,
    required String username,
    String? userSearchId,
    required String userType,
    required int beanAmount,
    required double usdAmount,
    required String accountNumber,
    String accountName = '',
    String withdrawalName = '',
    String withdrawalBkash = '',
    String dealerId = '',
    String dealerName = '',
    String? dealerSearchId,
    String note = '',
  }) async {
    try {
      final userRef = _firestore.collection('Users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception('User not found');

        final currentBeans = (userDoc.data()?['beans'] as num?)?.toInt() ?? 0;
        if (currentBeans < beanAmount) {
          throw Exception('Insufficient beans');
        }

        // Deduct beans
        transaction.update(userRef, {
          'beans': FieldValue.increment(-beanAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create withdrawal doc
        final withdrawalId = _uuid.v4();
        final finalAccountName = withdrawalName.isNotEmpty
            ? withdrawalName
            : (accountName.isNotEmpty ? accountName : username);
        final finalBkashNumber = withdrawalBkash.isNotEmpty
            ? withdrawalBkash
            : accountNumber;

        transaction.set(
          _firestore.collection('withdrawals').doc(withdrawalId),
          {
            'id': withdrawalId,
            'userId': userId,
            'username': username,
            'userType': userType,
            'beanAmount': beanAmount,
            'amount': beanAmount,
            'usdAmount': usdAmount,
            'accountNumber': finalBkashNumber,
            'accountName': finalAccountName,
            'withdrawalName': finalAccountName,
            'withdrawalBkash': finalBkashNumber,
            'dealerId': dealerId,
            'dealerName': dealerName,
            'sellerId': dealerId,
            'sellerName': dealerName,
            'userSearchId': userSearchId,
            'sellerSearchId': dealerSearchId,
            'dealerSearchId': dealerSearchId,
            'sellerDiamondPercent': sellerDiamondPercent,
            'diamondReward': (beanAmount * (sellerDiamondPercent / 100.0)).round(),
            'type': 'bean_withdraw',
            'method': 'Withdraw',
            'currency': 'USD',
            'note': note,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint(
          '✅ GiftEconomyService: Bean withdrawal request created for $beanAmount beans (\$ $usdAmount)');
      return true;
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error creating bean withdrawal: $e');
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
