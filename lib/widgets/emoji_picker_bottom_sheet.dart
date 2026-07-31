import 'package:flutter/material.dart';
import 'package:chat_messenger/widgets/spinning_dice_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/services/emoji_service.dart';

/// Custom emoji picker bottom sheet similar to the screenshot
class EmojiPickerBottomSheet extends StatefulWidget {
  final Function(EmojiItem) onEmojiSelected;
  final String? currentUserId;
  final VoidCallback? onClose;

  const EmojiPickerBottomSheet({
    super.key,
    required this.onEmojiSelected,
    this.currentUserId,
    this.onClose,
  });

  @override
  State<EmojiPickerBottomSheet> createState() => _EmojiPickerBottomSheetState();
}

class _EmojiPickerBottomSheetState extends State<EmojiPickerBottomSheet> {
  List<EmojiCategory> _categories = [];
  Map<String, List<EmojiItem>> _emojisByCategory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmojiData();
  }

  Future<void> _loadEmojiData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load categories and emojis
      final categories = await EmojiService.getEmojiCategories();
      final emojisByCategory = await EmojiService.getAllEmojis();

      // Inject Ludo Dice into Activity category (or first category if not found)
      final activityCategory = categories.firstWhere(
        (c) => c.displayName.toLowerCase().contains('activity'),
        orElse: () => categories.isNotEmpty ? categories.first : const EmojiCategory(id: 'dummy', name: 'Activity', displayName: 'Activity', iconUrl: '', order: 0),
      );

      if (activityCategory.id != 'dummy') {
        final diceEmoji = const EmojiItem(
          id: 'local_dice_action',
          name: 'dice',
          displayName: 'Ludo Dice',
          emojiUrl: 'local_dice_action', // Special marker
          categoryId: '',
          order: -1,
        );
        if (emojisByCategory.containsKey(activityCategory.id)) {
          emojisByCategory[activityCategory.id]!.insert(0, diceEmoji);
        } else {
          emojisByCategory[activityCategory.id] = [diceEmoji];
        }
      }

      if (mounted) {
        setState(() {
          _categories = categories;
          _emojisByCategory = emojisByCategory;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [EmojiPicker] Error loading emoji data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onEmojiSelected(EmojiItem emoji) async {
    try {
      // Add to recent emojis if user ID is provided
      if (widget.currentUserId != null) {
        await EmojiService.addToRecentEmojis(widget.currentUserId!, emoji);
      }

      // Call the callback
      widget.onEmojiSelected(emoji);

      // Close the bottom sheet
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ [EmojiPicker] Error selecting emoji: $e');
    }
  }

  Widget _buildEmojiGrid(List<EmojiItem> emojis) {
    if (emojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No emojis found',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return _buildEmojiItem(emoji);
      },
    );
  }

  Widget _buildEmojiItem(EmojiItem emoji) {
    return GestureDetector(
      onTap: () => _onEmojiSelected(emoji),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: emoji.emojiUrl == 'local_dice_action'
              ? const Center(
                  child: StaticDiceWidget(
                    number: 6,
                    size: 32,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: emoji.emojiUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.emoji_emotions,
                      color: Colors.grey.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmojiContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
        ),
      );
    }

    return _buildAllEmojisView();
  }

  Widget _buildAllEmojisView() {
    if (_categories.isEmpty) {
      return _buildEmojiGrid([]);
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = _categories[categoryIndex];
        final emojis = _emojisByCategory[category.id] ?? [];

        if (emojis.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                category.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Emojis grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                return _buildEmojiItem(emojis[index]);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C3E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Title and Close button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Emoji',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: () {
                    widget.onClose?.call();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Emoji content
          Expanded(
            child: _buildEmojiContent(),
          ),
        ],
      ),
    );
  }
}
