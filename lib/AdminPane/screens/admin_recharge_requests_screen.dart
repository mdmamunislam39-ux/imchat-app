import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/services/online_recharge_service.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';

/// Admin Panel screen to review, approve, and reject user online recharge requests
class AdminRechargeRequestsScreen extends StatefulWidget {
  const AdminRechargeRequestsScreen({super.key});

  @override
  State<AdminRechargeRequestsScreen> createState() => _AdminRechargeRequestsScreenState();
}

class _AdminRechargeRequestsScreenState extends State<AdminRechargeRequestsScreen>
    with SingleTickerProviderStateMixin {
  final OnlineRechargeService _rechargeService = OnlineRechargeService.instance;
  late TabController _tabController;

  final List<String> _tabs = ['Pending', 'Approved', 'Rejected', 'All'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied: $text'),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _approveOrder(RechargeOrderModel order) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Recharge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to approve this recharge?', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('• User: ${order.userName} (${order.userId})', style: const TextStyle(color: Colors.white)),
            Text('• Amount: ৳${order.amount}', style: const TextStyle(color: Color(0xFF00B074), fontWeight: FontWeight.bold)),
            Text('• Diamonds to Credit: +${order.diamondAmount} Diamonds', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            Text('• TrxID: ${order.transactionId}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This will atomically credit diamonds to the user balance and cannot be undone.',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B074)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM & CREDIT'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      await _rechargeService.approveRechargeOrder(
        orderId: order.orderId,
        adminId: currentAdminId,
      );

      if (mounted) Navigator.pop(context); // Dismiss progress

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderId} approved! +${order.diamondAmount} diamonds credited.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectOrder(RechargeOrderModel order) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final reasonController = TextEditingController(text: 'Invalid Transaction ID / Payment not received');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Recharge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter rejection reason for this order:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REJECT ORDER'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _rechargeService.rejectRechargeOrder(
        orderId: order.orderId,
        adminId: currentAdminId,
        reason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderId} rejected.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recharge Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white60,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by TrxID, User ID, or Order ID...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E142B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),

          // Tab views
          Expanded(
            child: StreamBuilder<List<RechargeOrderModel>>(
              stream: _rechargeService.getAdminOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading requests: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                  );
                }

                final allOrders = snapshot.data ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    List<RechargeOrderModel> orders;
                    if (tab == 'All') {
                      orders = allOrders;
                    } else {
                      orders = allOrders.where((o) => o.status.toLowerCase() == tab.toLowerCase()).toList();
                    }

                    // Apply Search Query
                    if (_searchQuery.isNotEmpty) {
                      orders = orders.where((o) {
                        return o.transactionId.toLowerCase().contains(_searchQuery) ||
                            o.userId.toLowerCase().contains(_searchQuery) ||
                            o.orderId.toLowerCase().contains(_searchQuery) ||
                            o.userName.toLowerCase().contains(_searchQuery);
                      }).toList();
                    }

                    if (orders.isEmpty) {
                      return Center(
                        child: Text(
                          tab == 'Pending' ? 'No pending recharge requests! 🎉' : 'No $tab orders found.',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        return _buildAdminOrderCard(orders[index]);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminOrderCard(RechargeOrderModel order) {
    Color statusColor = Colors.amber;
    if (order.isApproved) statusColor = const Color(0xFF00B074);
    if (order.isRejected) statusColor = Colors.redAccent;

    final formattedDate = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: order.isPending ? Colors.amber.withAlpha(80) : Colors.white.withAlpha(15),
          width: order.isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row
          Row(
            children: [
              CachedCircleAvatar(
                imageUrl: order.userPhoto,
                radius: 20,
                userId: order.userId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.userName.isNotEmpty ? order.userName : 'Anonymous',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => _copyToClipboard(order.userId, 'User ID'),
                      child: Row(
                        children: [
                          Text('ID: ${order.userId}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, color: Colors.white38, size: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          // Order details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order ID: ${order.orderId}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recharge Amount', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    '৳${order.amount.toStringAsFixed(2)} BDT',
                    style: const TextStyle(color: Color(0xFF00B074), fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Diamonds to Add', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    '+${order.diamondAmount} Diamonds',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Method & TrxID
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Method: ${order.paymentMethod}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('Target No: ${order.paymentNumber}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction ID:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    InkWell(
                      onTap: () => _copyToClipboard(order.transactionId, 'TrxID'),
                      child: Row(
                        children: [
                          SelectableText(
                            order.transactionId,
                            style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy, color: Colors.purpleAccent, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (order.isRejected && (order.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text('Rejection Reason: ${order.rejectionReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],

          if (order.isApproved && (order.verifiedBy?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text('Approved by Admin: ${order.verifiedBy}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
          ],

          // Actions
          if (order.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectOrder(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('REJECT'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveOrder(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B074),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('APPROVE'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
