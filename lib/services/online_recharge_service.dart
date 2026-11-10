import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recharge_models.dart';
import 'store_service.dart';
import 'svip_service.dart';
import '../api/official_team_api.dart';

/// Service managing Online Recharge payment methods, packages, orders, and atomic diamond credit
class OnlineRechargeService {
  static final OnlineRechargeService instance = OnlineRechargeService._internal();
  OnlineRechargeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  static const String _paymentMethodsCol = 'paymentMethods';
  static const String _rechargePackagesCol = 'rechargePackages';
  static const String _rechargeOrdersCol = 'rechargeOrders';
  static const String _usersCol = 'Users';
  static const String _transactionsCol = 'wallet_transactions';

  // Default fallback packages when Firestore collection is empty
  static final List<RechargePackageModel> defaultPackages = [
    RechargePackageModel(id: 'pkg_5000', amount: 150, diamondAmount: 5000, sortOrder: 1),
    RechargePackageModel(id: 'pkg_25000', amount: 700, diamondAmount: 25000, sortOrder: 2),
    RechargePackageModel(id: 'pkg_50000', amount: 1400, diamondAmount: 50000, sortOrder: 3),
    RechargePackageModel(id: 'pkg_90000', amount: 2500, diamondAmount: 90000, sortOrder: 4),
  ];

  // Default fallback payment method when none configured yet
  static final List<PaymentMethodModel> defaultPaymentMethods = [
    PaymentMethodModel(
      id: 'default_bkash',
      name: 'bKash',
      number: '01609738735',
      iconUrl: '',
      status: 'ON',
      instructions: "'সেন্ড মানি' দিয়ে পরিশোধ করুন",
    ),
    PaymentMethodModel(
      id: 'default_nagad',
      name: 'Nagad',
      number: '01609738735',
      iconUrl: '',
      status: 'ON',
      instructions: "'সেন্ড মানি' দিয়ে পরিশোধ করুন",
    ),
  ];

  // ==========================================
  // PAYMENT METHODS
  // ==========================================

  /// Stream of active payment methods (status == 'ON') for User App
  Stream<List<PaymentMethodModel>> getActivePaymentMethodsStream() {
    return _firestore
        .collection(_paymentMethodsCol)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PaymentMethodModel.fromFirestore(doc))
          .where((item) => item.isActive)
          .toList();

