import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

class LevelListItem extends StatelessWidget {
  final Map<String, dynamic> levelData;

  const LevelListItem({
    Key? key,
    required this.levelData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int levelNumber = levelData['levelNumber'] ?? 0;
    final String? imageUrl = levelData['imageUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Level Range (e.g. Lv. 1)
          Expanded(
            flex: 2,
            child: Text(
              'Lv. $levelNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          
          // Level Icon
          Expanded(
            flex: 2,
            child: Center(
              child: _buildBadge(imageUrl),
            ),
          ),
          
          // Entry Effect
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildDiamondRequirement(levelData['diamondRequirement']),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String? url) {
    if (url == null || url.isEmpty) {
      return const SizedBox(width: 40, height: 40);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        width: 20, 
        height: 20, 
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error, size: 20),
    );
  }

  Widget _buildDiamondRequirement(dynamic diamondReq) {
    // Determine the requirement value
    final num requirement = diamondReq != null ? (diamondReq as num) : 0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DynamicDiamondIcon(width: 18, height: 18),
        const SizedBox(width: 4),
        Text(
          requirement.toInt().toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: 
            FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }


}
