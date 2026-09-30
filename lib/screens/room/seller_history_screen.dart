import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


import 'package:chat_messenger/screens/room/seller_diamond_request_screen.dart';

class SellerHistoryScreen extends StatefulWidget {
  final User currentUser;

  const SellerHistoryScreen({super.key, required this.currentUser});

  @override
  State<SellerHistoryScreen> createState() => _SellerHistoryScreenState();
}

class _SellerHistoryScreenState extends State<SellerHistoryScreen> {
  int _dailySales = 0;
  int _monthlySales = 0;
  int _totalSales = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('seller_transactions')
          .where('sellerId', isEqualTo: widget.currentUser.userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      int daily = 0;
      int monthly = 0;
      int total = 0;
      final now = DateTime.now();
      final List<Map<String, dynamic>> transList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        transList.add(data);

        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        total += amount;

        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          if (date.year == now.year && date.month == now.month) {
            monthly += amount;
            if (date.day == now.day) {
              daily += amount;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _dailySales = daily;
          _monthlySales = monthly;
          _totalSales = total;
          _transactions = transList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching seller history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellerDiamondRequestScreen(
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC381F4), Color(0xFF8E44AD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E44AD).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DynamicDiamondIcon(width: 14, height: 14),
                      SizedBox(width: 4),
                      Text(
                        'Stock & Top-Up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : Column(
              children: [
                _buildStatsSection(),
                const SizedBox(height: 12),
                Expanded(child: _buildTransactionList()),
              ],
            ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Daily Sales', _dailySales, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Monthly Sales', _monthlySales, Colors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC381F4), Color(0xFF8E44AD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Total All-Time Sales',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DynamicDiamondIcon(width: 20, height: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$_totalSales',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DynamicDiamondIcon(width: 14, height: 14),
              const SizedBox(width: 4),
              Text(
                '$amount',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No sales history found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final amount = tx['amount'] ?? 0;
        final desc = tx['description'] as String? ?? 'Recharge';
        final timestamp = tx['createdAt'] as Timestamp?;
        
        // Extract username from description if possible, e.g. "Seller recharge: 100 diamonds to John Doe"
        String username = 'User';
        if (desc.contains('to ')) {
          username = desc.split('to ').last;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.pink.shade50,
                  child: const Icon(Icons.arrow_outward, color: Colors.pink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recharge to $username',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(timestamp),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('+', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        DynamicDiamondIcon(width: 12, height: 12),
                        const SizedBox(width: 2),
                        Text(
                          '$amount',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Completed', style: TextStyle(color: Colors.green, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
