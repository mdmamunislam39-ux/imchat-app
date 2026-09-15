import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
import 'package:chat_messenger/services/lucky_bag_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_claim_result_dialog.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_result_dialog.dart';

/// Large 3D Red Packet Overlay Dialog with Countdown -> "Open" transition
class LuckyBagBigPacketDialog extends StatefulWidget {
  final String roomId;
  final LuckyBagModel bag;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatar;

  const LuckyBagBigPacketDialog({
    super.key,
    required this.roomId,
    required this.bag,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatar,
  });

  static void show(
    BuildContext context, {
    required String roomId,
    required LuckyBagModel bag,
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LuckyBagBigPacketDialog(
        roomId: roomId,
        bag: bag,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
      ),
    );
  }

  @override
  State<LuckyBagBigPacketDialog> createState() => _LuckyBagBigPacketDialogState();
}

class _LuckyBagBigPacketDialogState extends State<LuckyBagBigPacketDialog> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = widget.bag.secondsUntilUnlock;

    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final currentDiff = widget.bag.secondsUntilUnlock;
        setState(() {
          _secondsLeft = currentDiff;
        });
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _handleOpen() async {
    if (_isClaiming) return;

    // Check if user already claimed
    final alreadyClaimed = await LuckyBagService.hasUserClaimed(
      roomId: widget.roomId,
      bagId: widget.bag.id,
      userId: widget.currentUserId,
    );

    if (alreadyClaimed) {
      if (mounted) {
        Navigator.pop(context);
        LuckyBagResultDialog.show(
          context,
          roomId: widget.roomId,
          bag: widget.bag,
        );
      }
      return;
    }

    setState(() {
      _isClaiming = true;
    });

    try {
      final reward = await LuckyBagService.claimLuckyBag(
        roomId: widget.roomId,
        bagId: widget.bag.id,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userAvatar: widget.currentUserAvatar,
      );

      if (mounted) {
        Navigator.pop(context); // Close Big Packet Dialog
        // Open Reward Result Dialog (Matching Screenshot 3)
        LuckyBagClaimResultDialog.show(
          context,
          roomId: widget.roomId,
          bag: widget.bag,
          rewardAmount: reward,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canOpen = widget.bag.isUnlocked || _secondsLeft <= 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Large 3D Red Packet Container (Matching Screenshot 1 & 2)
          Container(
            width: 310,
            height: 380,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3B6B), Color(0xFFFF1744)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: const Color(0xFFFFD54F),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top Arc Curve Line Decoration
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 180,
                  child: CustomPaint(
                    painter: _RedPacketEnvelopeArcPainter(),
                  ),
                ),

                // Center Action Button (Golden Circle)
                // Timer > 0s: Displays "59s"
                // Timer == 0s: Displays "Open"
                Positioned(
                  child: GestureDetector(
                    onTap: canOpen ? _handleOpen : null,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: Colors.white,
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isClaiming
                            ? const CircularProgressIndicator(
                                color: Color(0xFFD81B60),
                                strokeWidth: 3,
                              )
                            : Text(
                                canOpen ? 'Open' : '${_secondsLeft}s',
                                style: TextStyle(
                                  color: const Color(0xFF8C1D00),
                                  fontSize: canOpen ? 28 : 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the red envelope arc band across the middle
class _RedPacketEnvelopeArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF8A80).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 0.9,
        size.width,
        size.height * 0.6,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
