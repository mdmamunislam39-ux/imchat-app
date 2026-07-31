import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/banner.dart';
import '../services/banner_service.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final BannerService _bannerService = BannerService();
  List<AudioRoomBanner> _banners = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      setState(() => _isLoading = true);
      final banners = await _bannerService.getAllBanners();
      setState(() {
        _banners = banners;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load banners: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _addBanner() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddBannerDialog(),
    );

    if (result == true) {
      _loadBanners();
      _showSnackBar('Banner added successfully!');
    }
  }

  Future<void> _deleteBanner(AudioRoomBanner banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Banner', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this banner?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _bannerService.deleteBanner(banner.id, banner.imageUrl);
        await _loadBanners();
        _showSnackBar('Banner deleted successfully!');
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to delete banner: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C1C),
      appBar: AppBar(
        title: const Text(
          'Banner Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _addBanner,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            tooltip: 'Add Banner',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : _banners.isEmpty
              ? const Center(
                  child: Text(
                    'No banners found.\nTap "+" to add a custom room banner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    return Card(
                      color: const Color(0xFF1E142B),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: banner.imageUrl.isNotEmpty && banner.imageUrl.startsWith('http')
                                ? Image.network(
                                    banner.imageUrl.startsWith('http://')
                                        ? banner.imageUrl.replaceFirst('http://', 'https://')
                                        : banner.imageUrl,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 140,
                                        color: Colors.white10,
                                        child: const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white30, size: 50),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    height: 140,
                                    color: Colors.white10,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.white30, size: 50),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        banner.clickUrl != null && banner.clickUrl!.isNotEmpty
                                            ? '🔗 Link: ${banner.clickUrl}'
                                            : '🔗 No Link Attached',
                                        style: TextStyle(
                                          color: banner.clickUrl != null && banner.clickUrl!.isNotEmpty
                                              ? Colors.cyanAccent
                                              : Colors.white54,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (banner.eventId != null && banner.eventId!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '🎉 Event ID: ${banner.eventId}',
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created: ${banner.createdAt.toLocal().toString().split('.')[0]}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteBanner(banner),
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  tooltip: 'Delete Banner',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddBannerDialog extends StatefulWidget {
  const _AddBannerDialog();

  @override
  State<_AddBannerDialog> createState() => _AddBannerDialogState();
}

class _AddBannerDialogState extends State<_AddBannerDialog> {
  final BannerService _bannerService = BannerService();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _clickUrlController = TextEditingController();
  final TextEditingController _eventIdController = TextEditingController();
  File? _selectedImageFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _imageUrlController.dispose();
    _clickUrlController.dispose();
    _eventIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _imageUrlController.text = ''; // Clear URL if local file is chosen
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submit() async {
    if (_selectedImageFile == null && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image file or enter a valid Image URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _bannerService.addBanner(
        imageUrl: _imageUrlController.text.trim(),
        clickUrl: _clickUrlController.text.trim().isEmpty ? null : _clickUrlController.text.trim(),
        eventId: _eventIdController.text.trim().isEmpty ? null : _eventIdController.text.trim(),
        imageFile: _selectedImageFile,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add banner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E142B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Custom Banner',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Image Source Selector
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: _selectedImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_selectedImageFile!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_photo_alternate_rounded, color: Colors.purpleAccent, size: 40),
                            SizedBox(height: 8),
                            Text('Upload from Gallery', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              const Center(
                child: Text('OR', style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              
              // Image URL input
              TextField(
                controller: _imageUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Paste Image URL',
                  labelStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purpleAccent),
                  ),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty && _selectedImageFile != null) {
                    setState(() {
                      _selectedImageFile = null; // Clear image file if URL is typed
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Clickable link URL input
              TextField(
                controller: _clickUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Attach Clickable Link (Optional)',
                  labelStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purpleAccent),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Event ID input
              TextField(
                controller: _eventIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Event ID (Optional)',
                  labelStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purpleAccent),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Add Banner'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
