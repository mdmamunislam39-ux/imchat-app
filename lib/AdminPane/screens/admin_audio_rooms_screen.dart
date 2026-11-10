import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/helpers/country_helper.dart';

class AdminAudioRoomsScreen extends StatefulWidget {
  const AdminAudioRoomsScreen({super.key});

  @override
  State<AdminAudioRoomsScreen> createState() => _AdminAudioRoomsScreenState();
}

class _AdminAudioRoomsScreenState extends State<AdminAudioRoomsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _globalRulesController = TextEditingController();

  AudioRoomV2? _currentRoom;
  bool _isLoading = false;
  bool _isSavingGlobalRules = false;
  String _selectedCategory = 'Event';
  final List<String> _categories = ['Event', 'Game', 'PK', 'All Rooms'];
  String _selectedCountryCode = 'BD';

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
  void initState() {
    super.initState();
    _loadGlobalRules();
  }

  Future<void> _loadGlobalRules() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('audio_room_rules')
          .get();
      if (doc.exists && doc.data() != null) {
        final rules = doc.data()!['rulesText'] as String?;
        if (rules != null && rules.isNotEmpty) {
          _globalRulesController.text = rules;
        } else {
          _globalRulesController.text =
              "There are a lot of very interested friends here. Let's chat together.";
        }
      } else {
        _globalRulesController.text =
            "There are a lot of very interested friends here. Let's chat together.";
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading global rules: $e');
    }
  }

  Future<void> _saveGlobalRules() async {
    setState(() => _isSavingGlobalRules = true);
    try {
      final text = _globalRulesController.text.trim();
      await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('audio_room_rules')
          .set({
        'rulesText': text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSnackBar('Global Audio Room Rules saved successfully!');
    } catch (e) {
      _showSnackBar('Error saving global rules: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingGlobalRules = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _globalRulesController.dispose();
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
      String initialCountry = room.countryCode ?? '';
      if (initialCountry.isEmpty && room.creatorCountry != null && room.creatorCountry!.isNotEmpty) {
        initialCountry = CountryHelper.detectCountryCodeFromPhoneOrUser(countryStr: room.creatorCountry);
      }
      if (initialCountry.isEmpty && room.creatorPhone != null && room.creatorPhone!.isNotEmpty) {
        initialCountry = CountryHelper.detectCountryCodeFromPhoneOrUser(phone: room.creatorPhone);
      }
      if (initialCountry.isEmpty) initialCountry = 'BD';

      setState(() {
        _currentRoom = room;
        _nameController.text = room.name;
        _descController.text = room.description;
        _selectedCategory = _categories.contains(room.category) ? room.category : 'Event';
        _selectedCountryCode = initialCountry.toUpperCase();
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
        allowedExtensions: isFrame ? ['png', 'gif', 'svga', 'mp4', 'vap', 'var', 'webp'] : ['png', 'jpg', 'jpeg', 'webp'],
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

      final countryData = CountryHelper.getCountryData(_selectedCountryCode);
      final updates = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'countryCode': _selectedCountryCode,
        'creatorCountry': countryData.name,
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
                  const SizedBox(height: 20),
                  _buildGlobalRulesSection(),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: CountryHelper.getAllCountries().any((c) => c.code == _selectedCountryCode)
                ? _selectedCountryCode
                : 'BD',
            dropdownColor: const Color(0xFF0F172A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Room Country / Location',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            items: CountryHelper.getAllCountries().map((c) {
              return DropdownMenuItem(
                value: c.code,
                child: Row(
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('${c.name} (${c.code})', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedCountryCode = v ?? 'BD'),
          ),
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

  Widget _buildGlobalRulesSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gavel_rounded, color: Color(0xFF00E5FF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Global Voice Room Rules (সকল রুমের রুলস)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'এই রুলসটি সকল ভয়েস রুমে Pro Mode এবং Party Mode-এ প্রদর্শিত হবে। শুধুমাত্র অ্যাডমিন এটি পরিবর্তন করতে পারবেন।',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _globalRulesController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter global voice room rules here...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingGlobalRules ? null : _saveGlobalRules,
              icon: _isSavingGlobalRules
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save Global Rules'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
