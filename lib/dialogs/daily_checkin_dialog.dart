import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class DailyCheckInDialog extends StatefulWidget {
  final int consecutiveDays;
  final String? lastCheckInDate;

  const DailyCheckInDialog({
    super.key,
    required this.consecutiveDays,
    this.lastCheckInDate,
  });

  @override
  State<DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<DailyCheckInDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSigningIn = false;
  List<Map<String, dynamic>> _rewards = [];
  Map<int, Map<String, dynamic>> _itemDetails = {};
  late int _targetDayIndex;

  @override
  void initState() {
    super.initState();
    _calculateTargetDay();
    _loadRewards();
  }

  void _calculateTargetDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final String yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    if (widget.lastCheckInDate == yesterdayStr) {
      _targetDayIndex = (widget.consecutiveDays % 7) + 1;
    } else {
      _targetDayIndex = 1;
    }
  }

  Future<void> _loadRewards() async {
    try {
      final querySnapshot = await _firestore.collection('daily_checkin_rewards').get();
      List<Map<String, dynamic>> loadedRewards = [];
      
      if (querySnapshot.docs.isEmpty) {
        loadedRewards = [
          {'dayIndex': 1, 'diamonds': 6000},
          {'dayIndex': 2, 'diamonds': 6000},
          {'dayIndex': 3, 'diamonds': 8000},
          {'dayIndex': 4, 'diamonds': 12000},
          {'dayIndex': 5, 'diamonds': 12000},
          {'dayIndex': 6, 'diamonds': 12000},
          {'dayIndex': 7, 'diamonds': 18000},
        ];
      } else {
        loadedRewards = querySnapshot.docs.map((doc) => doc.data()).toList();
      }
      
      loadedRewards.sort((a, b) => (a['dayIndex'] as int).compareTo(b['dayIndex'] as int));

      // Load item details from market_items for any reward that has an itemId
      final Map<int, Map<String, dynamic>> itemDetailsMap = {};
      for (final reward in loadedRewards) {
        final itemId = reward['itemId'] != null ? (reward['itemId'] as num).toInt() : null;
        if (itemId != null) {
          final itemQuery = await _firestore
              .collection('market_items')
              .where('displayId', isEqualTo: itemId)
              .limit(1)
              .get();
          if (itemQuery.docs.isNotEmpty) {
            itemDetailsMap[itemId] = itemQuery.docs.first.data();
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _rewards = loadedRewards;
          _itemDetails = itemDetailsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      final String userId = AuthController.instance.currentUser.userId;
      final String todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final reward = _rewards.firstWhere(
        (r) => r['dayIndex'] == _targetDayIndex,
        orElse: () => {'diamonds': 6000},
      );
      final int diamondsReward = reward['diamonds'] != null ? (reward['diamonds'] as num).toInt() : 0;

      await _firestore.collection('Users').doc(userId).update({
        'lastCheckInDate': todayStr,
        'consecutiveDays': _targetDayIndex,
      });

      if (diamondsReward > 0) {
        await UserApi.updateDiamonds(userId, diamondsReward);
      }

      String? rewardItemName;
      String? rewardItemImageUrl;
      if (reward['itemId'] != null) {
        final int itemId = (reward['itemId'] as num).toInt();
        final int durationDays = (reward['itemDuration'] as num?)?.toInt() ?? 1;

        // Query the item from market_items using displayId
        final itemQuery = await _firestore
            .collection('market_items')
            .where('displayId', isEqualTo: itemId)
            .limit(1)
            .get();

        if (itemQuery.docs.isNotEmpty) {
          final doc = itemQuery.docs.first;
          final String storeItemId = doc.id;
          final String itemName = doc.data()['name'] ?? '';
          final String itemType = doc.data()['type'] ?? '';
          rewardItemName = "$itemName ($durationDays Days)";
          rewardItemImageUrl = doc.data()['thumbnailUrl'] as String? ?? doc.data()['fileUrl'] as String? ?? '';

          // 1. Check if user already has this item in user_store_items
          final existingQuery = await _firestore
              .collection('user_store_items')
              .where('userId', isEqualTo: userId)
              .where('storeItemId', isEqualTo: storeItemId)
              .limit(1)
              .get();

          DateTime expiresAt;
          String userStoreItemId;

          if (existingQuery.docs.isNotEmpty) {
            final existingDoc = existingQuery.docs.first;
            final existingData = existingDoc.data();
            final currentExpiry = (existingData['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final baseDate = currentExpiry.isAfter(DateTime.now()) ? currentExpiry : DateTime.now();
            expiresAt = baseDate.add(Duration(days: durationDays));
            userStoreItemId = existingDoc.id;

            await _firestore.collection('user_store_items').doc(userStoreItemId).update({
              'expiresAt': Timestamp.fromDate(expiresAt),
              'isActive': true,
              'assignedAt': FieldValue.serverTimestamp(),
              'assignedBy': 'daily_checkin',
            });
          } else {
            expiresAt = DateTime.now().add(Duration(days: durationDays));
            userStoreItemId = _firestore.collection('user_store_items').doc().id;

            await _firestore.collection('user_store_items').doc(userStoreItemId).set({
              'id': userStoreItemId,
              'userId': userId,
              'storeItemId': storeItemId,
              'storeItemName': itemName,
              'itemType': itemType,
              'assignedAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(expiresAt),
              'isActive': true,
              'assignedBy': 'daily_checkin',
            });
          }

          // 2. Update user's customization (badge, frame, entry effect, room theme, etc.)
          final userDoc = await _firestore.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final customizationMap = userData['customization'] as Map<String, dynamic>? ?? {};

            List<String> ownedList = [];
            String selectedField = '';
            String ownedField = '';

            if (itemType == 'badge') {
              ownedField = 'ownedBadges';
              selectedField = 'selectedBadgeId';
            } else if (itemType == 'avatarFrame') {
              ownedField = 'ownedFrames';
              selectedField = 'selectedFrameId';
            } else if (itemType == 'entryEffect') {
              ownedField = 'ownedEntryEffects';
              selectedField = 'selectedEntryEffectId';
            } else if (itemType == 'backgroundTheme' || itemType == 'profileSkin') {
              ownedField = 'ownedBackgroundThemes';
              selectedField = 'selectedBackgroundThemeId';
            } else if (itemType == 'nameplate') {
              ownedField = 'ownedNameplates';
              selectedField = 'selectedNameplateId';
            } else if (itemType == 'roomTheme') {
              ownedField = 'ownedRoomThemes';
              selectedField = 'selectedRoomThemeId';
            }

            if (ownedField.isNotEmpty) {
              ownedList = List<String>.from(customizationMap[ownedField] ?? []);
              if (!ownedList.contains(storeItemId)) {
                ownedList.add(storeItemId);
              }
              customizationMap[ownedField] = ownedList;
              if (selectedField.isNotEmpty) {
                customizationMap[selectedField] = storeItemId;
              }

              await _firestore.collection('Users').doc(userId).update({
                'customization': customizationMap,
              });
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showRewardReceivedDialog(diamondsReward, rewardItemName, rewardItemImageUrl);

        // Send Notification Channel Message
        String msg = "🎉 Congratulations! You received ";
        if (diamondsReward > 0) {
          msg += "$diamondsReward Diamonds";
        }
        if (rewardItemName != null) {
          if (diamondsReward > 0) msg += " and ";
          msg += rewardItemName;
        }
        msg += " from Daily Check-in.";

        final user = AuthController.instance.currentUser;
        OfficialTeamApi.sendOfficialMessage(
          receiverId: user.userId,
          receiverDeviceToken: user.deviceToken,
          messageText: msg,
        );
      }
    } catch (e) {
      debugPrint('Error during sign in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  void _showRewardReceivedDialog(int amount, String? itemName, String? itemImageUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RewardReceivedDialog(
        amount: amount,
        itemName: itemName,
        itemImageUrl: itemImageUrl,
      ),
    );
  }

  Widget _buildItemImage(int itemId, {double size = 28}) {
    final itemData = _itemDetails[itemId];
    final imageUrl = itemData != null
        ? (itemData['thumbnailUrl'] as String? ?? itemData['fileUrl'] as String? ?? '')
        : '';
    final hasImage = imageUrl.isNotEmpty && !imageUrl.endsWith('.svga');
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.card_giftcard,
            color: Colors.greenAccent,
            size: size,
          ),
        ),
      );
    }
    return Icon(
      Icons.card_giftcard,
      color: Colors.greenAccent,
      size: size,
    );
  }

  Widget _buildDayCard(int dayIndex, {bool isBigReward = false}) {
    final isCurrent = dayIndex == _targetDayIndex;
    final reward = _rewards.firstWhere(
      (r) => r['dayIndex'] == dayIndex,
      orElse: () => {'diamonds': 6000},
    );
    final int diamonds = reward['diamonds'] != null ? (reward['diamonds'] as num).toInt() : 0;
    final int? itemId = reward['itemId'] != null ? (reward['itemId'] as num).toInt() : null;
    final int? itemDuration = reward['itemDuration'] != null ? (reward['itemDuration'] as num).toInt() : null;

    if (isBigReward) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF2E2C3C) : const Color(0xFF232130),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? const Color(0xFF1DE9B6) : Colors.white.withValues(alpha: 0.05),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '7 Big Reward',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (diamonds > 0) ...[
                        DynamicDiamondIcon(width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.diamond,
                            color: Colors.cyanAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$diamonds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (itemId != null) ...[
                        if (diamonds > 0) const SizedBox(width: 12),
                        _buildItemImage(itemId, size: 32),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _itemDetails[itemId] != null
                                ? (diamonds > 0
                                    ? '+ ${_itemDetails[itemId]!['name']} ($itemDuration Days)'
                                    : '${_itemDetails[itemId]!['name']} ($itemDuration Days)')
                                : (diamonds > 0 ? '+ Item ($itemDuration Days)' : 'Item ($itemDuration Days)'),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 28),
                if (itemId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard, color: Colors.orangeAccent, size: 24),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF2E2C3C) : const Color(0xFF232130),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFF1DE9B6) : Colors.white.withValues(alpha: 0.05),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF1DE9B6) : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$dayIndex',
              style: TextStyle(
                color: isCurrent ? Colors.black : Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (diamonds > 0) ...[
            DynamicDiamondIcon(width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.diamond,
                color: Colors.cyanAccent,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$diamonds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (itemId != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildItemImage(itemId, size: 14),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        _itemDetails[itemId] != null
                            ? '${_itemDetails[itemId]!['name']} (${itemDuration}d)'
                            : 'Item ${itemDuration}d',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (itemId != null) ...[
            _buildItemImage(itemId, size: 28),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                _itemDetails[itemId] != null
                    ? '${_itemDetails[itemId]!['name']} (${itemDuration}d)'
                    : 'Item ${itemDuration}d',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Illustration & Title
            Stack(
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1DE9B6), Color(0xFF00BFA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month, color: Colors.white, size: 36),
                      SizedBox(height: 6),
                      Text(
                        'Daily Reward',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sign in for 7 days for rich rewards',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            
            // Cards Grid Layout
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Row 1: Days 1, 2, 3, 4
                  Row(
                    children: [
                      Expanded(child: _buildDayCard(1)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDayCard(2)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDayCard(3)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDayCard(4)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 2: Days 5, 6
                  Row(
                    children: [
                      Expanded(child: _buildDayCard(5)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDayCard(6)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 3: Day 7 Big Reward
                  _buildDayCard(7, isBigReward: true),
                ],
              ),
            ),
            
            // Sign In Button
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 4),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSigningIn ? null : _performSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DE9B6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 3,
                  ),
                  child: _isSigningIn
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardReceivedDialog extends StatelessWidget {
  final int amount;
  final String? itemName;
  final String? itemImageUrl;

  const _RewardReceivedDialog({
    required this.amount,
    this.itemName,
    this.itemImageUrl,
  });

  Widget _buildReceivedItemImage(String? imageUrl, {double size = 60}) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty && !imageUrl.endsWith('.svga');
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.card_giftcard,
            color: Colors.greenAccent,
            size: size,
          ),
        ),
      );
    }
    return Icon(
      Icons.card_giftcard,
      color: Colors.greenAccent,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Get Reward',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (amount > 0)
                  DynamicDiamondIcon(width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.diamond,
                      color: Color(0xFFFFD700),
                      size: 60,
                    ),
                  ),
                if (amount > 0 && itemName != null) ...[
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                ],
                if (itemName != null)
                  _buildReceivedItemImage(itemImageUrl, size: 60),
              ],
            ),
            const SizedBox(height: 16),
            if (amount > 0)
              Text(
                '$amount Diamonds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (itemName != null) ...[
              const SizedBox(height: 8),
              Text(
                itemName!,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
