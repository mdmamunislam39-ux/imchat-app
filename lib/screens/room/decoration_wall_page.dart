import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/screens/room/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

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
    'nameplate',
    'svipTag',
    'roomTheme',
    'micRefill',
    'roomProfileBackground',
    'shortProfileTheme',
    'roomEntry',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StoreService _storeService = StoreService();
  final WalletService _walletService = WalletService();

  late List<Map<String, dynamic>> _items;
  bool _isLoading = false;
  Timer? _realtimeTimer;
  StreamSubscription<QuerySnapshot>? _storeStreamSubscription;

  int _getStarRating(dynamic rating) {
    if (rating == null) return 1;
    if (rating is num) return rating.toInt();
    if (rating is String) {
      return int.tryParse(rating) ?? 1;
    }
    return 1;
  }

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
            'storeItemName': data['storeItemName'] ?? data['name'] ?? 'Item',
            'itemType': itemType,
            'expiresAt': data['expiresAt'],
            'assignedAt': data['assignedAt'],
            'imageUrl': data['imageUrl'] ?? data['thumbnailUrl'] ?? data['fileUrl'] ?? data['image'] ?? '',
            'fileUrl': data['fileUrl'] ?? data['imageUrl'] ?? '',
            'thumbnailUrl': data['thumbnailUrl'] ?? data['imageUrl'] ?? '',
            'description': data['description'] ?? '',
            'starRating': _getStarRating(data['starRating']),
          };
          final storeItemId = entry['storeItemId'] as String;
          if (storeItemId.isNotEmpty) {
            try {
              final details = await _storeService.getStoreItemDetails(storeItemId);
              if (details != null) {
                entry['imageUrl'] = details['thumbnailUrl'] ??
                    details['fileUrl'] ??
                    details['imageUrl'] ??
                    details['image'] ??
                    entry['imageUrl'];
                entry['description'] = details['description'] ?? entry['description'];
                entry['starRating'] = _getStarRating(details['starRating'] ?? entry['starRating']);
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
        final int starA = _getStarRating(a['starRating']);
        final int starB = _getStarRating(b['starRating']);
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
      case 'shortProfileTheme':
        return 'Short Profile Theme';
      case 'roomEntry':
        return 'Room Entry';
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
      case 'shortProfileTheme':
        return const Color(0xFFE91E63); // pink
      case 'roomEntry':
        return const Color(0xFF00E676); // emerald green
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
      case 'shortProfileTheme':
        return Icons.portrait_rounded;
      case 'roomEntry':
        return Icons.login_rounded;
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

    final customization = currentUser.customization;
    String? getEquippedId(String type, UserCustomization? c) {
      if (c == null) return null;
      switch (type) {
        case 'badge':
          return c.selectedBadgeId;
        case 'avatarFrame':
        case 'frame':
          return c.selectedFrameId;
        case 'entryEffect':
          return c.selectedEntryEffectId;
        case 'backgroundTheme':
        case 'profileSkin':
          return c.selectedBackgroundThemeId;
        case 'nameplate':
          return c.selectedNameplateId;
        case 'roomProfileBackground':
          return c.selectedRoomProfileBackgroundId;
        case 'shortProfileTheme':
          return c.selectedShortProfileThemeId;
        case 'roomEntry':
          return c.selectedRoomEntryId;
        default:
          return null;
      }
    }

    // Compute initial equipped state
    bool initialEquipped = itemType == 'nameplate'
        ? (customization?.selectedNameplateIds.contains(storeItemId) ?? false)
        : (customization != null && getEquippedId(itemType, customization) == storeItemId);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool isEquipped = initialEquipped;
          return Dialog(
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
                            : UniversalAssetWidget(
                                key: ValueKey(imageUrl),
                                url: imageUrl,
                                fit: BoxFit.contain,
                                isAlphaVideo: false,
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
                                    storeItemId,
                                  );
                                  // Update local dialog state immediately
                                  setDialogState(() => initialEquipped = false);
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
                                  // Update local dialog state immediately
                                  setDialogState(() => initialEquipped = true);
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
                              if (mounted) setState(() {}); // Refresh wall
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
          );
        },
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

    // Group items by starRating
    final Map<int, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in validItems) {
      final int rating = _getStarRating(item['starRating']);
      groupedItems.putIfAbsent(rating, () => []).add(item);
    }

    // Sort ratings descending
    final sortedRatings = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

    // Calculate total stats
    final int totalStars = validItems.fold<int>(0, (acc, item) => acc + _getStarRating(item['starRating']));
    final int totalItems = validItems.length;

    // Local badge color mapper
    Color getBadgeColor(int stars) {
      switch (stars) {
        case 5:
          return const Color(0xFFFFD23F); // Gold
        case 4:
          return const Color(0xFFFF9F1C); // Orange
        case 3:
          return const Color(0xFFFF5252); // Red-Orange
        case 2:
          return const Color(0xFFB388FF); // Purple
        case 1:
        default:
          return const Color(0xFF2EC4B6); // Teal
      }
    }

    // Dynamic friend ranking logic (deterministic based on stars/items)
    int rankVal = 1000 - (totalStars * 12) - (totalItems * 4);
    if (rankVal < 1) rankVal = 1;
    final rankText = totalStars == 0 ? "Unranked" : "No.$rankVal";

    Widget buildChestIcon() {
      return Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.35),
              Colors.amber.withValues(alpha: 0.0),
            ],
            radius: 0.65,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Light rays glow
            Positioned(
              top: 4,
              child: Container(
                width: 44,
                height: 20,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.7),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
            // White chest/box
            Container(
              width: 52,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Lid separator line
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 2,
                      color: Colors.grey,
                    ),
                  ),
                  // Lock latch
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget header = Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          buildChestIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Decoration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Stars Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$totalStars',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Divider
                    Container(
                      height: 14,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    // Items Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.backpack_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$totalItems',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    text: 'Ranked ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: rankText,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ' among friends',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    List<Widget> buildGrids() {
      final List<Widget> list = [];
      for (int i = 0; i < sortedRatings.length; i++) {
        final rating = sortedRatings[i];
        final items = groupedItems[rating]!;
        
        list.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.80,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = item['imageUrl'] as String?;
              final name = item['storeItemName'] as String? ?? 'Item';
              final itemType = item['itemType'] as String? ?? '';
              final accentColor = _typeColor(itemType);

              return GestureDetector(
                onTap: () => _showDetails(item),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16171C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          alignment: Alignment.center,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? (imageUrl.toLowerCase().endsWith('.svg')
                                  ? SvgPicture.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      placeholderBuilder: (_) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : UniversalAssetWidget(
                                      key: ValueKey(imageUrl),
                                      url: imageUrl,
                                      fit: BoxFit.contain,
                                      isAlphaVideo: false,
                                    ))
                              : Icon(
                                  _typeIcon(itemType),
                                  color: accentColor,
                                  size: 32,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
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
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: getBadgeColor(rating),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: rating == 5 ? Colors.black87 : Colors.white,
                                    size: 8,
                                  ),
                                  Text(
                                    '$rating',
                                    style: TextStyle(
                                      color: rating == 5 ? Colors.black87 : Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
        if (i < sortedRatings.length - 1) {
          list.add(const SizedBox(height: 8));
        }
      }
      return list;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            )
          : validItems.isEmpty
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
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      ...buildGrids(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
      bottomNavigationBar: Container(
        color: const Color(0xFF0F1014),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 10 + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              final currentUser = AuthController.instance.currentUser;
              Get.to(() => StoreScreen(
                    currentUser: currentUser,
                    walletService: _walletService,
                    storeService: _storeService,
                  ));
            },
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
            label: const Text(
              'Store',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0091FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
