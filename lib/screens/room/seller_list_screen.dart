import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class SellerListScreen extends StatefulWidget {
  final int requestedAmount;

  const SellerListScreen({
    super.key,
    required this.requestedAmount,
  });

  @override
  State<SellerListScreen> createState() => _SellerListScreenState();
}

class _SellerListScreenState extends State<SellerListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sellersData = [];

  @override
  void initState() {
    super.initState();
    _fetchSellers();
  }

  Future<void> _fetchSellers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sellers')
          .where('isActive', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> loadedSellers = [];

      for (var doc in snapshot.docs) {
        final sellerData = doc.data();
        final userId = sellerData['userId'] as String?;
        if (userId != null) {
          // Fetch user details for the seller
          final userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .get();
              
          if (userDoc.exists) {
            final userObj = User.fromMap(userDoc.data()!);
            sellerData['userObj'] = userObj;
            loadedSellers.add(sellerData);
          }
        }
      }

      // Sort by online status or last active
      loadedSellers.sort((a, b) {
        final userA = a['userObj'] as User;
        final userB = b['userObj'] as User;
        if (userA.isOnline && !userB.isOnline) return -1;
        if (!userA.isOnline && userB.isOnline) return 1;
        final timeA = userA.lastActive?.millisecondsSinceEpoch ?? 0;
        final timeB = userB.lastActive?.millisecondsSinceEpoch ?? 0;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _sellersData = loadedSellers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sellers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _contactSeller(User sellerUser) async {
    // Add seller to contacts
    ContactApi.addContact(userId: sellerUser.userId);
    // Go to messages
    RoutesHelper.toMessages(user: sellerUser).then((_) {
      Get.back();
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} mins ago';
    } else {
      return 'Just now';
    }
  }
  
  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} mins ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diamond Sellers'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.pink.shade50,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.pink, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.requestedAmount > 0
                        ? 'Select a seller to recharge ${widget.requestedAmount} diamonds. Contact them to arrange payment.'
                        : 'Select a seller to buy/recharge diamonds. Contact them to arrange payment.',
                    style: TextStyle(color: Colors.pink.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sellersData.isEmpty
                    ? const Center(
                        child: Text(
                          'No active sellers available right now.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sellersData.length,
                        itemBuilder: (context, index) {
                          final seller = _sellersData[index];
                          final user = seller['userObj'] as User;
                          final balance = seller['accountBalance'] ?? 0;
                          final updatedAt = seller['updatedAt'] as Timestamp?;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CachedCircleAvatar(
                                    imageUrl: user.photoUrl,
                                    radius: 30,
                                    isOnline: user.isOnline,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.fullname,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (user.isVerified)
                                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        UserIdBadgeWidget(
                                           searchId: user.searchId,
                                           badgeHeight: 14,
                                           textStyle: TextStyle(
                                             fontSize: 12,
                                             color: Colors.grey.shade600,
                                           ),
                                         ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            DynamicDiamondIcon(width: 14, height: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$balance Available',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.pink,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Last Recharge: ${_formatTime(updatedAt)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          'Activity: ${user.isOnline ? "Online Now" : _formatDateTime(user.lastActive)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: user.isOnline ? Colors.green : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _contactSeller(user),
                                        icon: const Icon(Icons.message, size: 16, color: Colors.white),
                                        label: const Text('Chat', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: const Size(80, 36),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
