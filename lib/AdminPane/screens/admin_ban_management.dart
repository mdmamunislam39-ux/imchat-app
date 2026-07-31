import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/AdminPane/screens/admin_room_ban_management.dart';

class AdminBanManagementScreen extends StatefulWidget {
  const AdminBanManagementScreen({super.key});

  @override
  State<AdminBanManagementScreen> createState() => _AdminBanManagementScreenState();
}

class _AdminBanManagementScreenState extends State<AdminBanManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  User? _foundUser;
  String? _errorMessage;

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(query).get();
      if (doc.exists) {
        setState(() {
          _foundUser = User.fromMap(doc.data()!);
        });
      } else {
        // Try searching by phone number
        final phoneQuery = await FirebaseFirestore.instance
            .collection('Users')
            .where('number', isEqualTo: query)
            .limit(1)
            .get();
        if (!mounted) return;
        if (phoneQuery.docs.isNotEmpty) {
          setState(() {
            _foundUser = User.fromMap(phoneQuery.docs.first.data());
          });
        } else {
          setState(() {
            _errorMessage = 'User not found';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching user: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _applyBan(String type, int hours) async {
    if (_foundUser == null) return;

    try {
      final endTime = hours == -1 ? null : DateTime.now().add(Duration(hours: hours));
      final isPermanent = hours == -1;

      UserBanStatus currentStatus = _foundUser!.banStatus ?? UserBanStatus();

      switch (type) {
        case 'Login':
          currentStatus.loginBanEndTime = endTime;
          currentStatus.isLoginBanPermanent = isPermanent;
          break;
        case 'Mic':
          currentStatus.micBanEndTime = endTime;
          currentStatus.isMicBanPermanent = isPermanent;
          break;
        case 'Chat':
          currentStatus.chatBanEndTime = endTime;
          currentStatus.isChatBanPermanent = isPermanent;
          break;
        case 'Device':
          // Fetch the user's device ID from device_sessions
          final sessionSnapshot = await FirebaseFirestore.instance
              .collection('device_sessions')
              .where('userId', isEqualTo: _foundUser!.userId)
              .get();
          
          if (sessionSnapshot.docs.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active device found for this user.')));
            return;
          }
          
          for (var doc in sessionSnapshot.docs) {
            await FirebaseFirestore.instance.collection('banned_devices').doc(doc.id).set({
              'isPermanent': isPermanent,
              'expiresAt': endTime != null ? Timestamp.fromDate(endTime) : null,
              'bannedAt': FieldValue.serverTimestamp(),
              'userId': _foundUser!.userId, // keeping reference
            });
            
            // Optionally, mark session as inactive so they get logged out immediately if DeviceSessionService handles it.
            // But we already added BanService.isDeviceBanned() on startup. To log out immediately, we can mark isActive: false.
            await doc.reference.update({'isActive': false});
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device Ban applied successfully!')),
          );
          OfficialTeamApi.sendOfficialMessage(
            receiverId: _foundUser!.userId,
            receiverDeviceToken: _foundUser!.deviceToken,
            messageText: 'Your device has been banned from accessing the app.',
          );
          return;
      }

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_foundUser!.userId)
          .update({'banStatus': currentStatus.toMap()});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type Ban applied successfully!')),
      );

      final durationText = isPermanent 
          ? 'permanently' 
          : (endTime != null ? 'until ${DateFormat('MMM dd, yyyy HH:mm').format(endTime)}' : 'temporarily');
      
      OfficialTeamApi.sendOfficialMessage(
        receiverId: _foundUser!.userId,
        receiverDeviceToken: _foundUser!.deviceToken,
        messageText: 'Your account has received a $type ban $durationText due to violations of community guidelines.',
      );

      _searchUser(); // refresh user
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply ban: $e')),
      );
    }
  }

  Future<void> _removeBan(String type) async {
    if (_foundUser == null) return;

    try {
      UserBanStatus currentStatus = _foundUser!.banStatus ?? UserBanStatus();
      
      switch (type) {
        case 'Login':
          currentStatus.loginBanEndTime = null;
          currentStatus.isLoginBanPermanent = false;
          break;
        case 'Mic':
          currentStatus.micBanEndTime = null;
          currentStatus.isMicBanPermanent = false;
          break;
        case 'Chat':
          currentStatus.chatBanEndTime = null;
          currentStatus.isChatBanPermanent = false;
          break;
        case 'Device':
          final sessionSnapshot = await FirebaseFirestore.instance
              .collection('device_sessions')
              .where('userId', isEqualTo: _foundUser!.userId)
              .get();
          for (var doc in sessionSnapshot.docs) {
            await FirebaseFirestore.instance.collection('banned_devices').doc(doc.id).delete();
            await doc.reference.update({'isActive': true});
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Unbanned successfully!')));
          
          OfficialTeamApi.sendOfficialMessage(
            receiverId: _foundUser!.userId,
            receiverDeviceToken: _foundUser!.deviceToken,
            messageText: 'Your Device Ban has been lifted. Welcome back!',
          );
          return;
      }

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_foundUser!.userId)
          .update({'banStatus': currentStatus.toMap()});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type Ban removed successfully!')),
      );

      OfficialTeamApi.sendOfficialMessage(
        receiverId: _foundUser!.userId,
        receiverDeviceToken: _foundUser!.deviceToken,
        messageText: 'Your $type Ban has been lifted. Please follow community guidelines.',
      );

      _searchUser(); // refresh user
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove ban: $e')),
      );
    }
  }

  Widget _buildBanCard(String title, bool isPermanent, DateTime? endTime, String type) {
    bool isBanned = isPermanent || (endTime != null && endTime.isAfter(DateTime.now()));
    
    return Card(
      color: const Color(0xFF2A1B38),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (isBanned)
                  const Chip(label: Text('BANNED', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
                else
                  const Chip(label: Text('ACTIVE', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
              ],
            ),
            if (isBanned) ...[
              const SizedBox(height: 8),
              Text(
                isPermanent ? 'Duration: Permanent' : 'Expires: ${endTime.toString()}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _removeBan(type),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Remove Ban'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(onPressed: () => _applyBan(type, 1), child: const Text('1 Hour')),
                  ElevatedButton(onPressed: () => _applyBan(type, 24), child: const Text('24 Hours')),
                  ElevatedButton(onPressed: () => _applyBan(type, 24 * 7), child: const Text('7 Days')),
                  ElevatedButton(
                    onPressed: () => _applyBan(type, -1),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Permanent'),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        title: const Text('Ban Management', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF1E142B),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminRoomBanManagementScreen()),
              );
            },
            icon: const Icon(Icons.no_meeting_room, color: Colors.purpleAccent),
            label: const Text('Room Bans', style: TextStyle(color: Colors.purpleAccent)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter User ID or Phone Number',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF2A1B38),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchUser,
                  child: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            if (_foundUser != null) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _foundUser!.photoUrl.isNotEmpty ? NetworkImage(_foundUser!.photoUrl) : null,
                  child: _foundUser!.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(_foundUser!.fullname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${_foundUser!.userId}\nPhone: ${_foundUser!.number}', style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildBanCard(
                      'Login Ban',
                      _foundUser!.banStatus?.isLoginBanPermanent ?? false,
                      _foundUser!.banStatus?.loginBanEndTime,
                      'Login',
                    ),
                    _buildBanCard(
                      'Microphone Ban',
                      _foundUser!.banStatus?.isMicBanPermanent ?? false,
                      _foundUser!.banStatus?.micBanEndTime,
                      'Mic',
                    ),
                    _buildBanCard(
                      'Chat Ban',
                      _foundUser!.banStatus?.isChatBanPermanent ?? false,
                      _foundUser!.banStatus?.chatBanEndTime,
                      'Chat',
                    ),
                    _buildBanCard(
                      'Device Ban',
                      false, // State isn't attached to User model.
                      null,
                      'Device',
                    ),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
