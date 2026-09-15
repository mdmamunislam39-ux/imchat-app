import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminIntimacyLevelsScreen extends StatefulWidget {
  const AdminIntimacyLevelsScreen({super.key});

  @override
  State<AdminIntimacyLevelsScreen> createState() => _AdminIntimacyLevelsScreenState();
}

class _AdminIntimacyLevelsScreenState extends State<AdminIntimacyLevelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  final _levelController = TextEditingController();
  final _pointsController = TextEditingController();
  
  File? _selectedImage;
  bool _isSaving = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _levelController.clear();
        _pointsController.clear();
        _selectedImage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _levelController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  String _getCollectionName() {
    return _tabController.index == 0 ? 'couple_levels' : 'relationshipLevels';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'gif', 'svga', 'webp', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _addLevel() async {
    final levelVal = int.tryParse(_levelController.text.trim());
    final pointsVal = int.tryParse(_pointsController.text.trim());
    final collectionName = _getCollectionName();

    if (levelVal == null || levelVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid level number (greater than 0)')),
      );
      return;
    }

    if (pointsVal == null || pointsVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid points/diamonds amount (0 or more)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;

      // 1. Upload file to Firebase Storage if selected
      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last.toLowerCase();
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('relationship_levels_media/${_uuid.v4()}.$ext');
        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      // 2. Save level to Firestore
      final docId = 'level_$levelVal';
      final Map<String, dynamic> dataToSave = {
        'level': levelVal,
        'requiredPoints': pointsVal,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        dataToSave['badgeUrl'] = imageUrl;
      }

      await _firestore.collection(collectionName).doc(docId).set(
        dataToSave,
        SetOptions(merge: true),
      );

      _levelController.clear();
      _pointsController.clear();
      setState(() {
        _selectedImage = null;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Level saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save level: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteLevel(String docId) async {
    final collectionName = _getCollectionName();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1F3F),
        title: const Text('Delete Level', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this level configuration?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection(collectionName).doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Level configuration deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete level: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSelectedFilePreview() {
    if (_selectedImage == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, color: Colors.white54, size: 28),
          SizedBox(height: 4),
          Text(
            'Upload Icon\n(PNG/GIF/SVGA)',
            style: TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    final path = _selectedImage!.path.toLowerCase();
    if (path.endsWith('.svga')) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.animation, color: Colors.purpleAccent, size: 30),
          SizedBox(height: 4),
          Text(
            'SVGA File',
            style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildIntimacyLevelIcon(String url, double size) {
    if (url.toLowerCase().contains('.svga')) {
      return SizedBox(
        width: size,
        height: size,
        child: SVGAEasyPlayer(resUrl: url),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.purpleAccent),
        ),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        title: const Text('CP & Friendship Levels', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2D1F3F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Couple Levels'),
            Tab(text: 'Friendship Levels'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(),
          _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final collectionName = _getCollectionName();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Level Form
          Card(
            color: const Color(0xFF2D1F3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add / Update ${_tabController.index == 0 ? "Couple" : "Friendship"} Level',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Fields
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _levelController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Level Number',
                                labelStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF1E142B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pointsController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Required Diamonds',
                                labelStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF1E142B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // File Picker UI
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E142B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedImage != null ? Colors.purpleAccent : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: _buildSelectedFilePreview(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _addLevel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Level Configuration',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Configured Levels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Levels List Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(collectionName)
                  .orderBy('level', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No levels configured for this category yet.\nDefault settings will be used.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final level = data['level'] ?? 0;
                    final requiredPoints = data['requiredPoints'] ?? 0;
                    final badgeUrl = data['badgeUrl'] as String? ?? data['imageUrl'] as String?;
                    final docId = docs[index].id;

                    return Card(
                      color: const Color(0xFF2D1F3F),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: badgeUrl != null && badgeUrl.isNotEmpty
                            ? Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E142B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.purpleAccent, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: _buildIntimacyLevelIcon(badgeUrl, 36),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.purpleAccent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Lv.$level',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                        title: Text(
                          'Level $level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '$requiredPoints Diamonds required',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteLevel(docId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
