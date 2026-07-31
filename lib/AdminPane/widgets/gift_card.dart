import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gift.dart';

/// Card widget for displaying gift information
class GiftCard extends StatelessWidget {
  final Gift gift;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GiftCard({
    super.key,
    required this.gift,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gift image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: gift.pngUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: gift.pngUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.card_giftcard,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
            ),
          ),
          
          // Gift info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gift name
                  Text(
                    gift.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  
                  // Category and credits in one row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(gift.category).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _getCategoryEmoji(gift.category),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          gift.category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Color(0xFF00BCD4),
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${gift.credits}',
                            style: const TextStyle(
                              color: Color(0xFF00BCD4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // Generate a consistent dynamic color based on category name
    final colors = [
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
    ];
    return colors[category.hashCode.abs() % colors.length];
  }

  String _getCategoryEmoji(String category) {
    // Default emoji since we no longer hardcode specific emojis per category
    return '🎁';
  }
}
