import 'package:flutter/material.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
import 'package:chat_messenger/services/lucky_bag_service.dart';

class LuckyBagResultDialog extends StatelessWidget {
  final String roomId;
  final LuckyBagModel bag;
  final int? currentUserClaimedAmount;

  const LuckyBagResultDialog({
    super.key,
    required this.roomId,
    required this.bag,
    this.currentUserClaimedAmount,
  });

  static void show(
    BuildContext context, {
    required String roomId,
    required LuckyBagModel bag,
    int? currentUserClaimedAmount,
  }) {
    showDialog(
      context: context,
      builder: (context) => LuckyBagResultDialog(
        roomId: roomId,
        bag: bag,
        currentUserClaimedAmount: currentUserClaimedAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Animated Icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF3D00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3D00).withOpacity(0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              '${bag.senderName}\'s Lucky Bag',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),

            if (bag.message != null && bag.message!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '"${bag.message}"',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // If user claimed, show user reward banner
            if (currentUserClaimedAmount != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      ' You Claimed',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$currentUserClaimedAmount 💎',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

            // Summary Info Line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Total Pool', '${bag.totalAmount} 💎'),
                Container(width: 1, height: 24, color: Colors.white12),
                _buildStatItem(
                    'Claimed', '${bag.claimedCount}/${bag.maxWinners}'),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Winners Stream
            SizedBox(
              height: 200,
              child: StreamBuilder<List<LuckyBagClaimModel>>(
                stream: LuckyBagService.streamClaims(roomId, bag.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  }

                  final claims = snapshot.data ?? [];
                  if (claims.isEmpty) {
                    return const Center(
                      child: Text(
                        'No claims yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    );
                  }

                  // Identify Lucky King (highest reward)
                  int maxReward = 0;
                  for (var c in claims) {
                    if (c.rewardAmount > maxReward) maxReward = c.rewardAmount;
                  }

                  return ListView.builder(
                    itemCount: claims.length,
                    itemBuilder: (context, index) {
                      final claim = claims[index];
                      final isKing = claim.rewardAmount == maxReward && maxReward > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isKing
                              ? Colors.amber.withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: isKing
                              ? Border.all(
                                  color: Colors.amber.withOpacity(0.6), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Rank Number / King Icon
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              child: isKing
                                  ? const Text('👑', style: TextStyle(fontSize: 18))
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),

                            // User Avatar / Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        claim.userName,
                                        style: TextStyle(
                                          color: isKing
                                              ? Colors.amberAccent
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: isKing
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      if (isKing) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Lucky King',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Reward Amount
                            Text(
                              '+${claim.rewardAmount} 💎',
                              style: TextStyle(
                                color: isKing
                                    ? Colors.amberAccent
                                    : const Color(0xFF4CAF50),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
