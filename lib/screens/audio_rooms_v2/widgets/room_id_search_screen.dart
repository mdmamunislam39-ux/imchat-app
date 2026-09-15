import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/services/premium_room_service.dart';

class RoomIdSearchScreen extends StatefulWidget {
  final AudioRoomsBloc audioRoomsBloc;
  const RoomIdSearchScreen({super.key, required this.audioRoomsBloc});

  @override
  State<RoomIdSearchScreen> createState() => _RoomIdSearchScreenState();
}

class _RoomIdSearchScreenState extends State<RoomIdSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;
  AudioRoomV2? _foundRoom;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchById() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundRoom = null;
      _errorMessage = null;
    });

    try {
      final premiumService = PremiumRoomService.instance;
      final targetRoomId = await premiumService.resolveRoomId(id);

      if (!mounted) return;

      if (targetRoomId != null) {
        // We found an exact match either by document ID or custom short ID
        final doc = await FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .doc(targetRoomId)
            .get(const GetOptions(source: Source.server));

        if (doc.exists) {
          final room = AudioRoomV2.fromFirestore(doc);
          if (!room.isActive) {
            setState(() {
              _errorMessage = 'Room is no longer active.';
              _isSearching = false;
            });
          } else {
            setState(() {
              _foundRoom = room;
              _isSearching = false;
            });
          }
          return;
        }
      }

      // Fallback — search by short prefix of original ID
      final prefixQuery = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: id)
          .where(FieldPath.documentId, isLessThanOrEqualTo: '$id\uf8ff')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      if (prefixQuery.docs.isNotEmpty) {
        final room = AudioRoomV2.fromFirestore(prefixQuery.docs.first);
        setState(() {
          _foundRoom = room;
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No room found with ID: $id';
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search failed. Please try again.';
        _isSearching = false;
      });
    }
  }

  void _enterRoom(AudioRoomV2 room) {
    final currentUser = AuthController.instance.currentUser;

    MinimizedRoomController.checkAndProceed(
      context: context,
      targetRoom: room,
      onProceed: () {
        if (!room.isParticipant(currentUser.userId)) {
          widget.audioRoomsBloc.add(JoinAudioRoom(
            roomId: room.id,
            userId: currentUser.userId,
            userName: currentUser.fullname,
            userImageUrl: currentUser.photoUrl,
            userFrameId: currentUser.customization?.selectedFrameId,
          ));
        }

        Navigator.of(context).pop(); // Close search screen
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AudioRoomScreen(room: room, audioRoomsBloc: widget.audioRoomsBloc),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0917) : const Color(0xFFF7F8FA);
    final appBarColor = isDark ? const Color(0xFF120C1C) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E162B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[700]!;
    final hintColor = isDark ? Colors.white38 : Colors.grey[400]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          '🔍 Search by Room ID',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Room ID',
              style: TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            // Search Input
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? primaryColor.withValues(alpha: 0.4) : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(IconlyLight.search, color: isDark ? Colors.white70 : Colors.grey[600], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor, fontSize: 16, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                      cursorColor: primaryColor,
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'e.g. 12345678',
                        hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.normal),
                      ),
                      onSubmitted: (_) => _searchById(),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, color: isDark ? Colors.white70 : Colors.grey[600], size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _foundRoom = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Search Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _searchById,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 20),
                label: Text(_isSearching ? 'Searching...' : 'Find Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Error
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            // Room Result
            if (_foundRoom != null) ...[
              const Text(
                'Room Found',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _enterRoom(_foundRoom!),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFF311B92)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Room image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _foundRoom!.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _foundRoom!.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundRoom!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Host: ${_foundRoom!.creatorName}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.people, color: Colors.white38, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${_foundRoom!.participantCount} members',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    '● LIVE',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Enter',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Hint
            Center(
              child: Text(
                'Room IDs are 7–8 digit numbers\nassigned when a room is created.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.meeting_room, color: Color(0xFFD4AF37), size: 28),
    );
  }
}
