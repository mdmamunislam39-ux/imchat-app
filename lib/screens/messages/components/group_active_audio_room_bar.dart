import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/screens/messages/controllers/message_controller.dart';
import 'package:chat_messenger/tabs/groups/controllers/group_controller.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

/// Real-time top active audio room & group call banner for group chat
class GroupActiveAudioRoomBar extends StatelessWidget {
  final MessageController controller;
  final String? overrideGroupId;

  const GroupActiveAudioRoomBar({
    super.key,
    required this.controller,
    this.overrideGroupId,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final group = controller.selectedGroup ?? (Get.isRegistered<GroupController>() ? GroupController.instance.selectedGroup.value : null);
      final String groupId = (overrideGroupId != null && overrideGroupId!.isNotEmpty)
          ? overrideGroupId!
          : (group?.groupId ?? (Get.isRegistered<GroupController>() ? (GroupController.instance.groupId.value ?? '') : ''));

      if (groupId.isEmpty) return const SizedBox.shrink();

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('GroupCalls').snapshots(),
        builder: (context, groupCallSnapshot) {
          // Check for active Group Call first
          if (groupCallSnapshot.hasData && groupCallSnapshot.data!.docs.isNotEmpty) {
            final activeCalls = groupCallSnapshot.data!.docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final String state = data['state'] ?? '';
              final String callerId = data['callerId'] ?? '';
              final String callerName = data['callerName'] ?? '';
              final List receiverNames = (data['receiverName'] as List?) ?? [];

              // Ensure call belongs to THIS group
              bool matchesThisGroup = false;
              if (group != null) {
                if (callerName.trim().toLowerCase() == group.name.trim().toLowerCase() ||
                    callerId == group.groupId) {
                  matchesThisGroup = true;
                } else if (group.recipients.any((u) => u.userId == callerId || u.fullname == callerName)) {
                  matchesThisGroup = true;
                }
              }

              final bool isActiveState = (state == 'calling' || state == 'running');
              return matchesThisGroup && isActiveState && receiverNames.isNotEmpty;
            }).toList();

            if (activeCalls.isNotEmpty) {
              final doc = activeCalls.first;
              final data = doc.data() as Map<String, dynamic>;
              final bool isVideo = data['isVideo'] ?? false;
              final String callerId = data['callerId'] ?? doc.id;
              final String callerName = data['callerName'] ?? 'Group Call';
              final String callerPhotoUrl = data['callerPhotoUrl'] ?? '';
              final List receiverNames = (data['receiverName'] as List?) ?? [];

              final Call call = Call(
                isVideo: isVideo,
                callerId: callerId,
                callerName: callerName,
                callerPhotoUrl: callerPhotoUrl,
                receiverName: callerName,
                receiverPhotoUrl: callerPhotoUrl,
                receiverId: 'group_call',
                agoraToken: data['agoraToken'],
              );

              // Extract small circular profile pictures only (max 9 avatars)
              List<String> photoUrls = [];
              final String callerRealName = data['callerRealName'] ?? '';
              final User currentUser = AuthController.instance.currentUser;

              for (var name in receiverNames) {
                final nameStr = name.toString().trim();
                String photo = '';
                if (nameStr == currentUser.fullname) {
                  photo = currentUser.photoUrl;
                } else if (nameStr == callerRealName && callerPhotoUrl.isNotEmpty) {
                  photo = callerPhotoUrl;
                } else if (group != null && group.recipients.isNotEmpty) {
                  final match = group.recipients.where((u) => u.fullname.trim() == nameStr).firstOrNull;
                  if (match != null && match.photoUrl.isNotEmpty) {
                    photo = match.photoUrl;
                  }
                }
                photoUrls.add(photo);
              }

              final List<String> displayPhotos = photoUrls.take(9).toList();
              final int extraCount = photoUrls.length - 9;

              List<Widget> avatarWidgets = displayPhotos.map((photo) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blueAccent,
                        width: 1.5,
                      ),
                    ),
                    child: CachedCircleAvatar(
                      imageUrl: photo,
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      borderWidth: 0,
                      padding: 0,
                    ),
                  ),
                );
              }).toList();

              if (extraCount > 0) {
                avatarWidgets.add(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent, width: 1),
                    ),
                    child: Text(
                      '+$extraCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                );
              }

              return _buildActiveBarContainer(
                context: context,
                icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                onTap: () {
                  Get.to(() => GroupCallScreen(
                        isVideo: isVideo,
                        call: call,
                        recipients: group?.recipients,
                      ));
                },
                participantsWidgets: avatarWidgets,
              );
            }
          }

          // Fallback to audio_rooms_v2
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('audio_rooms_v2')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              final activeDocs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final String? roomGroupId = data['groupId']?.toString();
                final bool isActive = (data['isActive'] ?? true) != false;
                final List participants = (data['participants'] as List?) ?? [];
                return isActive &&
                    roomGroupId != null &&
                    roomGroupId == groupId.toString() &&
                    participants.isNotEmpty;
              }).toList();

              if (activeDocs.isEmpty) return const SizedBox.shrink();

              final doc = activeDocs.first;
              final room = AudioRoomV2.fromFirestore(doc);

              if (!room.isActive || room.participants.isEmpty) {
                return const SizedBox.shrink();
              }

              final List displayParticipants = room.participants.take(9).toList();
              final int extraRoomCount = room.participants.length - 9;

              List<Widget> roomAvatarWidgets = displayParticipants.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blueAccent,
                        width: 1.5,
                      ),
                    ),
                    child: CachedCircleAvatar(
                      imageUrl: p.userImageUrl ?? '',
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      borderWidth: 0,
                      padding: 0,
                    ),
                  ),
                );
              }).toList();

              if (extraRoomCount > 0) {
                roomAvatarWidgets.add(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent, width: 1),
                    ),
                    child: Text(
                      '+$extraRoomCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                );
              }

              return _buildActiveBarContainer(
                context: context,
                icon: Icons.record_voice_over_rounded,
                onTap: () {
                  AudioRoomsV2Integration.navigateToRoom(room, context);
                },
                participantsWidgets: roomAvatarWidgets,
              );
            },
          );
        },
      );
    });
  }

  Widget _buildActiveBarContainer({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    required List<Widget> participantsWidgets,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Phone / Call Icon Circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0088FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                // Small Profile Picture Avatars (No Text Names!)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: participantsWidgets,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
