import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/lucky_bag_service.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/room/wallet_screen.dart';

class CreateLuckyBagBottomSheet extends StatefulWidget {
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;

  const CreateLuckyBagBottomSheet({
    super.key,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
  });

  static void show(
    BuildContext context, {
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateLuckyBagBottomSheet(
          roomId: roomId,
          senderId: senderId,
          senderName: senderName,
          senderAvatar: senderAvatar,
        ),
      ),
    );
  }

  @override
  State<CreateLuckyBagBottomSheet> createState() =>
      _CreateLuckyBagBottomSheetState();
}

class _CreateLuckyBagBottomSheetState
    extends State<CreateLuckyBagBottomSheet> {
  // Selected values (Single Currency: Diamonds)
  int _selectedAmount = 1000;
  int _selectedWinners = 10;
  String _distributionMethod = 'Random'; // 'Random' or 'Average'
  int _selectedCountdown = 60; // 30, 60, 90, 120

  bool _isCustomAmount = false;
  bool _isCustomWinners = false;
  bool _isSubmitting = false;

  final List<int> _presetAmounts = [1000, 5000, 10000];
  final List<int> _presetWinners = [10, 20, 50];
  final List<int> _presetCountdowns = [30, 60, 90, 120];

  void _showCustomInputDialog({
    required String title,
    required String hint,
    required int initialValue,
    required ValueChanged<int> onSubmitted,
  }) {
    final controller = TextEditingController(text: initialValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF7A301E),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF7A301E), fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFFFEEC9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                onSubmitted(val);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2A55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3366), Color(0xFFFF1744)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Title and Close X
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    const Text(
                      'Rules',
                      style: TextStyle(
                        color: Color(0xFFFFEEB3),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Light Cream Content Card
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF0),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _RuleText(
                      number: '1.',
                      text:
                          'You can set all the options for the lucky bag then send it. Other users will receive the broadcast notification and can enter your room.',
                    ),
                    SizedBox(height: 14),
                    _RuleText(
                      number: '2.',
                      text:
                          'After the countdown ends, users in the room can claim a random amount of diamonds until all are claimed.',
                    ),
                    SizedBox(height: 14),
                    _RuleText(
                      number: '3.',
                      text:
                          'If the lucky bag expires with unclaimed diamonds, the remaining amount will be returned to your wallet.',
                    ),
                    SizedBox(height: 14),
                    _RuleText(
                      number: '4.',
                      text:
                          'Lucky bag cannot be sent in locked rooms, and only one lucky bag can be sent in the room at the same time.',
                    ),
                    SizedBox(height: 14),
                    _RuleText(
                      number: '5.',
                      text: 'The final right of interpretation belongs to ImChat.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    if (_selectedAmount <= 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await LuckyBagService.createLuckyBag(
        roomId: widget.roomId,
        senderId: widget.senderId,
        senderName: widget.senderName,
        senderAvatar: widget.senderAvatar,
        totalAmount: _selectedAmount,
        maxWinners: _selectedWinners,
        countdownSeconds: _selectedCountdown,
        distributionType:
            _distributionMethod == 'Random' ? 'random' : 'equal',
        message: 'Enjoy the lucky diamonds! 🎁',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🎁 Lucky Bag ($_selectedAmount 💎 for $_selectedWinners winners) sent!'),
            backgroundColor: const Color(0xFFFF2A55),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send Lucky Bag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    final formatNumber = (int n) {
      if (n >= 1000000) {
        return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)},000,000';
      } else if (n >= 1000) {
        return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)},000';
      }
      return n.toString();
    };

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF3366), Color(0xFFFF1744)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header with 3D Graphic & Header Buttons
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 3D Graphic Bags Illustration in Header
              Container(
                height: 70,
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: -0.15,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellowAccent.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.amber, size: 26),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.translate(
                      offset: const Offset(0, -6),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.card_giftcard,
                            color: Color(0xFFD81B60), size: 34),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.rotate(
                      angle: 0.15,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellowAccent.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.amber, size: 26),
                      ),
                    ),
                  ],
                ),
              ),

              // Title Arch Crest ("Lucky bag")
              Positioned(
                bottom: -14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2A55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD54F),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Lucky bag',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),

              // Top Left Icons: Rules (?) and Record History
              Positioned(
                top: 14,
                left: 16,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showRulesDialog(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF5252).withValues(alpha: 0.9),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lucky Bag History'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF5252).withValues(alpha: 0.9),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Top Right Close Icon (X)
              Positioned(
                top: 14,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF5252).withValues(alpha: 0.9),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Main Form Container (Light Cream Card #FFFDF0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFDF0),
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. Diamonds Selection
                const Text(
                  'Diamonds',
                  style: TextStyle(
                    color: Color(0xFF7A301E),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Custom Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _showCustomInputDialog(
                            title: 'Enter Custom Diamonds',
                            hint: 'e.g. 1000',
                            initialValue: _selectedAmount,
                            onSubmitted: (val) {
                              setState(() {
                                _selectedAmount = val;
                                _isCustomAmount = true;
                              });
                            },
                          );
                        },
                        child: _buildOptionPill(
                          text: _isCustomAmount
                              ? formatNumber(_selectedAmount)
                              : 'Custom ✏️',
                          isSelected: _isCustomAmount,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._presetAmounts.map((amt) {
                      final isSel = !_isCustomAmount && _selectedAmount == amt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAmount = amt;
                                _isCustomAmount = false;
                              });
                            },
                            child: _buildOptionPill(
                              text: formatNumber(amt),
                              isSelected: isSel,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 18),

                // B. Quantity Selection
                const Text(
                  'Quantity',
                  style: TextStyle(
                    color: Color(0xFF7A301E),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Custom Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _showCustomInputDialog(
                            title: 'Enter Custom Winners',
                            hint: 'e.g. 10',
                            initialValue: _selectedWinners,
                            onSubmitted: (val) {
                              setState(() {
                                _selectedWinners = val;
                                _isCustomWinners = true;
                              });
                            },
                          );
                        },
                        child: _buildOptionPill(
                          text: _isCustomWinners
                              ? '$_selectedWinners'
                              : 'Custom ✏️',
                          isSelected: _isCustomWinners,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._presetWinners.map((w) {
                      final isSel = !_isCustomWinners && _selectedWinners == w;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedWinners = w;
                                _isCustomWinners = false;
                              });
                            },
                            child: _buildOptionPill(
                              text: '$w',
                              isSelected: isSel,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 18),

                // C. Method Selection (Random vs Average)
                const Text(
                  'Method',
                  style: TextStyle(
                    color: Color(0xFF7A301E),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _distributionMethod = 'Random'),
                        child: _buildOptionPill(
                          text: 'Random',
                          isSelected: _distributionMethod == 'Random',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _distributionMethod = 'Average'),
                        child: _buildOptionPill(
                          text: 'Average',
                          isSelected: _distributionMethod == 'Average',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // D. Countdown Selection
                const Text(
                  'Countdown',
                  style: TextStyle(
                    color: Color(0xFF7A301E),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: _presetCountdowns.map((sec) {
                    final isSel = _selectedCountdown == sec;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCountdown = sec),
                          child: _buildOptionPill(
                            text: '${sec}s',
                            isSelected: isSel,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Bottom Send Button & User Wallet Diamond Recharge Bar
          // Elevated above system navigation bar using bottomInset padding
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + (bottomInset > 0 ? bottomInset : 12)),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSend,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 6,
                      shadowColor: Colors.black45,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFC107), Color(0xFFFF8F00)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Send',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Realtime Diamond Wallet & Recharge Button (Safe Above System Navigation Bar)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Users')
                      .doc(widget.senderId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int walletDiamonds = 0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        final val = data['diamonds'] ?? data['wallet'] ?? 0;
                        walletDiamonds = (val is double) ? val.toInt() : (val is int ? val : 0);
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        final currentUser = AuthController.instance.currentUser;
                        Get.to(() => UserWalletScreen(currentUser: currentUser));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DynamicDiamondIcon(width: 16, height: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$walletDiamonds Recharge >',
                            style: const TextStyle(
                              color: Color(0xFFFFEEB3),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionPill({required String text, required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF2A55) // Selected vibrant pink
            : const Color(0xFFFFEEC9), // Unselected light beige
        borderRadius: BorderRadius.circular(18),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFF2A55).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF7A301E),
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Inter',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RuleText extends StatelessWidget {
  final String number;
  final String text;

  const _RuleText({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFF7A301E),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            height: 1.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A301E),
              fontSize: 13,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
