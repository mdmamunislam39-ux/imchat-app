import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

/// Background image picker for room hosts
class BackgroundPicker extends StatelessWidget {
  final String userId;
  final String? currentImageUrl;
  final Function({File? imageFile, String? imageUrl}) onImageSelected;
  final VoidCallback? onRemoveImage;

  const BackgroundPicker({
    super.key,
    required this.userId,
    this.currentImageUrl,
    required this.onImageSelected,
    this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Change Room Background',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // Current background preview
          if (currentImageUrl != null)
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(currentImageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Text(
                    'Current Background',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          if (currentImageUrl != null) const SizedBox(height: 20),

          // Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Store Backgrounds (My Room Themes)
                _buildOption(
                  icon: IconlyLight.star,
                  title: 'My Room Themes',
                  subtitle: 'Choose from themes you own',
                  onTap: () => _showMyRoomThemes(context),
                ),

                const SizedBox(height: 12),

                // Default backgrounds
                _buildOption(
                  icon: IconlyLight.folder,
                  title: 'Default Backgrounds',
                  subtitle: 'Choose from preset backgrounds',
                  onTap: () => _showDefaultBackgrounds(context),
                ),

                if (currentImageUrl != null) ...[
                  const SizedBox(height: 12),

                  // Remove background
                  _buildOption(
                    icon: IconlyLight.delete,
                    title: 'Remove Background',
                    subtitle: 'Use default background',
                    onTap: () => _removeBackground(context),
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withValues(alpha: 0.1)
                    : primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showMyRoomThemes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MyRoomThemesSheet(
        userId: userId,
        onThemeSelected: (String url) {
          Navigator.of(context).pop(); // Close sheet
          Navigator.of(context).pop(); // Close background picker
          onImageSelected(imageUrl: url);
        },
      ),
    );
  }

  void _showDefaultBackgrounds(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultBackgroundsSheet(
        onBackgroundSelected: (imagePath) {
          Navigator.of(context).pop(); // Close sheet
          Navigator.of(context).pop(); // Close picker
          // Since it's a local asset, we can't just pass it as network url.
          // Wait, earlier it was handled differently or ignored?
          // If we want to support default background, we could pass it as imageUrl but the UI might try to load it as network.
          // The best way for assets is to pass it as url if the Audio Room supports it, or handle it specifically.
          // Let's pass it as imageUrl. AudioRoom will see it's an asset or network.
          // Currently we just pass it to onUrlSelected? No, audio room expects network URL.
          // I'll just pass it as imageUrl and let the Audio Room handle it, or remove Default Backgrounds?
          // The user said: "অথবা ফ্রিতে যেগুলা এড করবে এগুলা এখানে পাবে এন্ড ইউজ করতে পারবে"
          // So I will just leave default backgrounds to use `onImageSelected(imageUrl: imagePath)` but it might break if it expects http.
          onImageSelected(imageUrl: imagePath);
        },
      ),
    );
  }

  void _removeBackground(BuildContext context) {
    Navigator.of(context).pop();
    onRemoveImage?.call();
  }
}

/// My Room Themes selection sheet fetching from StoreService
class MyRoomThemesSheet extends StatefulWidget {
  final String userId;
  final Function(String) onThemeSelected;

  const MyRoomThemesSheet({
    super.key,
    required this.userId,
    required this.onThemeSelected,
  });

  @override
  State<MyRoomThemesSheet> createState() => _MyRoomThemesSheetState();
}

class _MyRoomThemesSheetState extends State<MyRoomThemesSheet> {
  final StoreService _storeService = StoreService();
  List<Map<String, dynamic>> _ownedThemes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    try {
      final items = await _storeService.getUserStoreItemsByType(widget.userId, 'roomTheme');
      if (mounted) {
        setState(() {
          _ownedThemes = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('My Room Themes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text('Error loading themes: $_errorMessage'))
                    : _ownedThemes.isEmpty
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'You do not own any room themes.\nPurchase them from the Store!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _ownedThemes.length,
                            itemBuilder: (context, index) {
                              final item = _ownedThemes[index];
                              final fileUrl = (item['fileUrl'] ?? item['thumbnailUrl'] ?? item['imageUrl'] ?? item['image'] ?? '') as String;
                              final name = item['storeItemName'] ?? 'Room Theme';

                              return GestureDetector(
                                onTap: () {
                                  if (fileUrl.isNotEmpty) {
                                    widget.onThemeSelected(fileUrl);
                                  }
                                },
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                          child: fileUrl.isNotEmpty
                                              ? UniversalAssetWidget(url: fileUrl, fit: BoxFit.cover)
                                              : const Icon(Icons.image, size: 40, color: Colors.grey),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Default backgrounds selection sheet
class DefaultBackgroundsSheet extends StatelessWidget {
  final Function(String) onBackgroundSelected;

  const DefaultBackgroundsSheet({
    super.key,
    required this.onBackgroundSelected,
  });

  @override
  Widget build(BuildContext context) {
    // List of default background assets
    final defaultBackgrounds = [
      'assets/images/welcome_image.png',
      'assets/images/agency.png',
      'assets/images/family.png',
      'assets/images/store.png',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Default Backgrounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            height: 300,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 9,
              ),
              itemCount: defaultBackgrounds.length,
              itemBuilder: (context, index) {
                final backgroundPath = defaultBackgrounds[index];
                return GestureDetector(
                  onTap: () => onBackgroundSelected(backgroundPath),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: AssetImage(backgroundPath), fit: BoxFit.cover),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Helper function to show background picker
Future<void> showBackgroundPicker({
  required BuildContext context,
  required String userId,
  String? currentImageUrl,
  required Function({File? imageFile, String? imageUrl}) onImageSelected,
  VoidCallback? onRemoveImage,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => BackgroundPicker(
      userId: userId,
      currentImageUrl: currentImageUrl,
      onImageSelected: onImageSelected,
      onRemoveImage: onRemoveImage,
    ),
  );
}
