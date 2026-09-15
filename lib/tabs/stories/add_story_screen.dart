import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/tabs/stories/story_editor_screen.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final List<AssetEntity> _galleryAssets = [];
  bool _isLoadingAssets = true;
  bool _selectMultiple = false;
  final Set<AssetEntity> _selectedAssets = {};

  @override
  void initState() {
    super.initState();
    _loadRecentGalleryAssets();
  }

  Future<void> _loadRecentGalleryAssets() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          onlyAll: true,
        );
        if (paths.isNotEmpty) {
          final List<AssetEntity> entities =
              await paths.first.getAssetListPaged(page: 0, size: 60);
          if (mounted) {
            setState(() {
              _galleryAssets.clear();
              _galleryAssets.addAll(entities);
              _isLoadingAssets = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading gallery assets: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingAssets = false;
      });
    }
  }

  Future<void> _openCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null) {
        final file = File(photo.path);
        Get.to(() => StoryEditorScreen(imageFile: file));
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, 'Could not open camera.');
    }
  }

  Future<void> _openGalleryPicker() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null) {
        final file = File(photo.path);
        Get.to(() => StoryEditorScreen(imageFile: file));
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
    }
  }

  Future<void> _onAssetTapped(AssetEntity asset) async {
    if (_selectMultiple) {
      setState(() {
        if (_selectedAssets.contains(asset)) {
          _selectedAssets.remove(asset);
        } else {
          _selectedAssets.add(asset);
        }
      });
      return;
    }

    DialogHelper.showProcessingDialog(
        title: 'Loading image...', barrierDismissible: false);
    final File? file = await asset.file;
    DialogHelper.closeDialog();

    if (file != null) {
      Get.to(() => StoryEditorScreen(imageFile: file));
    } else {
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, 'Unable to load selected photo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87, size: 26),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Add Story',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Top Gradient Action Cards (Camera, Text, MagicStatus, Music)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 1. Camera Card
                Expanded(
                  child: _buildActionCard(
                    title: 'Camera',
                    icon: Icons.camera_alt_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    onTap: _openCamera,
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Text Card
                Expanded(
                  child: _buildActionCard(
                    title: 'Text',
                    icon: Icons.text_fields_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF7043)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    onTap: () => Get.toNamed(AppRoutes.writeStory),
                  ),
                ),
                const SizedBox(width: 10),

                // 3. MagicStatus Card
                Expanded(
                  child: _buildActionCard(
                    title: 'MagicStatus',
                    icon: Icons.auto_awesome_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF007F), Color(0xFFA000FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    onTap: () => Get.toNamed(AppRoutes.writeStory),
                  ),
                ),
                const SizedBox(width: 10),

                // 4. Music Card
                Expanded(
                  child: _buildActionCard(
                    title: 'Music',
                    icon: Icons.music_note_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    onTap: _openGalleryPicker,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Gallery Section Header with "Gallery ▾" and "Select multiple" toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _openGalleryPicker,
                  child: const Row(
                    children: [
                      Text(
                        'Gallery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.black87, size: 22),
                    ],
                  ),
                ),

                // Select Multiple checkbox
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectMultiple = !_selectMultiple;
                      if (!_selectMultiple) _selectedAssets.clear();
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        _selectMultiple
                            ? Icons.check_circle_rounded
                            : Icons.panorama_fish_eye_rounded,
                        color: _selectMultiple ? primaryColor : Colors.black54,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Select multiple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Gallery Grid View
          Expanded(
            child: _isLoadingAssets
                ? const Center(child: CircularProgressIndicator())
                : _galleryAssets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                size: 64, color: Colors.black26),
                            const SizedBox(height: 12),
                            const Text(
                              'No photos found in gallery',
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: _openGalleryPicker,
                              icon: const Icon(Icons.folder_open,
                                  color: Colors.white),
                              label: const Text('Browse Files',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        itemCount: _galleryAssets.length,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 3,
                          crossAxisSpacing: 3,
                        ),
                        itemBuilder: (context, index) {
                          final asset = _galleryAssets[index];
                          final isSelected = _selectedAssets.contains(asset);

                          return GestureDetector(
                            onTap: () => _onAssetTapped(asset),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FutureBuilder<Uint8List?>(
                                  future: asset.thumbnailDataWithSize(
                                    const ThumbnailSize(250, 250),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(color: Colors.grey[200]);
                                  },
                                ),
                                if (_selectMultiple)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.black38,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              size: 14, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
