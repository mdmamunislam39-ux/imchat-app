import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/services/online_recharge_service.dart';

/// Screen displaying the user's online recharge history with status badges and filter tabs
class UserRechargeHistoryScreen extends StatefulWidget {
  final String userId;

  const UserRechargeHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserRechargeHistoryScreen> createState() => _UserRechargeHistoryScreenState();
}

class _UserRechargeHistoryScreenState extends State<UserRechargeHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OnlineRechargeService _rechargeService = OnlineRechargeService.instance;

  final List<String> _tabs = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyTrxId(String trxId) {
    Clipboard.setData(ClipboardData(text: trxId));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('TrxID copied: $trxId'),
        backgroundColor: const Color(0xFF0C6B44),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF14121E) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;

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
          'Recharge History',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00B074),
          indicatorWeight: 3,
          labelColor: const Color(0xFF00B074),
          unselectedLabelColor: subtitleColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: StreamBuilder<List<RechargeOrderModel>>(
        stream: _rechargeService.getUserOrdersStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00B074)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading history: ${snapshot.error}',
                style: TextStyle(color: textColor),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              List<RechargeOrderModel> filteredOrders;
              if (tab == 'All') {
                filteredOrders = allOrders;
              } else {
                filteredOrders = allOrders
                    .where((order) => order.status.toLowerCase() == tab.toLowerCase())
                    .toList();
              }

              if (filteredOrders.isEmpty) {
                return _buildEmptyState(tab, textColor, subtitleColor);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order, cardColor, textColor, subtitleColor);
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String filter, Color textColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: subtitleColor.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            filter == 'All' ? 'No recharge history yet' : 'No $filter orders',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Your online diamond recharge orders will appear here.',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    RechargeOrderModel order,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (order.isApproved) {
      statusBgColor = const Color(0xFF00B074).withAlpha(30);
      statusTextColor = const Color(0xFF00B074);
      statusIcon = Icons.check_circle_rounded;
    } else if (order.isRejected) {
      statusBgColor = Colors.red.withAlpha(30);
      statusTextColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBgColor = Colors.amber.withAlpha(30);
      statusTextColor = Colors.amber;
      statusIcon = Icons.hourglass_top_rounded;
    }

    final formattedDate = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
        : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Amount + Diamonds and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '৳${order.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF00B074),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '+${order.diamondAmount} Diamonds',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusTextColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      order.status,
                      style: TextStyle(
                        color: statusTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),

          // Order details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order ID:', style: TextStyle(color: subtitleColor, fontSize: 12)),
              Text(
                order.orderId,
                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Channel:', style: TextStyle(color: subtitleColor, fontSize: 12)),
              Text(
                order.paymentMethod,
                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // TrxID with copy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TrxID:', style: TextStyle(color: subtitleColor, fontSize: 12)),
              InkWell(
                onTap: () => _copyTrxId(order.transactionId),
                child: Row(
                  children: [
                    Text(
                      order.transactionId,
                      style: const TextStyle(
                        color: Color(0xFF00B074),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded, color: Color(0xFF00B074), size: 13),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date & Time:', style: TextStyle(color: subtitleColor, fontSize: 12)),
              Text(
                formattedDate,
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ],
          ),

          if (order.isRejected && (order.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${order.rejectionReason}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
