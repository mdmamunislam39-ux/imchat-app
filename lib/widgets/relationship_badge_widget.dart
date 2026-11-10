import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

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

        return SizedBox(
          width: size,
          height: size,
          child: UniversalAssetWidget(
            key: ValueKey(badgeUrl),
            url: badgeUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            isAlphaVideo: true,
            errorWidget: _buildDefaultIcon(),
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
