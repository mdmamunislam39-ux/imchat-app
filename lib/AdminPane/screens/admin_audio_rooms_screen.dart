import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

class AdminAudioRoomsScreen extends StatefulWidget {
  const AdminAudioRoomsScreen({super.key});

  @override
  State<AdminAudioRoomsScreen> createState() => _AdminAudioRoomsScreenState();
}

class _AdminAudioRoomsScreenState extends State<AdminAudioRoomsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  AudioRoomV2? _currentRoom;
  bool _isLoading = false;
  String _selectedCategory = 'Event';
  final List<String> _categories = ['Event', 'Game', 'PK', 'All Rooms'];

  // Pinning
  bool _isPinned = false;
  DateTime? _pinnedUntil;

  // Framing
  DateTime? _frameUntil;
  File? _selectedFrameFile;

  // Ban
  bool _isBanned = false;
  DateTime? _banEndTime;

  // Cover Image
  File? _selectedCoverFile;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _searchRoom() async {
    final roomId = _searchController.text.trim();
    if (roomId.isEmpty) {
      _showSnackBar('Please enter a room ID', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('audio_rooms_v2').doc(roomId).get();
      if (!doc.exists) {
        _showSnackBar('Room not found', isError: true);
        setState(() {
          _currentRoom = null;
          _isLoading = false;
        });
        return;
      }

      final room = AudioRoomV2.fromFirestore(doc);
      setState(() {
        _currentRoom = room;
        _nameController.text = room.name;
        _descController.text = room.description;
        _selectedCategory = _categories.contains(room.category) ? room.category : 'Event';
        _isPinned = room.isPinned;
        _pinnedUntil = room.pinnedUntil;
        _frameUntil = room.roomFrameUntil;
        _isBanned = room.isBanned;
        _banEndTime = room.banEndTime;
        _selectedFrameFile = null;
        _selectedCoverFile = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching room: $e', isError: true);
    }
  }

  Future<void> _pickDateTime(bool isPinning) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isPinning) {
        _pinnedUntil = dateTime;
        _isPinned = true;
      } else {
        _frameUntil = dateTime;
      }
    });
  }

  Future<void> _pickBanDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _banEndTime = dateTime;
      _isBanned = true;
    });
  }

  Future<void> _pickFile(bool isFrame) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isFrame ? ['png', 'gif', 'svga'] : ['png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (isFrame) {
            _selectedFrameFile = File(result.files.single.path!);
          } else {
            _selectedCoverFile = File(result.files.single.path!);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final ext = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child('audio_rooms/$folder/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _showSnackBar('Error uploading file: $e', isError: true);
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_currentRoom == null) return;

    setState(() => _isLoading = true);
    try {
      String? coverUrl = _currentRoom!.imageUrl;
      if (_selectedCoverFile != null) {
        coverUrl = await _uploadFile(_selectedCoverFile!, 'covers');
      }

      String? frameUrl = _currentRoom!.roomFrameUrl;
      if (_selectedFrameFile != null) {
        frameUrl = await _uploadFile(_selectedFrameFile!, 'frames');
      }

      // If user toggled switch on, but forgot to pick date, assign default 1 day
      if (_isPinned && _pinnedUntil == null) {
        _pinnedUntil = DateTime.now().add(const Duration(days: 1));
      }

      final updates = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': coverUrl,
        'isPinned': _isPinned,
        'pinnedUntil': _pinnedUntil != null ? Timestamp.fromDate(_pinnedUntil!) : FieldValue.delete(),
        'roomFrameUrl': frameUrl,
        'roomFrameUntil': _frameUntil != null ? Timestamp.fromDate(_frameUntil!) : FieldValue.delete(),
        'isBanned': _isBanned,
        'banEndTime': _banEndTime != null ? Timestamp.fromDate(_banEndTime!) : FieldValue.delete(),
      };

      await FirebaseFirestore.instance.collection('audio_rooms_v2').doc(_currentRoom!.id).update(updates);

      // Re-fetch room to reflect changes accurately
      await _searchRoom();
      _showSnackBar('Room updated successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error updating room: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Audio Room Management'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  if (_currentRoom != null) ...[
                    _buildSectionHeader('Room Information'),
                    _buildInfoForm(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Pinning Settings'),
                    _buildPinningSettings(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Room Profile Frame'),
                    _buildFrameSettings(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Ban Settings'),
                    _buildBanSettings(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save All Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter Room ID (e.g. 63965726)',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blueAccent),
            onPressed: _searchRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoForm() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _pickFile(false),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    image: _selectedCoverFile != null
                        ? DecorationImage(image: FileImage(_selectedCoverFile!), fit: BoxFit.cover)
                        : _currentRoom!.imageUrl != null
                            ? DecorationImage(image: NetworkImage(_currentRoom!.imageUrl!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: (_selectedCoverFile == null && _currentRoom!.imageUrl == null)
                      ? const Icon(Icons.add_a_photo, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildTextField(_nameController, 'Room Name'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(_descController, 'Room Description', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildPinningSettings() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Pin Room to Top', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Room will appear at the top of Explorer', style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: _isPinned,
            activeThumbColor: Colors.blueAccent,
            onChanged: (v) {
              setState(() {
                _isPinned = v;
                if (!v) _pinnedUntil = null;
              });
            },
          ),
          if (_isPinned)
            ListTile(
              title: const Text('Pinned Until:', style: TextStyle(color: Colors.white70)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                label: Text(
                  _pinnedUntil != null ? DateFormat('MMM dd, yyyy HH:mm').format(_pinnedUntil!) : 'Select Date & Time',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
                onPressed: () => _pickDateTime(true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFrameSettings() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Upload Frame (PNG/GIF/SVGA)', style: TextStyle(color: Colors.white)),
            subtitle: Text(_selectedFrameFile != null
                ? 'Selected: ${_selectedFrameFile!.path.split(Platform.pathSeparator).last}'
                : _currentRoom!.roomFrameUrl != null
                    ? 'Active frame exists in database'
                    : 'No frame assigned', style: const TextStyle(color: Colors.white54)),
            trailing: ElevatedButton.icon(
              onPressed: () => _pickFile(true),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
          ),
          if (_selectedFrameFile != null || _currentRoom!.roomFrameUrl != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Frame Expiry Time:', style: TextStyle(color: Colors.white70)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.access_time, color: Colors.blueAccent),
                label: Text(
                  _frameUntil != null ? DateFormat('MMM dd, yyyy HH:mm').format(_frameUntil!) : 'Select Expiry',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
                onPressed: () => _pickDateTime(false),
              ),
            ),
          if (_currentRoom!.roomFrameUrl != null && _selectedFrameFile == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentRoom = _currentRoom!.copyWith(roomFrameUrl: null, roomFrameUntil: null);
                    _frameUntil = null;
                  });
                },
                child: const Text('Remove Current Frame', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanSettings() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Ban Room', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            subtitle: const Text('Room will remain active but no one can join seats', style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: _isBanned,
            activeThumbColor: Colors.redAccent,
            onChanged: (v) {
              setState(() {
                _isBanned = v;
                if (!v) _banEndTime = null;
              });
            },
          ),
          if (_isBanned)
            ListTile(
              title: const Text('Banned Until (Leave empty for permanent):', style: TextStyle(color: Colors.white70)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.calendar_today, color: Colors.redAccent),
                label: Text(
                  _banEndTime != null ? DateFormat('MMM dd, yyyy HH:mm').format(_banEndTime!) : 'Permanent',
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onPressed: _pickBanDateTime,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}
