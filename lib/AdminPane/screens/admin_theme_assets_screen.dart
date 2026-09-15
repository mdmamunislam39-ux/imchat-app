import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Admin screen for customizing global app theme assets and tab icons.
class AdminThemeAssetsScreen extends StatefulWidget {
  const AdminThemeAssetsScreen({super.key});

  @override
  State<AdminThemeAssetsScreen> createState() => _AdminThemeAssetsScreenState();
}

class _AdminThemeAssetsScreenState extends State<AdminThemeAssetsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  // Configuration Fields
  final List<String> _fields = [
    'appLogoUrl',
    'diamondIconUrl',
    'beansIconUrl',
    'defaultAvatarUrl',
    'splashImageUrl',
    'splashColor',
    'tabChatIconUrl',
    'tabHomeIconUrl',
    'tabGlobeIconUrl',
    'tabContactsIconUrl',
    'searchIconUrl',
    'trophyIconUrl',
    'giftBoxIconUrl',
    'gameWallIconUrl',
    'leaderboardBgUrl',
    'top1FrameUrl',
    'top2FrameUrl',
    'top3FrameUrl',
    'leaderboardPodiumUrl',
  ];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _uploadingStates = {};

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field] = TextEditingController();
      _uploadingStates[field] = false;
    }
    _loadThemeData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadThemeData() async {
    try {
      setState(() => _isLoading = true);

      final doc = await _firestore.collection('global_settings').doc('app_theme').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        for (final field in _fields) {
          _controllers[field]?.text = (data[field] ?? '').toString();
        }

        if (data['leaderboardFrames'] is Map) {
          final Map frames = data['leaderboardFrames'];
          if ((_controllers['top1FrameUrl']?.text.isEmpty ?? true) && frames['1'] != null) {
            _controllers['top1FrameUrl']?.text = frames['1'].toString();
          }
          if ((_controllers['top2FrameUrl']?.text.isEmpty ?? true) && frames['2'] != null) {
            _controllers['top2FrameUrl']?.text = frames['2'].toString();
          }
          if ((_controllers['top3FrameUrl']?.text.isEmpty ?? true) && frames['3'] != null) {
            _controllers['top3FrameUrl']?.text = frames['3'].toString();
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ AdminThemeAssetsScreen: Error loading theme data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load theme settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(String fieldName) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _uploadingStates[fieldName] = true);

      final File file = File(image.path);
      final String extension = image.path.split('.').last;
      final String storagePath = 'app_theme_assets/${fieldName}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      debugPrint('📤 AdminThemeAssetsScreen: Uploading $fieldName image to $storagePath...');
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ AdminThemeAssetsScreen: Upload successful: $downloadUrl');

      if (mounted) {
        setState(() {
          _controllers[fieldName]?.text = downloadUrl;
          _uploadingStates[fieldName] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded image for ${fieldName.replaceAll('Url', '')} successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ AdminThemeAssetsScreen: Error uploading image: $e');
      if (mounted) {
        setState(() => _uploadingStates[fieldName] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isSaving = true);

      final Map<String, dynamic> updateData = {};
      for (final field in _fields) {
        updateData[field] = _controllers[field]?.text.trim() ?? '';
      }

      // Also mirror into leaderboardFrames map for backwards compatibility
      updateData['leaderboardFrames'] = {
        '1': _controllers['top1FrameUrl']?.text.trim() ?? '',
        '2': _controllers['top2FrameUrl']?.text.trim() ?? '',
        '3': _controllers['top3FrameUrl']?.text.trim() ?? '',
      };

      await _firestore.collection('global_settings').doc('app_theme').set(
        updateData,
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ App Theme and Navigation settings updated successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ AdminThemeAssetsScreen: Error saving settings: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121318),
      appBar: AppBar(
        title: const Text(
          'App Theme & Assets',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1C1D24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _loadThemeData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Brand & Icon Customization',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Configure dynamic app branding assets, splash configuration, tab bar navigation icons, and room controls.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildCategorySection(
                    title: 'General Branding Assets',
                    icon: Icons.storefront_rounded,
                    children: [
                      _buildAssetRow('appLogoUrl', 'App Logo'),
                      _buildAssetRow('diamondIconUrl', 'Diamond Currency Icon'),
                      _buildAssetRow('beansIconUrl', 'Beans Currency Icon'),
                      _buildAssetRow('defaultAvatarUrl', 'Fallback User Avatar'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCategorySection(
                    title: 'Splash Screen Assets',
                    icon: Icons.splitscreen_rounded,
                    children: [
                      _buildAssetRow('splashImageUrl', 'Splash Center Image'),
                      _buildColorRow('splashColor', 'Splash Background Color'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCategorySection(
                    title: 'Home Tab Bar & Header Action Icons',
                    icon: Icons.navigation_rounded,
                    children: [
                      _buildAssetRow('tabChatIconUrl', 'Chat Tab Icon'),
                      _buildAssetRow('tabHomeIconUrl', 'Home Tab Icon'),
                      _buildAssetRow('tabGlobeIconUrl', 'Globe Tab Icon'),
                      _buildAssetRow('tabContactsIconUrl', 'Contacts Tab Icon'),
                      _buildAssetRow('searchIconUrl', 'Room ID Search Icon'),
                      _buildAssetRow('trophyIconUrl', 'Top Rankings / Trophy Icon'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCategorySection(
                    title: 'Voice Room Quick Controls',
                    icon: Icons.settings_voice_rounded,
                    children: [
                      _buildAssetRow('giftBoxIconUrl', 'Room Gift Box Icon'),
                      _buildAssetRow('gameWallIconUrl', 'Room Game Wall Icon'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCategorySection(
                    title: '🏆 Top Rankings & Leaderboard Customization',
                    icon: Icons.emoji_events_rounded,
                    children: [
                      _buildAssetRow('leaderboardBgUrl', 'Stage / Podium Background Image (Grand Hall)'),
                      _buildAssetRow('top1FrameUrl', 'Top 1 Ornate Frame (Crown & Wings)'),
                      _buildAssetRow('top2FrameUrl', 'Top 2 Ornate Frame (Gold & Blue Wreath)'),
                      _buildAssetRow('top3FrameUrl', 'Top 3 Ornate Frame (Gold & Green Wreath)'),
                      _buildAssetRow('leaderboardPodiumUrl', 'Podium Stage Disc Image (Optional)'),
                    ],
                  ),
                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.withAlpha(80),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: const Text(
                        'Save App Settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha(10),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white10),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAssetRow(String fieldName, String label) {
    final String url = _controllers[fieldName]?.text ?? '';
    final bool isUploading = _uploadingStates[fieldName] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Image Preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withAlpha(15),
                  ),
                ),
                child: isUploading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.purpleAccent,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 18,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                color: Colors.white30,
                                size: 18,
                              ),
                      ),
              ),
              const SizedBox(width: 10),

              // URL Field
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: TextField(
                    controller: _controllers[fieldName],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste direct Image URL...',
                      hintStyle: TextStyle(
                        color: Colors.white.withAlpha(77),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Upload Button
              IconButton(
                icon: const Icon(Icons.upload_file_rounded, color: Colors.purpleAccent),
                onPressed: isUploading ? null : () => _pickAndUploadImage(fieldName),
                tooltip: 'Upload from Gallery',
              ),

              // Clear Button
              if (url.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    setState(() {
                      _controllers[fieldName]?.text = '';
                    });
                  },
                  tooltip: 'Clear field',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(String fieldName, String label) {
    final String colorHex = _controllers[fieldName]?.text ?? '';

    // Validate hex color
    Color? parsedColor;
    if (colorHex.isNotEmpty) {
      final buffer = StringBuffer();
      if (colorHex.length == 6 || colorHex.length == 7) buffer.write('ff');
      buffer.write(colorHex.replaceFirst('#', ''));
      try {
        parsedColor = Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Color Preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: parsedColor ?? Colors.black.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withAlpha(15),
                  ),
                ),
                child: parsedColor == null
                    ? const Icon(
                        Icons.color_lens_outlined,
                        color: Colors.white30,
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              // Hex Color Code input field
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: TextField(
                    controller: _controllers[fieldName],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter Hex code (e.g. #120C1C)...',
                      hintStyle: TextStyle(
                        color: Colors.white.withAlpha(77),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Clear Button
              if (colorHex.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    setState(() {
                      _controllers[fieldName]?.text = '';
                    });
                  },
                  tooltip: 'Clear field',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
