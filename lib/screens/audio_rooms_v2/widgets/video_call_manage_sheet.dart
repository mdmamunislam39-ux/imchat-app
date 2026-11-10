// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../components/cached_circle_avatar.dart';
import '../../../models/audio_room_v2.dart';
import '../../../models/user.dart';
import '../bloc/audio_rooms_bloc.dart';
import '../bloc/audio_rooms_event.dart';

/// Sheet to manage Call Join Requests and Active Call Guests
class VideoCallManageSheet extends StatelessWidget {
  final AudioRoomV2 room;
  final AudioRoomsBloc audioRoomsBloc;

  const VideoCallManageSheet({
    super.key,
    required this.room,
    required this.audioRoomsBloc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: const Color(0xFF131722).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Manage Call Guests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Real-time List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('audio_rooms_v2')
                    .doc(room.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD946EF)),
                    );
                  }

                  final data = snapshot.hasData && snapshot.data!.exists
                      ? snapshot.data!.data() as Map<String, dynamic>? ?? {}
                      : <String, dynamic>{};

                  final joinRequests = List<String>.from(data['joinRequests'] ?? room.joinRequests);

                  // Extract active guests seated on seat > 1
                  final participantsRaw = data['participants'] as List? ?? [];
                  final activeGuests = participantsRaw.where((p) {
                    if (p is Map) {
                      final seatNum = p['seatNumber'] as int? ?? 0;
                      return seatNum > 1;
                    }
                    return false;
                  }).toList();

                  if (joinRequests.isEmpty && activeGuests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 54,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No join requests or active guests',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 1. Pending Join Requests Section
                      if (joinRequests.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Join Requests (${joinRequests.length})',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...joinRequests.map(
                          (userId) => _buildRequestItem(context, userId),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 2. Active Guests Section
                      if (activeGuests.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Guests on Call (${activeGuests.length})',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...activeGuests.map(
                          (p) => _buildActiveGuestItem(context, p as Map<String, dynamic>),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItem(BuildContext context, String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, snapshot) {
        String name = 'User $userId';
        String photoUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final uData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final u = User.fromMap(uData);
          name = u.fullname.isNotEmpty ? u.fullname : 'User $userId';
          photoUrl = u.photoUrl;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              CachedCircleAvatar(
                imageUrl: photoUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requesting to join call',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Reject Button
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5), size: 22),
                onPressed: () {
                  audioRoomsBloc.add(
                    RejectJoinRequest(roomId: room.id, userId: userId),
                  );
                },
              ),
              const SizedBox(width: 4),
              // Accept Button
              ElevatedButton(
                onPressed: () {
                  audioRoomsBloc.add(
                    AcceptJoinRequest(roomId: room.id, userId: userId),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Accepted $name to call'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveGuestItem(BuildContext context, Map<String, dynamic> participant) {
    final name = (participant['userName'] ?? 'Guest').toString();
    final photoUrl = (participant['userImageUrl'] ?? '').toString();
    final seatNumber = participant['seatNumber'] as int? ?? 0;
    final userId = (participant['userId'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CachedCircleAvatar(
            imageUrl: photoUrl,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Connected on Call (Seat $seatNumber)',
                  style: TextStyle(
                    color: const Color(0xFF10B981).withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Disconnect / Move to Audience Button
          TextButton(
            onPressed: () {
              audioRoomsBloc.add(
                MoveParticipantToSeat(
                  roomId: room.id,
                  userId: userId,
                  fromSeat: seatNumber,
                  toSeat: 0,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              backgroundColor: Colors.red.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
