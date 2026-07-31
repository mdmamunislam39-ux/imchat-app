import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';

class WaitingListBottomSheet extends StatelessWidget {
  final String roomId;
  final AudioRoomsBloc audioRoomsBloc;

  const WaitingListBottomSheet({
    super.key,
    required this.roomId,
    required this.audioRoomsBloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: audioRoomsBloc,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Waiting List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            // List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('audio_rooms_v2').doc(roomId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(
                      child: Text('Room not found', style: TextStyle(color: Colors.white54)),
                    );
                  }
                  
                  final roomData = snapshot.data!.data() as Map<String, dynamic>;
                  final joinRequests = List<String>.from(roomData['joinRequests'] ?? []);
                  
                  if (joinRequests.isEmpty) {
                    return const Center(
                      child: Text(
                        'No pending requests',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: joinRequests.length,
                    itemBuilder: (context, index) {
                      final userId = joinRequests[index];
                      return _buildRequestItem(context, userId);
                    },
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
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.white12),
            title: Text('Loading...', style: TextStyle(color: Colors.white54)),
          );
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        
        final user = User.fromMap(data);
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CachedCircleAvatar(
            imageUrl: user.photoUrl,
            radius: 22,
          ),
          title: Text(
            user.fullname,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Requested to join',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reject Button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  audioRoomsBloc.add(RejectJoinRequest(roomId: roomId, userId: userId));
                },
              ),
              const SizedBox(width: 8),
              // Accept Button
              ElevatedButton(
                onPressed: () {
                  audioRoomsBloc.add(AcceptJoinRequest(roomId: roomId, userId: userId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37), // Gold
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void showWaitingListBottomSheet(BuildContext context, String roomId, AudioRoomsBloc bloc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => WaitingListBottomSheet(
      roomId: roomId,
      audioRoomsBloc: bloc,
    ),
  );
}
