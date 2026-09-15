import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';

class PendingFriendRequestBanner extends StatelessWidget {
  const PendingFriendRequestBanner({
    super.key,
    required this.user,
  });

  final User user;

  Future<Map<String, int>> _fetchMutualCounts(String currentUserId, String senderId) async {
    int commonContacts = 0;
    int commonGroups = 0;

    try {
      final currentContactsSnap = await FirebaseFirestore.instance
          .collection('Users/$currentUserId/Contacts')
          .get();
      final senderContactsSnap = await FirebaseFirestore.instance
          .collection('Users/$senderId/Contacts')
          .get();

      final currentSet = currentContactsSnap.docs.map((d) => d.id).toSet();
      final senderSet = senderContactsSnap.docs.map((d) => d.id).toSet();
      commonContacts = currentSet.intersection(senderSet).length;

      final currentGroupsSnap = await FirebaseFirestore.instance
          .collection('Groups')
          .where('members', arrayContains: currentUserId)
          .get();

      for (var doc in currentGroupsSnap.docs) {
        final members = List.from(doc.data()['members'] ?? []);
        if (members.contains(senderId)) {
          commonGroups++;
        }
      }
    } catch (e) {
      debugPrint('Error fetching mutual counts: $e');
    }

    return {
      'contacts': commonContacts,
      'groups': commonGroups,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthController.instance.currentUser.userId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .collection('friend_requests')
          .doc(user.userId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? data;

        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>?;
        }

        if (data == null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friend_requests')
                .doc('${user.userId}_$currentUserId')
                .snapshots(),
            builder: (context, snapshot2) {
              if (!snapshot2.hasData || !snapshot2.data!.exists) {
                return const SizedBox.shrink();
              }
              final data2 = snapshot2.data!.data() as Map<String, dynamic>?;
              if (data2 == null || data2['status'] == 'accepted') {
                return const SizedBox.shrink();
              }
              return _buildBannerBody(context, currentUserId, data2);
            },
          );
        }

        if (data['status'] == 'accepted') {
          return const SizedBox.shrink();
        }

        return _buildBannerBody(context, currentUserId, data);
      },
    );
  }

  Widget _buildBannerBody(BuildContext context, String currentUserId, Map<String, dynamic> data) {
    final String? roomTitle = data['roomTitle'] as String?;

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Top Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              children: [
                // Avatar
                CachedCircleAvatar(
                  imageUrl: user.photoUrl,
                  radius: 36,
                ),
                const SizedBox(height: 10),
                // Fullname
                Text(
                  user.fullname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Room Subtitle or Request Subtitle
                if (roomTitle != null && roomTitle.isNotEmpty)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[700],
                      ),
                      children: [
                        const TextSpan(text: 'From Room '),
                        TextSpan(
                          text: '"$roomTitle"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Sent you a friend request',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 12),

                // Common contacts & groups row
                FutureBuilder<Map<String, int>>(
                  future: _fetchMutualCounts(currentUserId, user.userId),
                  builder: (context, mutualSnap) {
                    final contactsCount = mutualSnap.data?['contacts'] ?? 0;
                    final groupsCount = mutualSnap.data?['groups'] ?? 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '$contactsCount common contacts',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '$groupsCount common groups >',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Action Buttons Row: Block / Accept
                Row(
                  children: [
                    // Block / Reject button
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ContactApi.rejectFriendRequest(senderId: user.userId);
                          },
                          icon: const Icon(Icons.block, size: 18, color: Colors.black87),
                          label: const Text(
                            'Block',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F2F7),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept button
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ContactApi.acceptFriendRequest(senderId: user.userId);
                          },
                          icon: const Icon(Icons.check, size: 18, color: Colors.white),
                          label: const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0099FF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),

          // Security warning & divider section below banner
          Container(
            color: const Color(0xFFEFEFF4),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                // Security Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Do NOT share your personal info such as phone number, SMS code, bank account, etc. Click "Block" if you\'re disturbed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Section text: Below are new messages
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[350])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Below are new messages',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[350])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
