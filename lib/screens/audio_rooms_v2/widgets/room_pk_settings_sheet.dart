import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/room_pk_repository.dart';

class RoomPKSettingsSheet extends StatefulWidget {
  final AudioRoomV2 room;

  const RoomPKSettingsSheet({super.key, required this.room});

  @override
  State<RoomPKSettingsSheet> createState() => _RoomPKSettingsSheetState();
}

class _RoomPKSettingsSheetState extends State<RoomPKSettingsSheet> {
  final RoomPKRepository _pkRepository = RoomPKRepository();
  final TextEditingController _roomIdController = TextEditingController();
  
  bool _isAutoMatching = false;
  bool _isInviting = false;
  int _selectedDuration = 5; // default 5 minutes
  
  final List<int> _durations = [3, 5, 10, 15];

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  void _sendInvite() async {
    final targetRoomId = _roomIdController.text.trim();
    if (targetRoomId.isEmpty) {
      Get.snackbar('Error', 'Please enter a Room ID');
      return;
    }

    setState(() => _isInviting = true);

    try {
      await _pkRepository.sendInvite(
        senderRoomId: widget.room.id,
        targetRoomId: targetRoomId,
        senderRoomName: widget.room.name,
        senderRoomImageUrl: widget.room.imageUrl ?? '',
        durationMinutes: _selectedDuration,
      );
      if (mounted) {
        Navigator.pop(context);
      }
      Get.snackbar('Success', 'PK Invite sent to Room $targetRoomId');
    } catch (e) {
      if (mounted) {
        setState(() => _isInviting = false);
      }
      Get.snackbar('Error', 'Failed to send invite');
    }
  }

  void _toggleAutoMatch() async {
    if (_isAutoMatching) {
      // Cancel
      setState(() => _isAutoMatching = false);
      await _pkRepository.leaveAutoMatchQueue(widget.room.id);
    } else {
      // Start Auto Match
      setState(() => _isAutoMatching = true);
      try {
        await _pkRepository.enterAutoMatchQueue(
          roomId: widget.room.id,
          roomName: widget.room.name,
          roomImageUrl: widget.room.imageUrl ?? '',
          durationMinutes: _selectedDuration,
        );
        // We do NOT pop the dialog immediately so they can see it's matching.
        // In a full implementation, we'd listen for the match here and then pop.
      } catch (e) {
        setState(() => _isAutoMatching = false);
        Get.snackbar('Error', 'Failed to enter Auto Match');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Room vs Room PK',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Duration Selection
          const Text(
            'PK Duration',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _durations.map((duration) {
              final isSelected = _selectedDuration == duration;
              return GestureDetector(
                onTap: () => setState(() => _selectedDuration = duration),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$duration min',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          
          // Option 1: Search and Invite
          const Text(
            'Invite by Room ID',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Room ID...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (_isAutoMatching || _isInviting) ? null : _sendInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInviting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Divider
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 30),
          
          // Option 2: Auto Match
          ElevatedButton(
            onPressed: _toggleAutoMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAutoMatching ? Colors.orangeAccent : Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isAutoMatching 
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16, height: 16, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    ),
                    SizedBox(width: 12),
                    Text('Matching...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                )
              : const Text('Auto Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