      if (list.isEmpty && snapshot.docs.isEmpty) {
        return defaultPaymentMethods;
      }
      return list;
    });
  }

  /// Stream of all payment methods for Admin
  Stream<List<PaymentMethodModel>> getAllPaymentMethodsStream() {
    return _firestore.collection(_paymentMethodsCol).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return defaultPaymentMethods;
      }
      return snapshot.docs
          .map((doc) => PaymentMethodModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Add new payment method (Admin)
  Future<void> addPaymentMethod({
    required String name,
    required String number,
    String iconUrl = '',
    String status = 'ON',
    String instructions = "'সেন্ড মানি' দিয়ে পরিশোধ করুন",
  }) async {
    final docRef = _firestore.collection(_paymentMethodsCol).doc();
    final trimmedIcon = iconUrl.trim();
    await docRef.set({
      'id': docRef.id,
      'name': name.trim(),
      'number': number.trim(),
      'iconUrl': trimmedIcon,
      'imageUrl': trimmedIcon,
      'logo': trimmedIcon,
      'status': status.toUpperCase(),
      'instructions': instructions.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update payment method (Admin)
  Future<void> updatePaymentMethod({
    required String paymentId,
    required String name,
    required String number,
    String? iconUrl,
    String? status,
    String? instructions,
  }) async {
    final Map<String, dynamic> data = {
      'name': name.trim(),
      'number': number.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (iconUrl != null) {
      final trimmed = iconUrl.trim();
      data['iconUrl'] = trimmed;
      data['imageUrl'] = trimmed;
      data['logo'] = trimmed;
    }
    if (status != null) data['status'] = status.toUpperCase();
    if (instructions != null) data['instructions'] = instructions.trim();

    await _firestore.collection(_paymentMethodsCol).doc(paymentId).set(data, SetOptions(merge: true));
  }

  /// Toggle ON/OFF payment method (Admin)
  Future<void> togglePaymentMethodStatus(String paymentId, bool isCurrentlyOn) async {
    await _firestore.collection(_paymentMethodsCol).doc(paymentId).set({
      'status': isCurrentlyOn ? 'OFF' : 'ON',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete payment method (Admin)
  Future<void> deletePaymentMethod(String paymentId) async {
    await _firestore.collection(_paymentMethodsCol).doc(paymentId).delete();
  }

  // ==========================================
  // RECHARGE PACKAGES
  // ==========================================

  /// Stream of packages for User and Admin
  Stream<List<RechargePackageModel>> getRechargePackagesStream() {
    return _firestore
        .collection(_rechargePackagesCol)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return defaultPackages;
      }
      final list = snapshot.docs
          .map((doc) => RechargePackageModel.fromFirestore(doc))
          .where((p) => p.isActive)
          .toList();

      list.sort((a, b) => a.amount.compareTo(b.amount));
      return list.isNotEmpty ? list : defaultPackages;
    });
  }

  /// Seed initial packages if none exist
  Future<void> seedInitialPackagesIfEmpty() async {
    try {
      final snapshot = await _firestore.collection(_rechargePackagesCol).limit(1).get();
      if (snapshot.docs.isEmpty) {
        for (final pkg in defaultPackages) {
          await _firestore.collection(_rechargePackagesCol).doc(pkg.id).set(pkg.toMap());
        }
      }
      final methodsSnapshot = await _firestore.collection(_paymentMethodsCol).limit(1).get();
      if (methodsSnapshot.docs.isEmpty) {
        for (final method in defaultPaymentMethods) {
          await _firestore.collection(_paymentMethodsCol).doc(method.id).set(method.toMap());
        }
      }
    } catch (e) {
      debugPrint('Error seeding default recharge data: $e');
    }
  }

  // ==========================================
  // RECHARGE ORDERS & TRXID SYSTEM
  // ==========================================

  /// Generate 18-digit unique Order ID like in screenshot
  String generateOrderId() {
    final now = DateTime.now();
    final millis = now.millisecondsSinceEpoch.toString(); // 13 digits
    final rand = (Random().nextInt(90000) + 10000).toString(); // 5 digits
    return '$millis$rand'; // 18 digits total
  }

  /// Check if a Transaction ID (TrxID) is already used across all orders
  Future<bool> isTransactionIdUsed(String transactionId) async {
    final trimmedTrxId = transactionId.trim().toUpperCase();
    if (trimmedTrxId.isEmpty) return false;

    final query = await _firestore
        .collection(_rechargeOrdersCol)
        .where('transactionId', isEqualTo: trimmedTrxId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Submit a new Recharge Order with duplicate TrxID protection
  Future<RechargeOrderModel> submitRechargeOrder({
    required String userId,
    required String userName,
    required String userPhoto,
    String searchId = '',
    String userPhone = '',
    required num amount,
    required int diamondAmount,
    int bonusDiamonds = 0,
    required String paymentMethod,
    required String paymentNumber,
    required String transactionId,
  }) async {
    final trimmedTrxId = transactionId.trim().toUpperCase();
    if (trimmedTrxId.isEmpty) {
      throw Exception('Please enter a valid Transaction ID.');
    }

    // 1. DUPLICATE TRXID PROTECTION
    final isUsed = await isTransactionIdUsed(trimmedTrxId);
    if (isUsed) {
      throw Exception('This transaction ID has already been used.');
    }

    // 2. Generate unique order ID
    final orderId = generateOrderId();

    final order = RechargeOrderModel(
      orderId: orderId,
      userId: userId,
      userName: userName,
      userPhoto: userPhoto,
      searchId: searchId,
      userPhone: userPhone,
      amount: amount,
      diamondAmount: diamondAmount,
      bonusDiamonds: bonusDiamonds,
      paymentMethod: paymentMethod,
      paymentNumber: paymentNumber,
      transactionId: trimmedTrxId,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    // Save to Firestore
    await _firestore
        .collection(_rechargeOrdersCol)
        .doc(orderId)
        .set(order.toMap());

    debugPrint('💰 Recharge order created: $orderId, TrxID: $trimmedTrxId');
    return order;
  }

  /// Stream of user's personal recharge orders
  Stream<List<RechargeOrderModel>> getUserOrdersStream(String userId) {
    return _firestore
        .collection(_rechargeOrdersCol)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RechargeOrderModel.fromFirestore(doc))
          .toList();
      // Sort client-side by createdAt descending to avoid indexing requirement
      list.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(2000);
        final dateB = b.createdAt ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      return list;
    });
  }

  /// Stream of all recharge orders for Admin (with optional status filter)
  Stream<List<RechargeOrderModel>> getAdminOrdersStream({String? statusFilter}) {
    Query query = _firestore.collection(_rechargeOrdersCol);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RechargeOrderModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(2000);
        final dateB = b.createdAt ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      return list;
    });
  }

  // ==========================================
  // ATOMIC DIAMOND CREDIT & APPROVAL
  // ==========================================

  /// Approve recharge request atomically:
  /// 1. Ensures request is in 'Pending' status (prevents double diamond credit).
  /// 2. Updates order status to 'Approved' with timestamps.
  /// 3. Safely increments user's diamonds in Users collection.
  /// 4. Records wallet transaction log.
  Future<bool> approveRechargeOrder({
    required String orderId,
    required String adminId,
  }) async {
    try {
      final orderRef = _firestore.collection(_rechargeOrdersCol).doc(orderId);

      final svipLevelsSnap = await _firestore
          .collection('config')
          .doc('svip_levels')
          .collection('levels')
          .get();
      final List<Map<String, dynamic>> svipLevels = svipLevelsSnap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      String targetUserId = '';
      int creditedDiamonds = 0;
      String targetTrxId = '';

      final success = await _firestore.runTransaction<bool>((transaction) async {
        final orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
          throw Exception('Recharge order not found.');
        }

        final orderData = orderSnap.data() as Map<String, dynamic>;
        final currentStatus = (orderData['status'] ?? '').toString();

        if (currentStatus.toLowerCase() == 'approved') {
          throw Exception('This recharge order has already been approved.');
        }
        if (currentStatus.toLowerCase() == 'rejected') {
          throw Exception('Cannot approve an already rejected order.');
        }

        final userId = orderData['userId'] as String? ?? '';
        final diamondAmount = (orderData['diamondAmount'] as num?)?.toInt() ?? 0;
        final bonusDiamonds = (orderData['bonusDiamonds'] as num?)?.toInt() ?? 0;
        final totalCreditDiamonds = diamondAmount + bonusDiamonds;
        final bdtAmount = orderData['amount'] ?? 0;
        final paymentMethod = orderData['paymentMethod'] ?? 'Online';
        final trxId = orderData['transactionId'] ?? '';

        if (userId.isEmpty || diamondAmount <= 0) {
          throw Exception('Invalid order details.');
        }

        targetUserId = userId;
        creditedDiamonds = totalCreditDiamonds;
        targetTrxId = trxId.toString();

        final userRef = _firestore.collection(_usersCol).doc(userId);
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('User account not found.');
        }

        final userData = userSnap.data() ?? {};
        final lastMonth = userData['lastRechargeMonth'] as String? ?? '';
        final now = DateTime.now();
        final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

        int previousMonthlyRecharge = (userData['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;
        int newMonthlyRecharge = totalCreditDiamonds;

        // 1. Update Order Status
        transaction.update(orderRef, {
          'status': 'Approved',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': adminId,
        });

        // 2. Increment User Diamond Balance & Tracking
        if (lastMonth != currentMonth) {
          transaction.update(userRef, {
            'diamonds': FieldValue.increment(totalCreditDiamonds),
            'totalDiamonds': FieldValue.increment(totalCreditDiamonds),
            'monthlyRechargeAmount': totalCreditDiamonds,
            'eligibleSellerRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'totalEligibleSellerRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'weeklyRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'lastRechargeWeek': getCurrentWeekId(),
            'lastRechargeMonth': currentMonth,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          newMonthlyRecharge = previousMonthlyRecharge + totalCreditDiamonds;
          transaction.update(userRef, {
            'diamonds': FieldValue.increment(totalCreditDiamonds),
            'totalDiamonds': FieldValue.increment(totalCreditDiamonds),
            'monthlyRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'eligibleSellerRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'totalEligibleSellerRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'weeklyRechargeAmount': FieldValue.increment(totalCreditDiamonds),
            'lastRechargeWeek': getCurrentWeekId(),
            'lastRechargeMonth': currentMonth,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Auto upgrade SVIP on online recharge
        await SvipService.checkAndAutoUpgradeSvip(
          userId: userId,
          newRechargeAmount: newMonthlyRecharge,
          currentMonth: currentMonth,
          transaction: transaction,
          userRef: userRef,
          userData: userData,
          svipLevels: svipLevels,
        );

        // 3. Log to wallet_transactions
        final txId = _uuid.v4();
        final txRef = _firestore.collection(_transactionsCol).doc(txId);
        transaction.set(txRef, {
          'id': txId,
          'userId': userId,
          'type': 'online_recharge',
          'diamonds': totalCreditDiamonds,
        'baseDiamonds': diamondAmount,
        'bonusDiamonds': bonusDiamonds,
          'beans': 0,
          'amountBdt': bdtAmount,
          'paymentMethod': paymentMethod,
          'transactionId': trxId,
          'orderId': orderId,
          'description': bonusDiamonds > 0 ? 'Online Diamond Recharge (+$totalCreditDiamonds Diamonds [+$diamondAmount Base ++$bonusDiamonds Bonus] via $paymentMethod)' : 'Online Diamond Recharge (+$diamondAmount Diamonds via $paymentMethod)',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      // Send official admin balance notification
      if (success == true && targetUserId.isNotEmpty && creditedDiamonds > 0) {
        try {
          await OfficialTeamApi.sendAdminBalanceCreditNotification(
            userId: targetUserId,
            amount: creditedDiamonds,
            currency: 'Diamonds',
            note: 'Online Recharge Approved (TrxID: $targetTrxId)',
          );
        } catch (ex) {
          debugPrint('⚠️ Error sending balance notification: $ex');
        }
      }

      return success;
    } catch (e, st) {
      debugPrint('❌ Error in approveRechargeOrder: $e\n$st');
      rethrow;
    }
  }

  /// Reject recharge request
  Future<void> rejectRechargeOrder({
    required String orderId,
    required String adminId,
    String reason = 'Payment verification failed',
  }) async {
    final orderRef = _firestore.collection(_rechargeOrdersCol).doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Recharge order not found.');
    }

    final currentStatus = (orderSnap.data()?['status'] ?? '').toString();
    if (currentStatus.toLowerCase() == 'approved') {
      throw Exception('Cannot reject an order that has already been approved.');
    }

    await orderRef.update({
      'status': 'Rejected',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminId,
      'rejectionReason': reason,
    });
  }

  // ==========================================
  // WEEKLY RECHARGE BENEFITS
  // ==========================================

  static String getCurrentWeekId() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekNum = ((monday.difference(DateTime(monday.year, 1, 1)).inDays) / 7).ceil();
    return '${monday.year}_W$weekNum';
  }

  Stream<List<WeeklyRechargeBenefitModel>> getWeeklyBenefitsStream() {
    return _firestore
        .collection('weekly_recharge_benefits')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return WeeklyRechargeBenefitModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) {
        if (a.targetDiamonds != b.targetDiamonds) {
          return a.targetDiamonds.compareTo(b.targetDiamonds);
        }
        return a.order.compareTo(b.order);
      });
      return list;
    });
  }

  Stream<Set<String>> getClaimedBenefitIdsStream(String userId) {
    if (userId.isEmpty) return Stream.value({});
    final weekId = getCurrentWeekId();
    return _firestore
        .collection('weekly_benefit_claims')
        .where('userId', isEqualTo: userId)
        .where('weekId', isEqualTo: weekId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => (d.data()['benefitId'] ?? '').toString()).toSet());
  }

  Stream<int> getUserWeeklyRechargeStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    return _firestore.collection('Users').doc(userId).snapshots().asyncMap((snap) async {
      if (!snap.exists || snap.data() == null) return 0;
      final data = snap.data()!;
      final weekId = getCurrentWeekId();
      final lastWeek = data['lastRechargeWeek'] as String? ?? '';

      // Direct weekly counter
      int weeklyFromField = (data['weeklyRechargeAmount'] as num?)?.toInt() ?? 0;
      if (lastWeek.isNotEmpty && lastWeek == weekId) {
        weeklyFromField = (data['weeklyRechargeAmount'] as num?)?.toInt() ?? 0;
      }
      // Monthly recharge counter
      final monthly = (data['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;
      // Seller recharge counters
      final sellerRecharge = (data['eligibleSellerRechargeAmount'] as num?)?.toInt() ?? 0;
      final totalSellerRecharge = (data['totalEligibleSellerRechargeAmount'] as num?)?.toInt() ?? 0;
      // Spendable diamonds & total accumulated diamonds
      final userDiamonds = (data['diamonds'] as num?)?.toInt() ?? 0;
      final totalDiamonds = (data['totalDiamonds'] as num?)?.toInt() ?? 0;

      // Query approved recharge orders
      int ordersTotal = 0;
      try {
        final ordersSnap = await _firestore
            .collection('rechargeOrders')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'Approved')
            .get();
        for (final doc in ordersSnap.docs) {
          final oData = doc.data();
          final dia = (oData['diamondAmount'] as num?)?.toInt() ?? 0;
          final bonus = (oData['bonusDiamonds'] as num?)?.toInt() ?? 0;
          ordersTotal += (dia + bonus);
        }
      } catch (e) {
        debugPrint('Error querying recharge orders: $e');
      }

      // Query wallet transactions
      int txTotal = 0;
      try {
        final now = DateTime.now();
        final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final txSnap = await _firestore
            .collection('wallet_transactions')
            .where('userId', isEqualTo: userId)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monday))
            .get();
        for (final doc in txSnap.docs) {
          final tData = doc.data();
          final type = (tData['type'] ?? '').toString();
          if (type == 'online_recharge' || type == 'recharge' || type == 'seller_page') {
            final dia = ((tData['diamonds'] ?? tData['amount']) as num?)?.toInt() ?? 0;
            txTotal += dia;
          }
        }
      } catch (e) {
        debugPrint('Error querying wallet_transactions: $e');
      }

      // Take maximum across all recharge metrics
      int candidate = weeklyFromField;
      if (monthly > candidate) candidate = monthly;
      if (sellerRecharge > candidate) candidate = sellerRecharge;
      if (totalSellerRecharge > candidate) candidate = totalSellerRecharge;
      if (ordersTotal > candidate) candidate = ordersTotal;
      if (txTotal > candidate) candidate = txTotal;

      // Fallback: If user topped up diamonds or tested in Firestore directly
      if (candidate == 0) {
        if (totalDiamonds > 0) {
          candidate = totalDiamonds;
        } else if (userDiamonds > 0) {
          candidate = userDiamonds;
        }
      }

      return candidate;
    });
  }

  Future<bool> claimWeeklyBenefit({
    required String userId,
    required WeeklyRechargeBenefitModel benefit,
  }) async {
    final weekId = getCurrentWeekId();
    final claimDocId = '${userId}_${weekId}_${benefit.id}';
    final claimRef = _firestore.collection('weekly_benefit_claims').doc(claimDocId);

    final claimSnap = await claimRef.get();
    if (claimSnap.exists) {
      throw Exception('Already claimed this week!');
    }

    // 1. Credit Bonus Diamonds if specified
    if (benefit.bonusDiamonds > 0) {
      await _firestore.collection('Users').doc(userId).update({
        'diamonds': FieldValue.increment(benefit.bonusDiamonds),
        'totalDiamonds': FieldValue.increment(benefit.bonusDiamonds),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log to wallet_transactions
      final txId = _uuid.v4();
      await _firestore.collection('wallet_transactions').doc(txId).set({
        'id': txId,
        'userId': userId,
        'type': 'weekly_benefit_bonus',
        'diamonds': benefit.bonusDiamonds,
        'beans': 0,
        'description': 'Weekly Recharge Benefit Diamond Bonus (+${benefit.bonusDiamonds} Diamonds)',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Assign store item to user backpack if item configured
    if (benefit.itemId.isNotEmpty) {
      await StoreService().assignStoreItemToUser(
        userId: userId,
        storeItemId: benefit.itemId,
        expirationDays: benefit.validityDays > 0 ? benefit.validityDays : null,
        assignedBy: 'Weekly Recharge Benefit (${benefit.tierName})',
        assetData: {
          'id': benefit.itemId,
          'name': benefit.itemName,
          'type': benefit.itemType,
          'fileUrl': benefit.itemIcon,
          'thumbnailUrl': benefit.itemIcon,
        },
      );
    }

    // 3. Record claim in weekly_benefit_claims
    await claimRef.set({
      'id': claimDocId,
      'userId': userId,
      'benefitId': benefit.id,
      'weekId': weekId,
      'itemId': benefit.itemId,
      'itemName': benefit.itemName,
      'targetDiamonds': benefit.targetDiamonds,
      'bonusDiamonds': benefit.bonusDiamonds,
      'validityDays': benefit.validityDays,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }
}
