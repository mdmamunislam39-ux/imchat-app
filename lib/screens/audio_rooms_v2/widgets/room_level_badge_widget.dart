import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

/// A widget that displays the room level badge (PNG) or a fallback text badge.
/// It uses a static cache to avoid redundant Firestore queries across multiple instances.
class RoomLevelBadgeWidget extends StatefulWidget {
  final int totalRevenue;
  final double height;
  final double? width;

  const RoomLevelBadgeWidget({
    super.key,
    required this.totalRevenue,
    this.height = 20,
    this.width,
  });

  @override
  State<RoomLevelBadgeWidget> createState() => _RoomLevelBadgeWidgetState();
}

class _RoomLevelBadgeWidgetState extends State<RoomLevelBadgeWidget> {
  static List<dynamic>? _cachedRoomLevelConfig;
  static bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (_cachedRoomLevelConfig != null || _isLoading) return;
    
    _isLoading = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('level_configurations')
          .doc('room_config')
          .get();
          
      if (doc.exists) {
        final levels = doc.data()?['levels'] as List<dynamic>?;
        if (mounted) {
          setState(() {
            _cachedRoomLevelConfig = levels;
          });
        } else {
          _cachedRoomLevelConfig = levels;
        }
      }
    } catch (e) {
      debugPrint('Error loading room config for badge: $e');
    } finally {
      _isLoading = false;
    }
  }

  String? _getDynamicRoomLevelBadgeUrl() {
    if (_cachedRoomLevelConfig == null) return null;
    final currentLevel = AudioRoomV2.calculateRoomLevel(widget.totalRevenue, _cachedRoomLevelConfig);
    for (final lvl in _cachedRoomLevelConfig!) {
      if (lvl['levelNumber'] == currentLevel) {
        return lvl['imageUrl'] as String?;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _getDynamicRoomLevelBadgeUrl();
    
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.contain,
        errorWidget: (context, error, stackTrace) => _buildFallbackBadge(),
      );
    }
    
    return _buildFallbackBadge();
  }
  
  Widget _buildFallbackBadge() {
    final level = AudioRoomV2.calculateRoomLevel(widget.totalRevenue, _cachedRoomLevelConfig);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
