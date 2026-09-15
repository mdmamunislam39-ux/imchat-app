import 'package:flutter/material.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_selection_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_result_dialog.dart';

/// Reward Claim Result Dialog (Matching Screenshot 3)
class LuckyBagClaimResultDialog extends StatelessWidget {
  final String roomId;
  final LuckyBagModel bag;
  final int rewardAmount;
  final String currentUserId;
  final String currentUserName;

  const LuckyBagClaimResultDialog({
    super.key,
    required this.roomId,
    required this.bag,
    required this.rewardAmount,
    required this.currentUserId,
    required this.currentUserName,
  });

  static void show(
    BuildContext context, {
    required String roomId,
    required LuckyBagModel bag,
    required int rewardAmount,
    required String currentUserId,
    required String currentUserName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LuckyBagClaimResultDialog(
        roomId: roomId,
        bag: bag,
        rewardAmount: rewardAmount,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF0), // Light cream inner card
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFF2A55), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Pink Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF3366), Color(0xFFFF1744)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Text(
                    'You got',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3D Gold/Diamond Stack Illustration
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFFDF0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: DynamicDiamondIcon(width: 50, height: 50),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reward Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$rewardAmount',
                        style: const TextStyle(
                          color: Color(0xFF7A301E),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const DynamicDiamondIcon(width: 24, height: 24),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Pink Container with Gift Back Button & Details Link
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2A55), Color(0xFFFF1744)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // "Gift Back" Golden Button (Matching Screenshot 3)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close claim result
                        // Open GiftSelectionBottomSheet pre-targeting sender
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (ctx) => GiftSelectionBottomSheet(
                            roomId: roomId,
                            senderId: currentUserId,
                            senderName: currentUserName,
                            receiverId: bag.senderId,
                            receiverName: bag.senderName,
                            receiverImageUrl: bag.senderAvatar,
                            participants: const [],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 4,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFC107), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Gift Back',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.card_giftcard_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  const Text(
                    'Send a gift back to say thanks',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Inter',
                    ),
                  ),

                  const SizedBox(height: 12),

                  // "Check details >" Link
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close claim dialog
                      // Open full ranking list & Lucky King dialog
                      LuckyBagResultDialog.show(
                        context,
                        roomId: roomId,
                        bag: bag,
                        currentUserClaimedAmount: rewardAmount,
                      );
                    },
                    child: const Text(
                      'Check details >',
                      style: TextStyle(
                        color: Color(0xFFFFEEB3),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
