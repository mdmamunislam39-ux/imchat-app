import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/premium_room_service.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'dart:async';



class RoomMemberScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;

  const RoomMemberScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
  });

  @override
  State<RoomMemberScreen> createState() => _RoomMemberScreenState();
}

class _RoomMemberScreenState extends State<RoomMemberScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isJoiningAction = false;
  String? _selectedCategoryForEdit;
  List<dynamic>? _roomLevelConfigData;
  StreamSubscription? _roomConfigSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadRoomConfig();
  }

  void _loadRoomConfig() {
    try {
      _roomConfigSub = FirebaseFirestore.instance.collection('level_configurations').doc('room_config').snapshots().listen((doc) {
        if (doc.exists) {
          if (mounted) {
            setState(() {
              _roomLevelConfigData = doc.data()?['levels'] as List<dynamic>?;
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading room config stream in member screen: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _roomConfigSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleJoinRoom(List<dynamic> joinedUserIds) async {
    final bool isMember = joinedUserIds.contains(widget.currentUserId);
    final DocumentReference roomRef = FirebaseFirestore.instance
        .collection('audio_rooms_v2')
        .doc(widget.roomId);

    setState(() {
      _isJoiningAction = true;
    });

    try {
      if (isMember) {
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
            ),
            title: const Text(
              'Leave Member Club',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            content: const Text(
              'Are you sure you want to leave this room\'s member club?',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Leave',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await roomRef.update({
            'joinedUserIds': FieldValue.arrayRemove([widget.currentUserId]),
            'settings.adminIds': FieldValue.arrayRemove([widget.currentUserId])
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Left the room member club successfully.',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await roomRef.update({
          'joinedUserIds': FieldValue.arrayUnion([widget.currentUserId])
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 You are now an official member of this room!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            backgroundColor: Color(0xFFD4AF37),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningAction = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Room ID copied to clipboard!',
          style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
        ),
        backgroundColor: Color(0xFFD4AF37),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF14141E),
                Color(0xFF0A0A0E),
              ],
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('audio_rooms_v2')
                .doc(widget.roomId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  ),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    'Room not found.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              }

              final roomData = snapshot.data!.data() as Map<String, dynamic>;
              final String roomName = roomData['name'] ?? 'Voiceroom';
              final String? roomImageUrl = roomData['imageUrl'];
              final String creatorId = roomData['creatorId'] ?? '';
              final String creatorName = roomData['creatorName'] ?? 'Owner';
              final List<dynamic> participantsData =
                  roomData['participants'] as List<dynamic>? ?? [];
              final List<String> joinedUserIds = (roomData['joinedUserIds'] as List<dynamic>?)
                      ?.where((id) => id != null)
                      .map((id) => id.toString())
                      .toList() ??
                  [];

              // Sort members by priority: Owner -> Admins -> Joined Members
              final Map<String, dynamic> settings = roomData['settings'] as Map<String, dynamic>? ?? {};
              final List<dynamic> adminIdsRaw = settings['adminIds'] as List<dynamic>? ?? [];
              final Set<String> adminIdsSet = adminIdsRaw.map((id) => id.toString()).toSet();
              
              for (final p in participantsData) {
                if (p is Map && p['userId'] != null && (p['isHost'] == true)) {
                  adminIdsSet.add(p['userId'].toString());
                }
              }
              adminIdsSet.remove(creatorId);

              final List<String> sortedMemberUserIds = [];
              if (creatorId.isNotEmpty) {
                sortedMemberUserIds.add(creatorId);
              }

              final Set<String> activeOrJoinedUserIds = {
                ...joinedUserIds,
                ...participantsData.map((p) => (p as Map)['userId']?.toString()).whereType<String>()
              };

              final List<String> sortedAdmins = adminIdsSet
                  .where((id) => activeOrJoinedUserIds.contains(id))
                  .toList();
              sortedMemberUserIds.addAll(sortedAdmins);

              for (final String memberId in joinedUserIds) {
                if (memberId != creatorId && !sortedAdmins.contains(memberId)) {
                  sortedMemberUserIds.add(memberId);
                }
              }

              // Calculate room level from totalRevenue
              final int totalRevenue = roomData['totalRevenue'] ?? 0;
              final int roomLevel = AudioRoomV2.calculateRoomLevel(totalRevenue, _roomLevelConfigData);
              final double progress = AudioRoomV2.calculateLevelProgress(totalRevenue, roomLevel, _roomLevelConfigData);
              final int nextReq = AudioRoomV2.calculateNextLevelRequirement(roomLevel, _roomLevelConfigData);

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Premium Custom Header
                      _buildHeaderAppBar(roomName, creatorId, roomData),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                // Header Card Details
                                _buildRoomHeaderCard(
                                  roomName: roomName,
                                  roomImageUrl: roomImageUrl,
                                  creatorName: creatorName,
                                  roomLevel: roomLevel,
                                  progress: progress,
                                  joinedUserIds: joinedUserIds,
                                  totalRevenue: totalRevenue,
                                  nextRequirement: nextReq,
                                ),
                                const SizedBox(height: 24),
                                // Realtime Active Member List Section Title
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Room Members',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Obx(() {
                                          final displayId = Get.find<PremiumRoomService>().getDisplayId(widget.roomId);
                                          return Text(
                                          'Room ID: $displayId',
                                          style: TextStyle(
                                            color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        );
                                        }),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4AF37)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFD4AF37)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${sortedMemberUserIds.length} Members',
                                        style: const TextStyle(
                                          color: Color(0xFFD4AF37),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Live member list builders
                                if (sortedMemberUserIds.isEmpty)
                                  Container(
                                    height: 150,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'No members in room.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: sortedMemberUserIds.length,
                                    itemBuilder: (context, index) {
                                      final String memberUserId = sortedMemberUserIds[index];
                                      // Find active participant map to check if they are online inside the room
                                      final Map<String, dynamic>? activeParticipant = participantsData.firstWhere(
                                        (p) => (p as Map)['userId'] == memberUserId,
                                        orElse: () => null,
                                      ) as Map<String, dynamic>?;

                                      return _buildMemberListItem(
                                        memberUserId: memberUserId,
                                        activeParticipant: activeParticipant,
                                        creatorId: creatorId,
                                        joinedUserIds: joinedUserIds,
                                        roomData: roomData,
                                      );
                                    },
                                  ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.currentUserId != creatorId)
                        _buildBottomJoinButton(joinedUserIds),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAppBar(String roomName, String creatorId, Map<String, dynamic> roomData) {
    final bool isOwner = widget.currentUserId == creatorId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Room Members & Club',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final displayId = Get.find<PremiumRoomService>().getDisplayId(widget.roomId);
                  return Text(
                  'Room ID: $displayId',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                );
                }),
              ],
            ),
          ),
          if (isOwner)
            IconButton(
              onPressed: () => _showRoomSettingsBottomSheet(roomData),
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomHeaderCard({
    required String roomName,
    required String? roomImageUrl,
    required String creatorName,
    required int roomLevel,
    required double progress,
    required List<dynamic> joinedUserIds,
    required int totalRevenue,
    required int nextRequirement,
  }) {

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F1F2F).withValues(alpha: 0.95),
            const Color(0xFF14141F).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.06),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic details row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Image Container
              Hero(
                tag: 'room_image_${widget.roomId}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: roomImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(roomImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: roomImageUrl == null
                      ? const Icon(
                          Icons.meeting_room,
                          color: Color(0xFFD4AF37),
                          size: 36,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Title and agency info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.security,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Host: $creatorName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Room ID Card
                    GestureDetector(
                      onTap: () => _copyToClipboard(widget.roomId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ID: ',
                              style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Obx(() {
                              final displayId = Get.find<PremiumRoomService>().getDisplayId(widget.roomId);
                              return Text(
                              displayId,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            );
                            }),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.copy,
                              color: Colors.white54,
                              size: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Level + Join Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Level details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFE259),
                                Color(0xFFFFA751),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFA751).withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'Lv.$roomLevel',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Room Exp: ${(progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    '$totalRevenue / $nextRequirement 💎',
                                    style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Level progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.black26,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFD4AF37),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomJoinButton(List<String> joinedUserIds) {
    final bool isMember = joinedUserIds.contains(widget.currentUserId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: GestureDetector(
        onTap: _isJoiningAction ? null : () => _toggleJoinRoom(joinedUserIds),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isMember
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF9A7B1C)],
                  ),
            color: isMember ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 1.5,
            ),
            boxShadow: isMember
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: _isJoiningAction
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMember ? Icons.check_circle : Icons.add,
                      color: isMember ? const Color(0xFFD4AF37) : Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMember ? 'Joined Member Club' : 'Join Member Club',
                      style: TextStyle(
                        color: isMember ? const Color(0xFFD4AF37) : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMemberListItem({
    required String memberUserId,
    required Map<String, dynamic>? activeParticipant,
    required String creatorId,
    required List<dynamic> joinedUserIds,
    required Map<String, dynamic> roomData,
  }) {
    final Map<String, dynamic> settings = roomData['settings'] as Map<String, dynamic>? ?? {};
    final List<dynamic> adminIds = settings['adminIds'] as List<dynamic>? ?? [];
    final List<dynamic> participantsData = roomData['participants'] as List<dynamic>? ?? [];

    // Admin checking persistent settings first
    final bool pIsHost = adminIds.contains(memberUserId) || (activeParticipant?['isHost'] ?? false);
    final bool pIsSpeaker = activeParticipant?['isSpeaker'] ?? false;
    final bool isRoomOwner = memberUserId == creatorId;
    final bool isMemberOfClub = joinedUserIds.contains(memberUserId);
    final bool isOnlineInsideRoom = activeParticipant != null;

    final Map<String, dynamic> membersLastActiveMap = roomData['membersLastActive'] as Map<String, dynamic>? ?? {};
    DateTime? lastActiveTime;
    if (membersLastActiveMap.containsKey(memberUserId)) {
      final dynamic val = membersLastActiveMap[memberUserId];
      if (val is Timestamp) {
        lastActiveTime = val.toDate();
      } else if (val is int) {
        lastActiveTime = DateTime.fromMillisecondsSinceEpoch(val);
      }
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('Users').doc(memberUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 70,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                ),
              ),
            ),
          );
        }

        final Map<String, dynamic>? uData =
            snapshot.data?.data() as Map<String, dynamic>?;
        final String fullname = uData?['fullname'] ?? 'User';
        final String userImage = uData?['photoUrl'] ?? '';

        final Map? sendingLevelMap = uData?['sendingLevel'] as Map?;
        final int sendLvl = (sendingLevelMap?['level'] as num?)?.toInt() ?? 1;

        final Map? receivingLevelMap = uData?['receivingLevel'] as Map?;
        final int receiveLvl =
            (receivingLevelMap?['level'] as num?)?.toInt() ?? 1;

        final int activeSvipLevel = uData?['activeSvipLevel'] as int? ?? 0;
        final String svipValidUntilMonth = uData?['svipValidUntilMonth'] as String? ?? '';

        // Fallback to user's global lastActive field
        if (lastActiveTime == null && uData?['lastActive'] != null) {
          final dynamic lastActiveVal = uData?['lastActive'];
          if (lastActiveVal is int) {
            lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActiveVal);
          } else if (lastActiveVal is Timestamp) {
            lastActiveTime = lastActiveVal.toDate();
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              final bool currentUserIsOwner = widget.currentUserId == creatorId;
              final bool currentUserIsAdmin = adminIds.contains(widget.currentUserId);
              
              if ((currentUserIsOwner || currentUserIsAdmin) && memberUserId != creatorId) {
                // If owner or admin taps a member, show moderation bottom sheet
                _showAdminOptionsBottomSheet(
                  memberUserId: memberUserId,
                  fullname: fullname,
                  userImageUrl: userImage,
                  pIsHost: pIsHost,
                  adminIds: adminIds,
                  participantsData: participantsData,
                  isCurrentUserOwner: currentUserIsOwner,
                  activeParticipant: activeParticipant,
                );
              } else {
                // Otherwise navigate to their profile directly
                _navigateToProfile(
                  memberUserId: memberUserId,
                  fullname: fullname,
                  userImageUrl: userImage,
                  isOnline: isOnlineInsideRoom,
                  lastActive: lastActiveTime,
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CachedCircleAvatar(
                      imageUrl: userImage,
                      radius: 22,
                      userId: memberUserId,
                      isOnline: isOnlineInsideRoom,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: AnimatedSvipName(
                                name: fullname,
                                activeSvipLevel: activeSvipLevel,
                                svipValidUntilMonth: svipValidUntilMonth,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Role/Official Badges
                            if (isRoomOwner)
                              _buildPremiumBadge(
                                'Owner',
                                [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                                Colors.black,
                              )
                            else if (pIsHost)
                              _buildPremiumBadge(
                                'Admin',
                                [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                                Colors.white,
                              )
                            else if (pIsSpeaker)
                              _buildBadgePill('Mic', Colors.tealAccent)
                            else if (isMemberOfClub)
                              _buildBadgePill('Member', Colors.blueAccent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Sending Level badge
                            _buildLevelPill('Send', sendLvl, const Color(0xFFFFD700)),
                            const SizedBox(width: 8),
                            // Receiving Level badge
                            _buildLevelPill('Recv', receiveLvl, const Color(0xFFEA4C89)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              isOnlineInsideRoom ? Icons.circle : Icons.access_time_rounded,
                              color: isOnlineInsideRoom ? Colors.greenAccent : Colors.white38,
                              size: isOnlineInsideRoom ? 10 : 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnlineInsideRoom ? 'Active now' : _formatLastActive(lastActiveTime),
                              style: TextStyle(
                                color: isOnlineInsideRoom ? Colors.greenAccent : Colors.white38,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOnlineInsideRoom)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumBadge(String label, List<Color> gradientColors, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.35),
            blurRadius: 5,
            spreadRadius: 0.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'Last active long ago';
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inSeconds < 60) {
      return 'Last active just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Last active $minutes ${minutes == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Last active $hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays == 1) {
      return 'Last active yesterday';
    } else {
      final days = difference.inDays;
      return 'Last active $days ${days == 1 ? "day" : "days"} ago';
    }
  }

  void _showAdminOptionsBottomSheet({
    required String memberUserId,
    required String fullname,
    required String userImageUrl,
    required bool pIsHost,
    required List<dynamic> adminIds,
    required List<dynamic> participantsData,
    required bool isCurrentUserOwner,
    dynamic activeParticipant,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14141F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicator handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Manage $fullname',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // View Profile option
              ListTile(tileColor: Colors.transparent,
                leading: const Icon(Icons.person, color: Colors.blueAccent),
                title: const Text('View Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToProfile(
                    memberUserId: memberUserId,
                    fullname: fullname,
                    userImageUrl: userImageUrl,
                    isOnline: participantsData.any((p) => p['userId'] == memberUserId),
                    lastActive: DateTime.now(),
                  );
                },
              ),

              // Promote/Demote Admin option (Owner Only)
              if (isCurrentUserOwner)
                ListTile(tileColor: Colors.transparent,
                  leading: Icon(
                    pIsHost ? Icons.shield_outlined : Icons.shield,
                    color: pIsHost ? Colors.orangeAccent : Colors.purpleAccent,
                  ),
                  title: Text(
                    pIsHost ? 'Dismiss Admin Role' : 'Make Admin',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _toggleAdminStatus(memberUserId, !pIsHost, adminIds, participantsData);
                  },
                ),

              // Mute/Unmute Mic
              ListTile(tileColor: Colors.transparent,
                leading: Icon(
                  activeParticipant != null && activeParticipant['isMutedByAdmin'] == true
                      ? Icons.mic_off
                      : Icons.mic,
                  color: Colors.white,
                ),
                title: Text(
                  activeParticipant != null && activeParticipant['isMutedByAdmin'] == true
                      ? 'Unmute Mic'
                      : 'Mute Mic',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final bool currentlyMuted = activeParticipant != null && activeParticipant['isMutedByAdmin'] == true;
                  await _toggleAdminMute(memberUserId, !currentlyMuted);
                },
              ),

              // Block/Unblock Message
              ListTile(tileColor: Colors.transparent,
                leading: Icon(
                  activeParticipant != null && activeParticipant['isMessagingBlocked'] == true
                      ? Icons.chat_bubble_outline
                      : Icons.chat_bubble,
                  color: Colors.white,
                ),
                title: Text(
                  activeParticipant != null && activeParticipant['isMessagingBlocked'] == true
                      ? 'Unblock Message'
                      : 'Block Message',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final bool currentlyBlocked = activeParticipant != null && activeParticipant['isMessagingBlocked'] == true;
                  await _toggleMessagingBlock(memberUserId, !currentlyBlocked);
                },
              ),

              // Block/Unblock Seat Access
              ListTile(tileColor: Colors.transparent,
                leading: Icon(
                  activeParticipant != null && activeParticipant['isSeatBlocked'] == true
                      ? Icons.event_seat_outlined
                      : Icons.event_seat,
                  color: Colors.white,
                ),
                title: Text(
                  activeParticipant != null && activeParticipant['isSeatBlocked'] == true
                      ? 'Unblock Seat Access'
                      : 'Block Seat Access',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final bool currentlyBlocked = activeParticipant != null && activeParticipant['isSeatBlocked'] == true;
                  await _toggleSeatBlock(memberUserId, !currentlyBlocked);
                },
              ),

              // Kick from room option
              ListTile(tileColor: Colors.transparent,
                leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                title: const Text('Remove from Room', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  _showKickDialog(memberUserId, fullname);
                },
              ),

              // Block from room option
              ListTile(tileColor: Colors.transparent,
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block from Room', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  _showBlockDialog(memberUserId, fullname);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _navigateToProfile({
    required String memberUserId,
    required String fullname,
    required String userImageUrl,
    required bool isOnline,
    required DateTime? lastActive,
  }) {
    String activityInfo = isOnline ? 'Active now' : _formatLastActive(lastActive);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfilePageForRoom(
          userID: memberUserId,
          userName: fullname,
          userImage: userImageUrl,
          roomActivityInfo: activityInfo,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _showKickDialog(String memberUserId, String fullname) async {
    final TextEditingController reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $fullname', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to remove this user from the room?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason (Optional)',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _kickParticipantAction(memberUserId, reasonController.text);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockDialog(String memberUserId, String fullname) async {
    final TextEditingController reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block $fullname', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to block this user from entering the room?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason (Optional)',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _blockParticipantAction(memberUserId, reasonController.text);
            },
            child: const Text('Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _kickParticipantAction(String targetUserId, String reason) async {
    try {
      final DocumentReference roomRef = FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(widget.roomId);

      // Get fresh data
      final doc = await roomRef.get().timeout(const Duration(seconds: 15));
      if (!doc.exists) return;

      final roomData = doc.data() as Map<String, dynamic>;
      final List<dynamic> participants = List.from(roomData['participants'] ?? []);

      // Find the participant to kick
      final targetIndex = participants.indexWhere((p) => p['userId'] == targetUserId);
      Map<String, dynamic>? targetParticipant;
      if (targetIndex != -1) {
        targetParticipant = Map<String, dynamic>.from(participants[targetIndex]);
        // Remove participant from room
        participants.removeAt(targetIndex);
      }

      // Record in removedUsers log
      final List<dynamic> currentRemovedUsers = List.from(roomData['removedUsers'] ?? []);
      currentRemovedUsers.add({
        'userId': targetUserId,
        'userName': targetParticipant?['userName'] ?? 'User',
        'userImageUrl': targetParticipant?['userImageUrl'] ?? '',
        'removedAt': Timestamp.now(),
        'removedBy': widget.currentUserId,
        'reason': reason.isNotEmpty ? reason : 'Removed by owner',
      });

      // Clear from seats
      final Map<String, dynamic> settings = Map<String, dynamic>.from(roomData['settings'] ?? {});
      final List<dynamic> seatConfig = List.from(settings['seatConfiguration'] ?? []);
      final updatedSeatConfig = seatConfig.map((seat) {
        final Map<String, dynamic> s = Map<String, dynamic>.from(seat);
        if (s['occupiedBy'] == targetUserId) {
          s['occupiedBy'] = null;
        }
        return s;
      }).toList();
      settings['seatConfiguration'] = updatedSeatConfig;

      await roomRef.update({
        'participants': participants,
        'removedUsers': currentRemovedUsers,
        'settings': settings,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully removed user from the room'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error kicking participant: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _blockParticipantAction(String targetUserId, String reason) async {
    try {
      final DocumentReference roomRef = FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(widget.roomId);

      // Get fresh data
      final doc = await roomRef.get().timeout(const Duration(seconds: 15));
      if (!doc.exists) return;

      final roomData = doc.data() as Map<String, dynamic>;
      final List<dynamic> participants = List.from(roomData['participants'] ?? []);

      // Find the participant to kick
      final targetIndex = participants.indexWhere((p) => p['userId'] == targetUserId);
      Map<String, dynamic>? targetParticipant;
      if (targetIndex != -1) {
        targetParticipant = Map<String, dynamic>.from(participants[targetIndex]);
        // Remove participant from room
        participants.removeAt(targetIndex);
      }

      final Map<String, dynamic> settings = Map<String, dynamic>.from(roomData['settings'] ?? {});
      final List<dynamic> blockedUsers = List.from(settings['blockedUsers'] ?? []);
      
      blockedUsers.add({
        'userId': targetUserId,
        'userName': targetParticipant?['userName'] ?? 'User',
        'userImageUrl': targetParticipant?['userImageUrl'] ?? '',
        'blockedAt': Timestamp.now(),
        'blockedBy': widget.currentUserId,
        'reason': reason.isNotEmpty ? reason : 'Blocked by admin',
      });
      settings['blockedUsers'] = blockedUsers;

      // Clear from seats
      final List<dynamic> seatConfig = List.from(settings['seatConfiguration'] ?? []);
      final updatedSeatConfig = seatConfig.map((seat) {
        final Map<String, dynamic> s = Map<String, dynamic>.from(seat);
        if (s['occupiedBy'] == targetUserId) {
          s['occupiedBy'] = null;
        }
        return s;
      }).toList();
      settings['seatConfiguration'] = updatedSeatConfig;

      await roomRef.update({
        'participants': participants,
        'settings': settings,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully blocked user from the room'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error blocking participant: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleAdminMute(String targetUserId, bool muted) async {
    try {
      await AudioRoomsRepository().toggleAdminMute(widget.roomId, targetUserId, muted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(muted ? 'User mic has been muted' : 'User mic has been unmuted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error toggling admin mute: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update mic status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleMessagingBlock(String targetUserId, bool blocked) async {
    try {
      await AudioRoomsRepository().toggleMessagingBlock(widget.roomId, targetUserId, blocked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blocked ? 'User has been blocked from messaging' : 'User has been unblocked from messaging'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error toggling messaging block: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update messaging status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleSeatBlock(String targetUserId, bool blocked) async {
    try {
      await AudioRoomsRepository().toggleSeatBlock(widget.roomId, targetUserId, blocked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blocked ? 'User seat access has been blocked' : 'User seat access has been unblocked'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error toggling seat block: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update seat access status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleAdminStatus(
    String targetUserId,
    bool makeAdmin,
    List<dynamic> adminIds,
    List<dynamic> participantsData,
  ) async {
    try {
      final DocumentReference roomRef = FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(widget.roomId);

      final List<dynamic> updatedAdminIds = List.from(adminIds);
      if (makeAdmin) {
        if (!updatedAdminIds.contains(targetUserId)) {
          updatedAdminIds.add(targetUserId);
        }
      } else {
        updatedAdminIds.remove(targetUserId);
      }

      // Also update the active participant's isHost field in the active list
      final List<dynamic> updatedParticipants = participantsData.map((p) {
        final Map<String, dynamic> participant = Map<String, dynamic>.from(p as Map);
        if (participant['userId'] == targetUserId) {
          participant['isHost'] = makeAdmin;
        }
        return participant;
      }).toList();

      await roomRef.update({
        'settings.adminIds': updatedAdminIds,
        'participants': updatedParticipants,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(makeAdmin
              ? 'Promoted user to Admin successfully!'
              : 'Dismissed Admin role successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBadgePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildLevelPill(String type, int level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Text(
        '$type. $level',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  void _showRoomSettingsBottomSheet(Map<String, dynamic> roomData) {
    final String creatorId = roomData['creatorId'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F15),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                // Pull bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Room Control Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Custom Premium TabBar
                const TabBar(
                  indicatorColor: Color(0xFFD4AF37),
                  labelColor: Color(0xFFD4AF37),
                  unselectedLabelColor: Colors.white54,
                  indicatorWeight: 3,
                  isScrollable: true,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                  tabs: [
                    Tab(
                      icon: Icon(Icons.campaign_rounded, size: 20),
                      text: 'Announcement',
                    ),
                    Tab(
                      icon: Icon(Icons.people_alt_rounded, size: 20),
                      text: 'Members',
                    ),
                    Tab(
                      icon: Icon(Icons.block_flipped, size: 20),
                      text: 'Blocked',
                    ),
                    Tab(
                      icon: Icon(Icons.history_rounded, size: 20),
                      text: 'Kicked',
                    ),
                    Tab(
                      icon: Icon(Icons.category_rounded, size: 20),
                      text: 'Category',
                    ),
                  ],
                ),
                
                const Divider(color: Colors.white10, height: 1),
                
                // Tab Views
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('audio_rooms_v2')
                        .doc(widget.roomId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                          ),
                        );
                      }
                      
                      final currentRoomData = snapshot.data!.data() as Map<String, dynamic>;
                      final Map<String, dynamic> settings = currentRoomData['settings'] as Map<String, dynamic>? ?? {};
                      final String? announcement = settings['announcement'];
                      final String roomCategory = currentRoomData['category'] ?? 'Game';
                      final List<dynamic> blockedUsersRaw = settings['blockedUsers'] as List<dynamic>? ?? [];
                      final List<dynamic> removedUsersRaw = currentRoomData['removedUsers'] as List<dynamic>? ?? [];
                      final List<dynamic> latestJoinedIds = (currentRoomData['joinedUserIds'] as List<dynamic>?)
                              ?.where((id) => id != null)
                              .map((id) => id.toString())
                              .toList() ??
                          [];
                      
                      return TabBarView(
                        children: [
                          // Announcement Tab
                          _buildAnnouncementTab(announcement),
                          
                          // Settings Members management tab
                          _buildSettingsMembersTab(latestJoinedIds, creatorId, currentRoomData),
                          
                          // Blocked Users Tab
                          _buildBlockedUsersTab(blockedUsersRaw),
                          
                          // Kick History Tab
                          _buildKickHistoryTab(removedUsersRaw),

                          // Room Category Tab
                          _buildRoomCategoryTab(roomCategory),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomCategoryTab(String currentCategory) {
    return StatefulBuilder(
      builder: (context, setTabState) {
        _selectedCategoryForEdit ??= currentCategory;

        final categories = [
          {'name': 'Game', 'emoji': '🎮'},
          {'name': 'PK', 'emoji': '⚔️'},
          {'name': 'Event', 'emoji': '🏆'},
          {'name': 'Islamic', 'emoji': '☪️'},
          {'name': 'Talk Show', 'emoji': '🎤'},
        ];

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Room Category',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a category to help users find your room in the Explore section.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final name = cat['name']!;
                    final emoji = cat['emoji']!;
                    final isSelected = _selectedCategoryForEdit == name;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD4AF37)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: ListTile(tileColor: Colors.transparent,
                        onTap: () {
                          setTabState(() {
                            _selectedCategoryForEdit = name;
                          });
                        },
                        leading: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37))
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFF9A7B1C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('audio_rooms_v2')
                            .doc(widget.roomId)
                            .update({
                          'category': _selectedCategoryForEdit,
                        });
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room category updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update category: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text(
                      'Update Room Category',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementTab(String? announcement) {
    final TextEditingController announcementController = TextEditingController(text: announcement);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Announcement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set a welcome message or rule list for anyone entering the room. This will be prominently displayed at the top of the room.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: TextField(
                controller: announcementController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
                decoration: InputDecoration(
                  hintText: 'Enter announcement here...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () => announcementController.clear(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFF9A7B1C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('audio_rooms_v2')
                        .doc(widget.roomId)
                        .update({
                      'settings.announcement': announcementController.text.trim(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Announcement updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update announcement: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text(
                  'Update Announcement',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersTab(List<dynamic> blockedUsersRaw) {
    if (blockedUsersRaw.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_flipped, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'No blocked users in this room.',
              style: TextStyle(color: Colors.white30, fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blockedUsersRaw.length,
      itemBuilder: (context, index) {
        final Map<String, dynamic> blocked = Map<String, dynamic>.from(blockedUsersRaw[index]);
        final String userName = blocked['userName'] ?? 'User';
        final String? userImageUrl = blocked['userImageUrl'];
        final String reason = blocked['reason'] ?? 'Removed by host';
        final DateTime blockedAt = blocked['blockedAt'] is Timestamp
            ? (blocked['blockedAt'] as Timestamp).toDate()
            : DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(tileColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: userImageUrl != null && userImageUrl.isNotEmpty
                  ? NetworkImage(userImageUrl)
                  : null,
              child: userImageUrl == null || userImageUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white30)
                  : null,
            ),
            title: Text(
              userName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Inter'),
                ),
                Text(
                  'Blocked: ${_formatSettingsDateTime(blockedAt)}',
                  style: const TextStyle(color: Colors.white30, fontSize: 10, fontFamily: 'Inter'),
                ),
              ],
            ),
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
              ),
              onPressed: () async {
                try {
                  final List<dynamic> updatedBlockedUsers = List.from(blockedUsersRaw);
                  updatedBlockedUsers.removeAt(index);
                  
                  await FirebaseFirestore.instance
                      .collection('audio_rooms_v2')
                      .doc(widget.roomId)
                      .update({
                    'settings.blockedUsers': updatedBlockedUsers,
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unblocked $userName successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  // Trigger official unban/unblock notification
                  final String? targetUserId = blocked['userId']?.toString();
                  if (targetUserId != null) {
                    try {
                      final unbannedUser = await UserApi.getUser(targetUserId);
                      if (unbannedUser != null) {
                        await OfficialTeamApi.sendUnbanMessage(unbannedUser);
                      }
                    } catch (ex) {
                      debugPrint('Error sending official unban notification: $ex');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to unblock: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKickHistoryTab(List<dynamic> removedUsersRaw) {
    if (removedUsersRaw.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'No kick history in this room.',
              style: TextStyle(color: Colors.white30, fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: removedUsersRaw.length,
      itemBuilder: (context, index) {
        final Map<String, dynamic> removed = Map<String, dynamic>.from(removedUsersRaw[index]);
        final String userName = removed['userName'] ?? 'User';
        final String? userImageUrl = removed['userImageUrl'];
        final String reason = removed['reason'] ?? 'Kicked by owner';
        final DateTime removedAt = removed['removedAt'] is Timestamp
            ? (removed['removedAt'] as Timestamp).toDate()
            : DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(tileColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: userImageUrl != null && userImageUrl.isNotEmpty
                  ? NetworkImage(userImageUrl)
                  : null,
              child: userImageUrl == null || userImageUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white30)
                  : null,
            ),
            title: Text(
              userName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Inter'),
                ),
                Text(
                  'Kicked: ${_formatSettingsDateTime(removedAt)}',
                  style: const TextStyle(color: Colors.white30, fontSize: 10, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsMembersTab(List<dynamic> joinedUserIdsRaw, String creatorId, Map<String, dynamic> roomData) {
    final Map<String, dynamic> settings = roomData['settings'] as Map<String, dynamic>? ?? {};
    final List<dynamic> adminIds = settings['adminIds'] as List<dynamic>? ?? [];
    final List<dynamic> participantsData = roomData['participants'] as List<dynamic>? ?? [];

    final List<String> joinedUserIds = joinedUserIdsRaw
            .where((id) => id != null)
            .map((id) => id.toString())
            .toList();

    // Build the sorted list of room member IDs (Owner -> Admins -> Joined Members)
    final Set<String> adminIdsSet = adminIds.map((id) => id.toString()).toSet();
    
    for (final p in participantsData) {
      if (p is Map && p['userId'] != null && (p['isHost'] == true)) {
        adminIdsSet.add(p['userId'].toString());
      }
    }
    adminIdsSet.remove(creatorId);

    final List<String> sortedMemberUserIds = [];

    // 1. Room Owner (Always First)
    if (creatorId.isNotEmpty) {
      sortedMemberUserIds.add(creatorId);
    }

    // 2. Admins
    final Set<String> activeOrJoinedUserIds = {
      ...joinedUserIds,
      ...participantsData.map((p) => (p as Map)['userId']?.toString()).whereType<String>()
    };

    final List<String> sortedAdmins = adminIdsSet
        .where((id) => activeOrJoinedUserIds.contains(id))
        .toList();
    sortedMemberUserIds.addAll(sortedAdmins);

    // 3. Joined Room Members
    for (final String memberId in joinedUserIds) {
      if (memberId != creatorId && !sortedAdmins.contains(memberId)) {
        sortedMemberUserIds.add(memberId);
      }
    }

    return Column(
      children: [
        Expanded(
          child: sortedMemberUserIds.isEmpty
              ? const Center(
                  child: Text(
                    'No members found.',
                    style: TextStyle(color: Colors.white30, fontFamily: 'Inter'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedMemberUserIds.length,
                  itemBuilder: (context, index) {
                    final String memberUserId = sortedMemberUserIds[index];
                    final Map<String, dynamic>? activeParticipant = participantsData.firstWhere(
                      (p) => (p as Map)['userId'] == memberUserId,
                      orElse: () => null,
                    ) as Map<String, dynamic>?;

                    final bool pIsHost = adminIds.contains(memberUserId) || (activeParticipant?['isHost'] ?? false);
                    final bool isRoomOwner = memberUserId == creatorId;
                    final bool isOnlineInsideRoom = activeParticipant != null;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('Users').doc(memberUserId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: 70,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                ),
                              ),
                            ),
                          );
                        }

                        final Map<String, dynamic>? uData = snapshot.data?.data() as Map<String, dynamic>?;
                        final String fullname = uData?['fullname'] ?? 'User';
                        final String userImage = uData?['photoUrl'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(tileColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: userImage.isNotEmpty ? NetworkImage(userImage) : null,
                  child: userImage.isEmpty ? const Icon(Icons.person, color: Colors.white30) : null,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isRoomOwner)
                      _buildPremiumBadge(
                        'Owner',
                        [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                        Colors.black,
                      )
                    else if (pIsHost)
                      _buildPremiumBadge(
                        'Admin',
                        [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                        Colors.white,
                      ),
                  ],
                ),
                subtitle: Text(
                  isOnlineInsideRoom ? 'Active now inside room' : 'Offline / Outside room',
                  style: TextStyle(
                    color: isOnlineInsideRoom ? Colors.green : Colors.white30,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                trailing: isRoomOwner
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune, color: Color(0xFFD4AF37)),
                            onPressed: () {
                              _showAdminOptionsBottomSheet(
                                memberUserId: memberUserId,
                                fullname: fullname,
                                userImageUrl: userImage,
                                pIsHost: pIsHost,
                                adminIds: adminIds,
                                participantsData: participantsData,
                                isCurrentUserOwner: widget.currentUserId == creatorId,
                                activeParticipant: activeParticipant,
                              );
                            },
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    ),
  ),
  ],
);
}
  String _formatSettingsDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
