import 'package:flutter/material.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/screens/room/user_recharge_history_screen.dart';

/// Screen displayed immediately after user submits a recharge request
class RechargeSuccessScreen extends StatelessWidget {
  final RechargeOrderModel order;

  const RechargeSuccessScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF14121E) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated / Glowing Success Badge
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B074), Color(0xFF007A50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B074).withAlpha(80),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Recharge Request Submitted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'আপনার রিচার্জ অনুরোধটি জমা দেওয়া হয়েছে। এডমিন ভেরিফাই করে অনুমোদন করার পরই ডায়মন্ড যুক্ত হবে।',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Order Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber.shade700, width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Pending Verification',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildDetailRow('Order ID', order.orderId, textColor, subtitleColor),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow(
                          'Amount',
                          '৳${order.amount.toStringAsFixed(2)}',
                          const Color(0xFF00B074),
                          subtitleColor,
                          isBoldValue: true,
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow(
                          'Diamonds',
                          '+${order.diamondAmount} Diamonds',
                          Colors.amberAccent,
                          subtitleColor,
                          isBoldValue: true,
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('Payment Method', order.paymentMethod, textColor, subtitleColor),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('Payment Number', order.paymentNumber, textColor, subtitleColor),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('Transaction ID', order.transactionId, textColor, subtitleColor, isSelectable: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // View Recharge History Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserRechargeHistoryScreen(userId: order.userId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C6B44),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'VIEW RECHARGE HISTORY',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Back to Wallet Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: Colors.white.withAlpha(40)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor, {
    bool isBoldValue = false,
    bool isSelectable = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: isSelectable
              ? SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
