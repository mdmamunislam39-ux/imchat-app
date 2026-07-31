import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class BadgeWallPage extends StatefulWidget {
  final String userID;
  final String userName;
  final List<Map<String, dynamic>> badgeItems;

  const BadgeWallPage({
    super.key,
    required this.userID,
    required this.userName,
    required this.badgeItems,
  });

  @override
  State<BadgeWallPage> createState() => _BadgeWallPageState();
}

class _BadgeWallPageState extends State<BadgeWallPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StoreService _storeService = StoreService();
  late List<Map<String, dynamic>> _badges;
  bool _isLoading = false;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _badges = List<Map<String, dynamic>>.from(widget.badgeItems);
    _loadBadgesLive();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBadgesLive() async {
    if (_badges.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final badgeDocs = await _firestore
          .collection('user_store_items')
          .where('userId', isEqualTo: widget.userID)
          .where('itemType', isEqualTo: 'badge')
          .where('isActive', isEqualTo: true)
          .limit(100)
          .get();

      if (badgeDocs.docs.isNotEmpty) {
        final List<Map<String, dynamic>> loadedBadges = badgeDocs.docs.map((
          doc,
        ) {
          final data = doc.data();
          return {
            'id': doc.id,
            'storeItemId': data['storeItemId'] ?? '',
            'storeItemName': data['storeItemName'] ?? 'Badge',
            'expiresAt': data['expiresAt'],
            'assignedAt': data['assignedAt'],
          };
        }).toList();

        // Load badge details from market_items
        for (int i = 0; i < loadedBadges.length; i++) {
          final storeItemId = loadedBadges[i]['storeItemId'] as String;
          if (storeItemId.isNotEmpty) {
            try {
              final details = await _storeService.getStoreItemDetails(
                storeItemId,
              );
              if (details != null) {
                loadedBadges[i]['imageUrl'] =
                    details['thumbnailUrl'] ??
                    details['fileUrl'] ??
                    details['imageUrl'] ??
                    details['image'];
                loadedBadges[i]['description'] =
                    details['description'] ??
                    'A prestigious badge representing user achievements.';
              }
            } catch (_) {}
          }
        }

        // Deduplicate and filter expired
        final Map<String, Map<String, dynamic>> dedup = {};
        for (final entry in loadedBadges) {
          final storeItemId = entry['storeItemId'] as String?;
          if (storeItemId != null && storeItemId.isNotEmpty) {
            if (!dedup.containsKey(storeItemId)) {
              dedup[storeItemId] = entry;
            } else {
              final currentExp = entry['expiresAt'] as Timestamp?;
              final existingExp =
                  dedup[storeItemId]!['expiresAt'] as Timestamp?;
              if (currentExp == null && existingExp != null) {
                dedup[storeItemId] = entry;
              } else if (currentExp != null && existingExp != null) {
                if (currentExp.toDate().isAfter(existingExp.toDate())) {
                  dedup[storeItemId] = entry;
                }
              }
            }
          } else {
            dedup[entry['id'] ??
                    DateTime.now().microsecondsSinceEpoch.toString()] =
                entry;
          }
        }

        final List<Map<String, dynamic>> uniqueBadges = dedup.values.toList();

        if (mounted) {
          setState(() {
            _badges = uniqueBadges;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _badges = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading badges live on wall: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;
    final name = badge['storeItemName'] as String? ?? 'Badge';
    final imageUrl = badge['imageUrl'] as String?;
    final description =
        badge['description'] as String? ??
        'A prestigious badge representing user achievements.';
    final expiresAt = badge['expiresAt'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.purple.shade300.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade800.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Image Container with radial glowing backdrop
              Container(
                height: 120,
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.3),
                      Colors.purple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield,
                          size: 64,
                          color: Colors.amber,
                        ),
                      )
                    : const Icon(Icons.shield, size: 64, color: Colors.amber),
              ),
              const SizedBox(height: 16),
              // Badge Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Outfit',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Expiry Section if Owner
              if (isOwner) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Colors.purple.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expires: ${_formatExpiryDate(expiresAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.purple.shade200,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final validBadges = _badges.where((badge) {
      final exp = badge['expiresAt'] as Timestamp?;
      if (exp == null) return true;
      return exp.toDate().isAfter(now);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: Text(
          '${widget.userName}\'s Badge Wall',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            )
          : validBadges.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No badges earned yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: validBadges.length,
              itemBuilder: (context, index) {
                final badge = validBadges[index];
                final imageUrl = badge['imageUrl'] as String?;
                final name = badge['storeItemName'] as String? ?? 'Badge';

                return GestureDetector(
                  onTap: () => _showBadgeDetails(badge),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
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
                            margin: const EdgeInsets.only(
                              top: 12,
                              left: 12,
                              right: 12,
                            ),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.shield,
                                      color: Colors.purple,
                                      size: 36,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shield,
                                    color: Colors.purple,
                                    size: 36,
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
