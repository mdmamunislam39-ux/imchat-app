import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DecorationWallPage extends StatefulWidget {
  final String userID;
  final String userName;

  /// Initial items passed from the profile page. The wall will also
  /// do a fresh live fetch on open so it always shows all items.
  final List<Map<String, dynamic>> decorationItems;

  const DecorationWallPage({
    super.key,
    required this.userID,
    required this.userName,
    required this.decorationItems,
  });

  @override
  State<DecorationWallPage> createState() => _DecorationWallPageState();
}

class _DecorationWallPageState extends State<DecorationWallPage> {
  static const _decorationTypes = [
    'avatarFrame',
    'frame',
    'entryEffect',
    'backgroundTheme',
    'profileSkin',
    'roomTheme',
    'nameplate',
    'micRefill',
    'roomProfileBackground',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StoreService _storeService = StoreService();

  late List<Map<String, dynamic>> _items;
  bool _isLoading = false;
  Timer? _realtimeTimer;
  StreamSubscription<QuerySnapshot>? _storeStreamSubscription;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.decorationItems);
    _loadLive();
    _subscribeToRealtimeStoreItems();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeToRealtimeStoreItems() {
    _storeStreamSubscription?.cancel();
    _storeStreamSubscription = _firestore
        .collection('user_store_items')
        .where('userId', isEqualTo: widget.userID)
        .snapshots()
        .listen((snapshot) {
      _loadLive();
    }, onError: (e) {
      debugPrint('Decoration wall live listen error: $e');
    });
  }

