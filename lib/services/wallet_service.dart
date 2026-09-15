import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'gift_economy_service.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'level_service.dart';

/// Service for managing user wallet operations
class WalletService {
  static const String _usersCollection = 'Users';
  static const String _transactionsCollection = 'wallet_transactions';
  static const String _storeItemsCollection = 'market_items';
  static const String _userStoreItemsCollection = 'user_store_items';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Get user wallet data
  Future<User?> getUserWallet(String userId) async {
    try {
      debugPrint('💰 WalletService: Fetching user wallet data for $userId');
      final doc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('💰 WalletService: Retrieved user wallet data');
        return User.fromMap(data);
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error fetching user wallet: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch user wallet: $e');
    }
  }

  /// Update user balance
  Future<bool> updateUserBalance({
    required String userId,
    int? diamonds,
    int? beans,
    String? transactionType,
    String? description,
  }) async {
    try {
      debugPrint('💰 WalletService: Updating user balance for $userId');

      final Map<String, dynamic> updateData = {};

      if (diamonds != null) {
        updateData['diamonds'] = FieldValue.increment(diamonds);
      }
      if (beans != null) {
        updateData['beans'] = FieldValue.increment(beans);
      }

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updateData);

      // Record transaction if provided
      if (transactionType != null) {
        await _recordTransaction(
          userId: userId,
          type: transactionType,
          diamonds: diamonds,
          beans: beans,
          description: description,
        );
      }

      debugPrint('💰 WalletService: Successfully updated user balance');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error updating user balance: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to update user balance: $e');
    }
  }

  /// Deduct diamonds safely in a Firestore transaction.
  Future<bool> deductDiamondsSafely({
    required String userId,
    required int amount,
    String? transactionType,
    String? description,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive', 'amount');
    }

    try {
      final userRef = _firestore.collection(_usersCollection).doc(userId);
      final result = await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          throw Exception('User not found');
        }

        final currentDiamonds = (snapshot.data()!['diamonds'] ?? 0) as int;
        if (currentDiamonds < amount) {
          return false;
        }

        transaction.update(userRef, {
          'diamonds': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (transactionType != null) {
          final transactionId = _uuid.v4();
          transaction.set(
            _firestore.collection(_transactionsCollection).doc(transactionId),
            {
              'id': transactionId,
              'userId': userId,
              'type': transactionType,
              'diamonds': -amount,
              'beans': 0,
              'description': description ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }

        return true;
      });

      debugPrint('💰 WalletService: Safely deducted $amount diamonds for $userId');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error deducting diamonds safely: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to deduct diamonds safely: $e');
    }
  }

  /// Record a wallet transaction
  Future<void> _recordTransaction({
    required String userId,
    required String type,
    int? diamonds,
    int? beans,
    String? description,
  }) async {
    try {
      final transactionId = _uuid.v4();
      final transactionData = {
        'id': transactionId,
        'userId': userId,
        'type': type,
        'diamonds': diamonds ?? 0,
        'beans': beans ?? 0,
        'description': description ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .set(transactionData);

      debugPrint('💰 WalletService: Recorded transaction $transactionId');
    } catch (e) {
      debugPrint('❌ WalletService: Error recording transaction: $e');
    }
  }

  /// Get user transaction history
  Future<List<Map<String, dynamic>>> getUserTransactions(String userId) async {
    try {
      debugPrint('💰 WalletService: Fetching transaction history for $userId');
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final transactions = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      debugPrint(
          '💰 WalletService: Retrieved ${transactions.length} transactions');
      return transactions;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error fetching transactions: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Purchase store item
  Future<bool> purchaseStoreItem({
    int? validityDays,
    required String userId,
    required String storeItemId,
    required int cost,
    String currencyType = 'diamonds',
    String? description,
  }) async {
    try {
      debugPrint(
          '💰 WalletService: Purchasing store item $storeItemId for user $userId using $currencyType');

      // Check if user has enough balance
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final currentBalance = userData[currencyType] ?? 0;

      if (currentBalance < cost) {
        throw Exception('Insufficient $currencyType');
      }
      // Get store item details
      var storeItemDoc = await _firestore
          .collection(_storeItemsCollection)
          .doc(storeItemId)
          .get();
      
      final Map<String, dynamic> storeItemData;
      if (storeItemDoc.exists) {
        storeItemData = storeItemDoc.data()!;
      } else {
        // Fallback to legacy store_items collection
        storeItemDoc = await _firestore
            .collection('store_items')
            .doc(storeItemId)
            .get();
        if (storeItemDoc.exists) {
          storeItemData = storeItemDoc.data()!;
        } else {
          throw Exception('Store item not found');
        }
      }

      // Start transaction
      await _firestore.runTransaction((transaction) async {
        // Deduct balance
        transaction.update(
          _firestore.collection(_usersCollection).doc(userId),
          {
            currencyType: FieldValue.increment(-cost),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        final rawUrl = storeItemData['imageUrl'] ??
            storeItemData['thumbnailUrl'] ??
            storeItemData['fileUrl'] ??
            storeItemData['image'] ??
            '';
        final String resolvedType = (storeItemData['type'] ?? storeItemData['category'] ?? 'avatarFrame').toString();
        final int starRating = (storeItemData['starRating'] ?? storeItemData['stars'] ?? 1) is num
            ? (storeItemData['starRating'] ?? storeItemData['stars'] ?? 1).toInt()
            : 1;

        // Add item to user's collection
        final userStoreItemId = _uuid.v4();
        transaction.set(
          _firestore.collection(_userStoreItemsCollection).doc(userStoreItemId),
          {
            'id': userStoreItemId,
            'userId': userId,
            'storeItemId': storeItemId,
            'storeItemName': storeItemData['name'] ?? storeItemData['title'] ?? 'Item',
            'itemType': resolvedType,
            'imageUrl': rawUrl,
            'fileUrl': storeItemData['fileUrl'] ?? rawUrl,
            'thumbnailUrl': storeItemData['thumbnailUrl'] ?? rawUrl,
            'starRating': starRating,
            'description': storeItemData['description'] ?? '',
            'badgeSubCategory': storeItemData['badgeSubCategory'] ?? storeItemData['subCategory'] ?? 'Verification',
            'assignedAt': FieldValue.serverTimestamp(),
            'expiresAt': ((validityDays ?? storeItemData['expirationDuration']) != null && (validityDays ?? storeItemData['expirationDuration']) > 0)
                ? Timestamp.fromDate(DateTime.now()
                    .add(Duration(days: validityDays ?? storeItemData['expirationDuration'])))
                : null,
            'isActive': true,
            'assignedBy': 'user_purchase',
          },
        );

        if (resolvedType == 'badge') {
          transaction.update(
            _firestore.collection(_usersCollection).doc(userId),
            {
              'customization.ownedBadges': FieldValue.arrayUnion([storeItemId]),
            },
          );
        }

        // Record transaction
        transaction.set(
          _firestore.collection(_transactionsCollection).doc(_uuid.v4()),
          {
            'id': _uuid.v4(),
            'userId': userId,
            'type': 'purchase',
            'diamonds': -cost,
            'beans': 0,
            'description': description ?? 'Purchased ${storeItemData['name']}',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      // Send official notification message
      try {
        final receiver = User.fromMap(userData);
        final String rewardName = storeItemData['name'] ?? 'Unknown Item';
        final String itemType = storeItemData['type'] ?? '';
        final bool isBadge = itemType == 'badge';
        await OfficialTeamApi.sendRewardMessage(receiver, rewardName, isBadge: isBadge);
      } catch (ex) {
        debugPrint('Error sending official purchase notification: $ex');
      }

      debugPrint('💰 WalletService: Successfully purchased store item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error purchasing store item: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to purchase store item: $e');
    }
  }

  /// Gift store item to another user
  Future<bool> giftStoreItem({
    int? validityDays,
    required String senderId,
    required String receiverId,
    required String storeItemId,
    required int cost,
    String currencyType = 'diamonds',
    String? description,
  }) async {
    try {
      debugPrint('💰 WalletService: Gifting store item $storeItemId from $senderId to $receiverId using $currencyType');

      // Check if sender has enough balance
      final senderDoc = await _firestore.collection(_usersCollection).doc(senderId).get();
      if (!senderDoc.exists) throw Exception('Sender not found');
      
      final receiverDoc = await _firestore.collection(_usersCollection).doc(receiverId).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');

      final senderData = senderDoc.data()!;
      final currentBalance = senderData[currencyType] ?? 0;

      if (currentBalance < cost) {
        throw Exception('Insufficient $currencyType');
      }

      // Get store item details
      final storeItemDoc = await _firestore.collection(_storeItemsCollection).doc(storeItemId).get();
      if (!storeItemDoc.exists) throw Exception('Store item not found');

      final storeItemData = storeItemDoc.data()!;

      // Start transaction
      await _firestore.runTransaction((transaction) async {
        // Deduct balance from sender
        transaction.update(
          _firestore.collection(_usersCollection).doc(senderId),
          {
            currencyType: FieldValue.increment(-cost),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        final rawUrl = storeItemData['imageUrl'] ??
            storeItemData['thumbnailUrl'] ??
            storeItemData['fileUrl'] ??
            storeItemData['image'] ??
            '';
        final String resolvedType = (storeItemData['type'] ?? storeItemData['category'] ?? 'avatarFrame').toString();
        final int starRating = (storeItemData['starRating'] ?? storeItemData['stars'] ?? 1) is num
            ? (storeItemData['starRating'] ?? storeItemData['stars'] ?? 1).toInt()
            : 1;

        // Add item to receiver's collection
        final userStoreItemId = _uuid.v4();
        transaction.set(
          _firestore.collection(_userStoreItemsCollection).doc(userStoreItemId),
          {
            'id': userStoreItemId,
            'userId': receiverId,
            'storeItemId': storeItemId,
            'storeItemName': storeItemData['name'] ?? storeItemData['title'] ?? 'Item',
            'itemType': resolvedType,
            'imageUrl': rawUrl,
            'fileUrl': storeItemData['fileUrl'] ?? rawUrl,
            'thumbnailUrl': storeItemData['thumbnailUrl'] ?? rawUrl,
            'starRating': starRating,
            'description': storeItemData['description'] ?? '',
            'badgeSubCategory': storeItemData['badgeSubCategory'] ?? storeItemData['subCategory'] ?? 'Verification',
            'assignedAt': FieldValue.serverTimestamp(),
            'expiresAt': ((validityDays ?? storeItemData['expirationDuration']) != null && (validityDays ?? storeItemData['expirationDuration']) > 0) ? Timestamp.fromDate(DateTime.now().add(Duration(days: validityDays ?? storeItemData['expirationDuration']))) : null,
            'isActive': true,
            'assignedBy': 'gift_from_$senderId',
          },
        );

        if (resolvedType == 'badge') {
          transaction.update(
            _firestore.collection(_usersCollection).doc(receiverId),
            {
              'customization.ownedBadges': FieldValue.arrayUnion([storeItemId]),
            },
          );
        }

        // Record transaction for sender
        transaction.set(
          _firestore.collection(_transactionsCollection).doc(_uuid.v4()),
          {
            'id': _uuid.v4(),
            'userId': senderId,
            'type': 'gift_send',
            'diamonds': -cost,
            'beans': 0,
            'description': description ?? 'Gifted ${storeItemData['name']}',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      // Send official notification message to receiver
      try {
        final receiver = User.fromMap(receiverDoc.data()!);
        final String rewardName = storeItemData['name'] ?? 'Unknown Item';
        final String itemType = storeItemData['type'] ?? '';
        final bool isBadge = itemType == 'badge';
        await OfficialTeamApi.sendRewardMessage(receiver, rewardName, isBadge: isBadge);
      } catch (ex) {
        debugPrint('Error sending official gift notification: $ex');
      }

      debugPrint('💰 WalletService: Successfully gifted store item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error gifting store item: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to gift store item: $e');
    }
  }

  /// Get user's owned store items
  Future<List<Map<String, dynamic>>> getUserStoreItems(String userId) async {
    try {
      debugPrint('💰 WalletService: Fetching user store items for $userId');
      final snapshot = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('assignedAt', descending: true)
          .get();

      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      debugPrint('💰 WalletService: Retrieved ${items.length} store items');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error fetching user store items: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch user store items: $e');
    }
  }

  /// Exchange beans for diamonds using dynamic rate from platform config.
  Future<bool> exchangeBeansForDiamonds({
    required String userId,
    required int beansToExchange,
    required int exchangeRate, // beans per diamond
  }) async {
    try {
      debugPrint(
          '💰 WalletService: Exchanging $beansToExchange beans for diamonds');

      // Check if user has enough beans
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final currentBeans = userData['beans'] ?? 0;
      final username = userData['username'] ?? '';

      if (currentBeans < beansToExchange) {
        throw Exception('Insufficient beans');
      }

      final diamondsToReceive = (beansToExchange / exchangeRate).floor();

      if (diamondsToReceive <= 0) {
        throw Exception('Exchange rate too low');
      }

      // Read beanToDiamondRate from config
      final config = await GiftEconomyService.instance.getConfig();
      final beanToDiamondRate =
          (config['beanToDiamondRate'] as num?)?.toDouble() ?? 1.0;

      // Start transaction
      await _firestore.runTransaction((transaction) async {
        // Update balances
        transaction.update(
          _firestore.collection(_usersCollection).doc(userId),
          {
            'beans': FieldValue.increment(-beansToExchange),
            'diamonds': FieldValue.increment(diamondsToReceive),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // Record wallet transaction (backwards compatibility)
        final walletTxId = _uuid.v4();
        transaction.set(
          _firestore.collection(_transactionsCollection).doc(walletTxId),
          {
            'id': walletTxId,
            'userId': userId,
            'type': 'exchange',
            'diamonds': diamondsToReceive,
            'beans': -beansToExchange,
            'description':
                'Exchanged $beansToExchange beans for $diamondsToReceive diamonds',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        // Record bean_conversions doc
        final conversionId = _uuid.v4();
        transaction.set(
          _firestore.collection('bean_conversions').doc(conversionId),
          {
            'id': conversionId,
            'userId': userId,
            'username': username,
            'beansSpent': beansToExchange,
            'diamondsReceived': diamondsToReceive,
            'exchangeRate': exchangeRate,
            'beanToDiamondRate': beanToDiamondRate,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('💰 WalletService: Successfully exchanged beans for diamonds');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error exchanging beans: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to exchange beans: $e');
    }
  }

  /// Exchange a specific package of beans for diamonds (supports custom package rates & bonuses).
  Future<bool> exchangeBeansForDiamondsPackage({
    required String userId,
    required int beansSpent,
    required int diamondsReceived,
  }) async {
    try {
      debugPrint(
          '💰 WalletService: Exchanging package of $beansSpent beans for $diamondsReceived diamonds');

      // Check if user has enough beans
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final currentBeans = userData['beans'] ?? 0;
      final username = userData['username'] ?? '';

      if (currentBeans < beansSpent) {
        throw Exception('Insufficient beans');
      }

      // Start transaction
      await _firestore.runTransaction((transaction) async {
        // Update balances
        transaction.update(
          _firestore.collection(_usersCollection).doc(userId),
          {
            'beans': FieldValue.increment(-beansSpent),
            'diamonds': FieldValue.increment(diamondsReceived),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // Record wallet transaction (backwards compatibility)
        final walletTxId = _uuid.v4();
        transaction.set(
          _firestore.collection(_transactionsCollection).doc(walletTxId),
          {
            'id': walletTxId,
            'userId': userId,
            'type': 'exchange',
            'diamonds': diamondsReceived,
            'beans': -beansSpent,
            'description':
                'Exchanged package of $beansSpent beans for $diamondsReceived diamonds',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        // Record bean_conversions doc
        final conversionId = _uuid.v4();
        transaction.set(
          _firestore.collection('bean_conversions').doc(conversionId),
          {
            'id': conversionId,
            'userId': userId,
            'username': username,
            'beansSpent': beansSpent,
            'diamondsReceived': diamondsReceived,
            'exchangeRate': 100, // standard relative representation
            'beanToDiamondRate': diamondsReceived / beansSpent,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      debugPrint('💰 WalletService: Successfully exchanged package beans for diamonds');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error exchanging package beans: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to exchange package beans: $e');
    }
  }

  Future<bool> updateUserLevel({
    required String userId,
    required String levelType, // 'sending' or 'receiving'
    required int progressGained,
  }) async {
    try {
      debugPrint(
          '💰 WalletService: Updating $levelType level for user $userId via LevelService');

      if (levelType == 'sending') {
        await LevelService().updateSendingLevel(userId, progressGained);
      } else {
        await LevelService().updateReceivingLevel(userId, progressGained);
      }

      debugPrint('💰 WalletService: Successfully updated user level');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error updating user level: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to update user level: $e');
    }
  }

  /// Get level name based on level number


  /// Get available store items
  Future<List<Map<String, dynamic>>> getStoreItems({
    String? type,
    String? category,
  }) async {
    try {
      debugPrint('💰 WalletService: Fetching store items');

      Query query = _firestore.collection(_storeItemsCollection);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.where('isActive', isEqualTo: true);

      final snapshot = await query.orderBy('createdAt', descending: true).get();

      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      debugPrint('💰 WalletService: Retrieved ${items.length} store items');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ WalletService: Error fetching store items: $e');
      debugPrint('❌ WalletService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store items: $e');
    }
  }
}

