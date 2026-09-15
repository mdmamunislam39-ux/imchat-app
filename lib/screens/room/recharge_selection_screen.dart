import 'package:flutter/material.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/seller_list_screen.dart';
import 'package:chat_messenger/screens/room/online_recharge_screen.dart';
import 'package:chat_messenger/screens/room/user_recharge_history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen allowing the user to mark/select between Online Recharge and Offline Seller Recharge
/// and then proceed to the next step.
class RechargeSelectionScreen extends StatefulWidget {
  final User currentUser;
  final int? preselectedDiamonds;
  final int? preselectedBonusDiamonds;
  final num? preselectedBdt;

  const RechargeSelectionScreen({
    super.key,
    required this.currentUser,
    this.preselectedDiamonds,
    this.preselectedBonusDiamonds,
    this.preselectedBdt,
  });

  @override
  State<RechargeSelectionScreen> createState() => _RechargeSelectionScreenState();
}

class _RechargeSelectionScreenState extends State<RechargeSelectionScreen> {
  int _diamondBalance = 0;
  String _selectedOption = 'online'; // 'online' or 'offline'

  @override
  void initState() {
    super.initState();
    _diamondBalance = widget.currentUser.diamonds;
    _listenToUserDiamonds();
  }

  void _listenToUserDiamonds() {
    FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.currentUser.userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final diamonds = (doc.data()?['diamonds'] as num?)?.toInt() ?? 0;
        setState(() {
          _diamondBalance = diamonds;
        });
      }
    });
  }

  void _proceedToNextStep() {
    if (_selectedOption == 'online') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineRechargeScreen(
            currentUser: widget.currentUser,
            initialAmount: widget.preselectedBdt,
            initialDiamonds: widget.preselectedDiamonds,
            initialBonusDiamonds: widget.preselectedBonusDiamonds,
          ),
        ),
      );
    } else {
      // Offline Seller Recharge (opens existing SellerListScreen unchanged)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellerListScreen(
            requestedAmount: widget.preselectedDiamonds ?? 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF14121E) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;

    final hasPreselected = widget.preselectedBdt != null && widget.preselectedDiamonds != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recharge Option',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Recharge History',
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.amberAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRechargeHistoryScreen(userId: widget.currentUser.userId),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selected Package summary pill (if coming from package screen)
                    if (hasPreselected) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withAlpha(50),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Package',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '৳${widget.preselectedBdt!.toStringAsFixed(2)} BDT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.diamond_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${widget.preselectedDiamonds} Diamonds',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Current Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Row(
                        children: [
                          const Center(
                            child: DynamicDiamondIcon(width: 32, height: 32),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Balance',
                                style: TextStyle(color: subtitleColor, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    _diamondBalance.toString(),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Diamonds',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Title
                    Text(
                      'Select Recharge Method',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'যে মাধ্যমে রিচার্জ করতে চান সেটি মার্ক করে নিচের বাটনে চাপুন',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. ONLINE RECHARGE OPTION (Markable)
                    _buildMarkableOptionCard(
                      optionKey: 'online',
                      iconWidget: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00B074), Color(0xFF007A50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                      ),
                      tag: 'FAST & EASY',
                      tagColor: const Color(0xFF00B074),
                      title: 'Online Recharge',
                      subtitle: 'Fast & Easy Online Payment\n(bKash, Nagad, Rocket)',
                      isSelected: _selectedOption == 'online',
                      cardColor: cardColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () {
                        setState(() => _selectedOption = 'online');
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. OFFLINE SELLER RECHARGE OPTION (Markable)
                    _buildMarkableOptionCard(
                      optionKey: 'offline',
                      iconWidget: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8C00), Color(0xFFE55D00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                      ),
                      tag: 'OFFICIAL SELLERS',
                      tagColor: const Color(0xFFFF8C00),
                      title: 'Offline Seller Recharge',
                      subtitle: 'Recharge via Seller\n(Chat & direct diamond transfer)',
                      isSelected: _selectedOption == 'offline',
                      cardColor: cardColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () {
                        setState(() => _selectedOption = 'offline');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom "Proceed / Next Step" Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceedToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.pink.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedOption == 'online'
                            ? 'PROCEED TO ONLINE PAYMENT'
                            : 'GO TO SELLER LIST',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkableOptionCard({
    required String optionKey,
    required Widget iconWidget,
    required String tag,
    required Color tagColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? tagColor : Colors.white.withAlpha(20),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? tagColor.withAlpha(30) : Colors.black.withAlpha(20),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Radio Mark Indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? tagColor : Colors.grey.shade500,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tagColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              iconWidget,
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
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
}