  @override
  void dispose() {
    _storeStreamSubscription?.cancel();
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLive() async {
    if (_items.isEmpty) setState(() => _isLoading = true);
    try {
      final futures = _decorationTypes.map(
        (type) => _firestore
            .collection('user_store_items')
            .where('userId', isEqualTo: widget.userID)
            .where('itemType', isEqualTo: type)
            .where('isActive', isEqualTo: true)
            .limit(50)
            .get(),
      );
      final results = await Future.wait(futures);

      final List<Map<String, dynamic>> loaded = [];
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final itemType = data['itemType'] as String? ?? '';
          final entry = <String, dynamic>{
            'id': doc.id,
            'storeItemId': data['storeItemId'] ?? '',
            'storeItemName': data['storeItemName'] ?? 'Item',
            'itemType': itemType,
            'expiresAt': data['expiresAt'],
            'assignedAt': data['assignedAt'],
          };
          final storeItemId = entry['storeItemId'] as String;
          if (storeItemId.isNotEmpty) {
            try {
              final details = await _storeService.getStoreItemDetails(storeItemId);
              if (details != null) {
                entry['imageUrl'] = details['thumbnailUrl'] ??
                    details['fileUrl'] ??
                    details['imageUrl'] ??
                    details['image'];
                entry['description'] = details['description'] ?? '';
                entry['starRating'] = details['starRating'] ?? 1;
              }
            } catch (_) {}
          }
          loaded.add(entry);
        }
      }
      
      final Map<String, Map<String, dynamic>> dedup = {};
      for (final entry in loaded) {
        final storeItemId = entry['storeItemId'] as String?;
        if (storeItemId != null && storeItemId.isNotEmpty) {
          if (!dedup.containsKey(storeItemId)) {
            dedup[storeItemId] = entry;
          } else {
            final currentExp = entry['expiresAt'] as Timestamp?;
            final existingExp = dedup[storeItemId]!['expiresAt'] as Timestamp?;
            if (currentExp == null && existingExp != null) {
              dedup[storeItemId] = entry;
            } else if (currentExp != null && existingExp != null) {
              if (currentExp.toDate().isAfter(existingExp.toDate())) {
                dedup[storeItemId] = entry;
              }
            }
          }
        } else {
          dedup[entry['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()] = entry;
        }
      }
      
      final now = DateTime.now();
      final List<Map<String, dynamic>> uniqueLoaded = dedup.values.where((item) {
        final exp = item['expiresAt'] as Timestamp?;
        if (exp == null) return true;
        return exp.toDate().isAfter(now);
      }).toList();

      // Sort by starRating DESC, then assignedAt DESC
      uniqueLoaded.sort((a, b) {
        final int starA = a['starRating'] as int? ?? 1;
        final int starB = b['starRating'] as int? ?? 1;
        final cmp = starB.compareTo(starA);
        if (cmp != 0) return cmp;
        
        final dateA = a['assignedAt'] as Timestamp?;
        final dateB = b['assignedAt'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _items = uniqueLoaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ DecorationWallPage: Error loading items: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _typeLabel(String itemType) {
    switch (itemType) {
      case 'avatarFrame':
        return 'Frame';
      case 'entryEffect':
        return 'Entry Effect';
      case 'backgroundTheme':
      case 'profileSkin':
        return 'Profile Skin';
      case 'nameplate':
        return 'Nameplate';
      case 'roomProfileBackground':
        return 'Room Background';
      default:
        return itemType.isNotEmpty ? itemType : 'Decoration';
    }
  }

  Color _typeColor(String itemType) {
    switch (itemType) {
      case 'avatarFrame':
        return const Color(0xFF00BCD4); // cyan
      case 'entryEffect':
        return const Color(0xFF7C4DFF); // deep purple
      case 'backgroundTheme':
      case 'profileSkin':
        return const Color(0xFF4CAF50); // green
      case 'nameplate':
        return const Color(0xFFFF9800); // orange
      case 'roomProfileBackground':
        return const Color(0xFF9C27B0); // purple
      default:
        return Colors.teal;
    }
  }

  IconData _typeIcon(String itemType) {
    switch (itemType) {
      case 'avatarFrame':
        return Icons.crop_free_rounded;
      case 'entryEffect':
        return Icons.auto_awesome;
      case 'backgroundTheme':
      case 'profileSkin':
        return Icons.wallpaper_rounded;
      case 'nameplate':
        return Icons.badge_outlined;
      case 'roomProfileBackground':
        return Icons.image_rounded;
      default:
        return Icons.palette_rounded;
    }
  }

  String _formatExpiryDate(dynamic expiresAt) {
    if (expiresAt == null) return 'Permanent';
    DateTime? date;
    if (expiresAt is Timestamp) {
      date = expiresAt.toDate();
    } else if (expiresAt is DateTime) {
      date = expiresAt;
    }
    if (date == null) return 'Permanent';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ── Details dialog ────────────────────────────────────────────────────────

  void _showDetails(Map<String, dynamic> item) {
    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;
    final name = item['storeItemName'] as String? ?? 'Item';
    final imageUrl = item['imageUrl'] as String?;
    final description = item['description'] as String?;
    final itemType = item['itemType'] as String? ?? '';
    final storeItemId = item['storeItemId'] as String? ?? '';
    final expiresAt = item['expiresAt'];
    final accentColor = _typeColor(itemType);

    String? getEquippedId(String type) {
      final customization = currentUser.customization;
      if (customization == null) return null;
      switch (type) {
        case 'badge':
          return customization.selectedBadgeId;
        case 'avatarFrame':
        case 'frame':
          return customization.selectedFrameId;
        case 'entryEffect':
          return customization.selectedEntryEffectId;
        case 'backgroundTheme':
        case 'profileSkin':
          return customization.selectedBackgroundThemeId;
        case 'nameplate':
          return customization.selectedNameplateId;
        case 'roomProfileBackground':
          return customization.selectedRoomProfileBackgroundId;
        default:
          return null;
      }
    }
    
    final equippedId = getEquippedId(itemType);
    final isEquipped = equippedId == storeItemId;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(itemType), size: 13, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      _typeLabel(itemType),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Image
              Container(
                height: 120,
                width: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? (imageUrl.toLowerCase().endsWith('.svg')
                        ? SvgPicture.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              _typeIcon(itemType),
                              size: 58,
                              color: accentColor,
                            ),
                          ))
                    : Icon(_typeIcon(itemType), size: 58, color: accentColor),
              ),
              const SizedBox(height: 14),
              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              // Expiry
              if (expiresAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Expires: ${_formatExpiryDate(expiresAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Owner actions
              if (isOwner && storeItemId.isNotEmpty && itemType.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(isEquipped ? Icons.remove_circle_outline : Icons.check_circle_outline, size: 17),
                        label: Text(isEquipped ? 'Remove' : 'Use'),
                        onPressed: () async {
                          if (isEquipped) {
                            try {
                              await _storeService.unequipItem(
                                currentUser.userId,
                                itemType,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('"$name" removed!'),
                                  backgroundColor: Colors.grey.shade700,
                                ));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          } else {
                            try {
                              await _storeService.equipItem(
                                currentUser.userId,
                                storeItemId,
                                itemType,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('"$name" equipped!'),
                                  backgroundColor: accentColor,
                                ));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          setState(() {}); // Refresh state
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped ? Colors.grey.shade700 : accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              // Close
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final validItems = _items.where((item) {
      final exp = item['expiresAt'] as Timestamp?;
      if (exp == null) return true;
      return exp.toDate().isAfter(now);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: Text(
          '${widget.userName}\'s Decorations',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            )
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.palette_outlined,
                          size: 64, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'No decoration items yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: validItems.length,
                  itemBuilder: (context, index) {
                    final item = validItems[index];
                    final imageUrl = item['imageUrl'] as String?;
                    final name = item['storeItemName'] as String? ?? 'Item';
                    final itemType = item['itemType'] as String? ?? '';
                    final accentColor = _typeColor(itemType);

                    return GestureDetector(
                      onTap: () => _showDetails(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? (imageUrl.toLowerCase().endsWith('.svg')
                                        ? SvgPicture.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            placeholderBuilder: (_) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        : Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                              _typeIcon(itemType),
                                              color: accentColor,
                                              size: 32,
                                            ),
                                          ))
                                    : Icon(
                                        _typeIcon(itemType),
                                        color: accentColor,
                                        size: 32,
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Star Rating Badge
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${item['starRating'] ?? 1}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
