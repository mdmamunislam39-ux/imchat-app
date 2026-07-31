import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chat_messenger/models/audio_room_v2.dart';

class AdminRoomBanManagementScreen extends StatefulWidget {
  const AdminRoomBanManagementScreen({super.key});

  @override
  State<AdminRoomBanManagementScreen> createState() => _AdminRoomBanManagementScreenState();
}

class _AdminRoomBanManagementScreenState extends State<AdminRoomBanManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  AudioRoomV2? _foundRoom;
  String? _errorMessage;

  Future<void> _searchRoom() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundRoom = null;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(query)
          .get();

      if (doc.exists) {
        setState(() {
          _foundRoom = AudioRoomV2.fromFirestore(doc);
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _errorMessage = 'No room found with that ID.';
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _toggleBan(bool banStatus) async {
    if (_foundRoom == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(_foundRoom!.id)
          .update({'isBanned': banStatus});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(banStatus ? 'Room banned successfully!' : 'Room unbanned successfully!'),
          backgroundColor: banStatus ? Colors.redAccent : Colors.green,
        ),
      );

      // Refresh room
      _searchRoom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update ban status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        title: const Text('Room Ban Management', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF1E142B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Room ID',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A1B38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    ),
                    onSubmitted: (_) => _searchRoom(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: _isSearching 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Search', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),

            if (_foundRoom != null) ...[
              Card(
                color: const Color(0xFF2A1B38),
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: _foundRoom!.imageUrl != null 
                              ? NetworkImage(_foundRoom!.imageUrl!)
                              : null,
                            backgroundColor: Colors.purple.withValues(alpha: 0.3),
                            child: _foundRoom!.imageUrl == null
                                ? const Icon(Icons.meeting_room, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundRoom!.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Room ID: ${_foundRoom!.id}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                                ),
                                Text(
                                  'Creator ID: ${_foundRoom!.creatorId}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Room Status:', style: TextStyle(color: Colors.white, fontSize: 16)),
                          Chip(
                            label: Text(
                              _foundRoom!.isBanned ? 'BANNED' : 'ACTIVE',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _foundRoom!.isBanned ? Colors.redAccent : Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _toggleBan(!_foundRoom!.isBanned),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _foundRoom!.isBanned ? Colors.green : Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            _foundRoom!.isBanned ? 'UNBAN ROOM' : 'BAN ROOM',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
