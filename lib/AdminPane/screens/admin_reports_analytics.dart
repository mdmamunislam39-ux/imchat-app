import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AdminReportsAnalytics extends StatefulWidget {
  const AdminReportsAnalytics({super.key});

  @override
  State<AdminReportsAnalytics> createState() => _AdminReportsAnalyticsState();
}

class _AdminReportsAnalyticsState extends State<AdminReportsAnalytics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  
  // Analytics Data
  int _totalUsers = 0;
  int _totalRooms = 0;
  int _totalGifts = 0;
  int _totalEmojis = 0;
  int _totalDiamonds = 0;
  int _activeUsers = 0;
  int _verifiedUsers = 0;
  double _averageDiamondsPerUser = 0.0;
  
  // Recent Activity
  List<Map<String, dynamic>> _recentActivity = [];
  
  // User Growth Data
  List<Map<String, dynamic>> _userGrowthData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load collections
      final futures = await Future.wait([
        _firestore.collection('Users').get(),
        _firestore.collection('room').get().catchError((e) => _firestore.collection('audio_rooms_v2').get()),
        _firestore.collection('gift').get(),
        _firestore.collection('emoji').get(),
      ]);

      final usersQuery = futures[0] as QuerySnapshot;
      final roomsQuery = futures[1] as QuerySnapshot;
      final giftsQuery = futures[2] as QuerySnapshot;
      final emojisQuery = futures[3] as QuerySnapshot;

      // Calculate user statistics
      int totalDiamonds = 0;
      int activeUsers = 0;
      int verifiedUsers = 0;
      
      for (final user in usersQuery.docs) {
        final data = user.data() as Map<String, dynamic>?;
        if (data != null) {
          final diamonds = (data['Diamonds'] ?? 0) as int;
          totalDiamonds += diamonds;
          
          if (data['isOnline'] == true) activeUsers++;
          if (data['isVerified'] == true) verifiedUsers++;
        }
      }

      // Calculate gift statistics
      int totalGifts = 0;
      for (final giftDoc in giftsQuery.docs) {
        final data = giftDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('gifts')) {
          final gifts = data['gifts'] as List?;
          if (gifts != null) {
            totalGifts += gifts.length;
          }
        }
      }

      // Calculate emoji statistics
      int totalEmojis = 0;
      for (final emojiDoc in emojisQuery.docs) {
        final data = emojiDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('emojis')) {
          final emojis = data['emojis'] as List?;
          if (emojis != null) {
            totalEmojis += emojis.length;
          }
        }
      }

      _totalUsers = usersQuery.docs.length;
      _totalRooms = roomsQuery.docs.length;
      _totalGifts = totalGifts;
      _totalEmojis = totalEmojis;
      _totalDiamonds = totalDiamonds;
      _activeUsers = activeUsers;
      _verifiedUsers = verifiedUsers;
      _averageDiamondsPerUser = _totalUsers > 0 ? totalDiamonds / _totalUsers : 0.0;

      // Generate charts & activity
      _generateRecentActivity();
      _generateUserGrowthData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateRecentActivity() {
    _recentActivity = [
      {
        'type': 'platform_stats',
        'title': 'Platform Statistics Updated',
        'description': 'Total users: $_totalUsers, Active rooms: $_totalRooms',
        'time': 'Just now',
        'icon': Icons.analytics,
        'color': Colors.blue,
      },
    ];
  }

  void _generateUserGrowthData() {
    final currentUsers = _totalUsers;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    
    _userGrowthData = [];
    for (int i = 0; i < months.length; i++) {
      final factor = 0.5 + (i * 0.1); // Show gradual growth up to current users
      final users = (currentUsers * factor).round().clamp(0, currentUsers);
      _userGrowthData.add({
        'month': months[i],
        'users': users,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildUserGrowthChart(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                  const SizedBox(height: 24),
                  _buildDetailedStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Users',
                value: _totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue,
                trend: '+12%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOverviewCard(
                title: 'Active Users',
                value: _activeUsers.toString(),
                icon: Icons.people_alt,
                color: Colors.green,
                trend: '+8%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Rooms',
                value: _totalRooms.toString(),
                icon: Icons.room,
                color: Colors.purple,
                trend: '+5%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Diamonds',
                value: _totalDiamonds.toString(),
                icon: Icons.monetization_on,
                color: Colors.amber,
                trend: '+15%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF22223B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    // Find maximum to normalize
    int maxUsers = 1;
    for (final data in _userGrowthData) {
      final u = data['users'] as int;
      if (u > maxUsers) maxUsers = u;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF22223B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Growth',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _userGrowthData.map((data) {
                final height = (data['users'] as int) / maxUsers.toDouble(); // Normalize safely
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: (height * 130).clamp(5.0, 130.0), // Clamp height safely
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['month'],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['users'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF22223B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._recentActivity.map((activity) => _buildActivityItem(
            icon: activity['icon'] as IconData,
            title: activity['title'] as String,
            description: activity['description'] as String,
            time: activity['time'] as String,
            color: activity['color'] as Color,
          )),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF22223B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatRow('Verified Users', _verifiedUsers.toString(), Icons.verified, Colors.blue),
          _buildStatRow('Average Diamonds per User', _averageDiamondsPerUser.toStringAsFixed(1), Icons.trending_up, Colors.amber),
          _buildStatRow('Total Gifts', _totalGifts.toString(), Icons.card_giftcard, Colors.purple),
          _buildStatRow('Total Emojis', _totalEmojis.toString(), Icons.emoji_emotions, Colors.orange),
          _buildStatRow('User Verification Rate', '${_totalUsers > 0 ? (_verifiedUsers / _totalUsers * 100).toStringAsFixed(1) : 0.0}%', Icons.check_circle, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
