import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

class RelationshipBadgeWidget extends StatelessWidget {
  final int level;
  final String relationshipType;
  final double size;

  const RelationshipBadgeWidget({
    super.key,
    required this.level,
    required this.relationshipType,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final collectionName = relationshipType.toLowerCase() == 'couple' 
        ? 'couple_levels' 
        : 'relationshipLevels';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .doc('level_$level')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultIcon();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final badgeUrl = data?['imageUrl'] as String? ?? data?['badgeUrl'] as String? ?? '';

        if (badgeUrl.isEmpty) {
          return _buildDefaultIcon();
        }

        final isSvga = badgeUrl.toLowerCase().contains('.svga');

        return SizedBox(
          width: size,
          height: size,
          child: isSvga
              ? SVGAEasyPlayer(
                  resUrl: badgeUrl,
                  fit: BoxFit.contain,
                )
              : CachedNetworkImage(
                  imageUrl: badgeUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultIcon(),
                ),
        );
      },
    );
  }

  Widget _buildDefaultIcon() {
    final isCouple = relationshipType.toLowerCase() == 'couple';
    return Icon(
      isCouple ? Icons.favorite : Icons.local_florist,
      color: isCouple ? Colors.pinkAccent : Colors.blueAccent,
      size: size * 0.7,
    );
  }
}
