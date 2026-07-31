import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/contact_api.dart';

class FriendRequestScreen extends StatelessWidget {
  const FriendRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthController.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.userId)
            .collection('friend_requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No new requests'));
          }
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final senderId = data['senderId'];
              
              return FutureBuilder<User?>(
                future: UserApi.getUser(senderId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();
                  final user = userSnapshot.data!;
                  
                  return ListTile(
                    leading: CachedCircleAvatar(
                      imageUrl: user.photoUrl,
                      radius: 20,
                    ),
                    title: Text(user.fullname),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            // Accept Request
                            await ContactApi.addContact(userId: user.userId);
                            await doc.reference.delete();
                          },
                          child: const Text('Accept', style: TextStyle(color: Colors.green)),
                        ),
                        TextButton(
                          onPressed: () => doc.reference.delete(),
                          child: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
