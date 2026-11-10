import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/models/user.dart';

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

  /// When a user confirms they have received payment from the seller:
  /// Marks the withdrawal as 'approved', sets 'userConfirmed' to true,
  /// credits the seller's account balance with the equivalent diamonds (e.g. 90%),
  /// logs to seller_admin_credits, and notifies both seller and user via OfficialTeamApi.
  Future<bool> userAcceptWithdrawal({
    required String docId,
    required Map<String, dynamic> data,
    required String userId,
    required String userName,
    String? userDeviceToken,
  }) async {
    try {
      // 1. Verify doc status
      final docRef = _firestore.collection('withdrawals').doc(docId);
      final currentDoc = await docRef.get();
      if (!currentDoc.exists) {
        throw Exception('Withdrawal record not found.');
      }
      final currentData = currentDoc.data() ?? {};
      final currentStatus = (currentData['status'] as String?)?.toLowerCase() ?? '';
      if (currentStatus == 'approved') {
        debugPrint('Withdrawal #$docId is already approved.');
        return true;
      }
      if (currentStatus == 'rejected') {
        throw Exception('This withdrawal was rejected and cannot be accepted.');
      }

      final beanAmount = (currentData['beanAmount'] as num?)?.toInt() ??
          (currentData['amount'] as num?)?.toInt() ??
          0;
      final usdAmount = (currentData['usdAmount'] as num?)?.toDouble() ?? 0.0;
      final sellerId = currentData['sellerId'] as String? ?? currentData['dealerId'] as String? ?? '';
      final sellerName = currentData['sellerName'] as String? ?? currentData['dealerName'] as String? ?? 'Seller';
      final int sellerDiamondPercent = (currentData['sellerDiamondPercent'] as num?)?.toInt() ?? 90;
      final int diamondReward = (currentData['diamondReward'] as num?)?.toInt() ??
          (beanAmount * (sellerDiamondPercent / 100.0)).round();

      // 2. Update withdrawal document
      await docRef.update({
        'status': 'approved',
        'userConfirmed': true,
        'userConfirmedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'diamondReward': diamondReward,
      });

      // 3. Credit diamonds to seller
      if (sellerId.isNotEmpty) {
        final sellerSnap = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: sellerId)
            .limit(1)
            .get();

        String sellerDocId = '';
        if (sellerSnap.docs.isNotEmpty) {
          sellerDocId = sellerSnap.docs.first.id;
          await _firestore.collection('sellers').doc(sellerDocId).update({
            'accountBalance': FieldValue.increment(diamondReward),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final newDoc = _firestore.collection('sellers').doc();
          sellerDocId = newDoc.id;
          await newDoc.set({
            'userId': sellerId,
            'sellerName': sellerName,
            'accountBalance': diamondReward,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Also credit seller's User document diamonds
        await _firestore.collection('Users').doc(sellerId).update({
          'diamonds': FieldValue.increment(diamondReward),
        });

        // 4. Create log in seller_admin_credits
        final creditDoc = _firestore.collection('seller_admin_credits').doc();
        await creditDoc.set({
          'id': creditDoc.id,
          'sellerId': sellerId,
          'sellerDocId': sellerDocId,
          'sellerName': sellerName,
          'amount': diamondReward,
          'note': 'Reward for withdrawal of $beanAmount beans (\$ $usdAmount) confirmed and accepted by user $userName',
          'type': 'withdrawal_reward_user_accepted',
          'withdrawalId': docId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 5. Send Official notification to seller
        try {
          final sellerUserDoc = await _firestore.collection('Users').doc(sellerId).get();
          if (sellerUserDoc.exists) {
            final sUser = User.fromMap(sellerUserDoc.data()!);
            OfficialTeamApi.sendOfficialMessage(
              receiverId: sUser.userId,
              receiverDeviceToken: sUser.deviceToken,
              messageText: 'Payment Confirmed by User! User $userName has confirmed receipt of \$ $usdAmount ($beanAmount beans). +$diamondReward diamonds (stock) have been credited to your diamond balance for withdrawal #$docId.',
            );
          }
        } catch (e) {
          debugPrint('Error sending official notification to seller: $e');
        }
      }

      // 6. Send Official notification to user
      try {
        OfficialTeamApi.sendOfficialMessage(
          receiverId: userId,
          receiverDeviceToken: userDeviceToken ?? '',
          messageText: 'Withdrawal of $beanAmount beans (\$ $usdAmount) completed! Thank you for confirming receipt of payment for withdrawal #$docId.',
        );
      } catch (e) {
        debugPrint('Error sending official notification to user: $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ GiftEconomyService: Error in userAcceptWithdrawal: $e');
      rethrow;
    }
  }
}
