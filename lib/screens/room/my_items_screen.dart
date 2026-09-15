import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Screen showing all purchased/owned items with equip/unequip functionality.
class MyItemsScreen extends StatefulWidget {
  final User currentUser;
  final StoreService storeService;
  final WalletService walletService;

  const MyItemsScreen({
    super.key,
    required this.currentUser,
    required this.storeService,
    required this.walletService,
  });

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    try {
      final user =
          await widget.walletService.getUserWallet(_currentUser.userId);
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Items'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: const TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          bottom: const TabBar(
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.pink,
            isScrollable: true,
            tabs: [
              Tab(text: 'Frames'),
              Tab(text: 'Entry Effects'),
              Tab(text: 'Profile Skins'),
              Tab(text: 'Room Themes'),
              Tab(text: 'Mic Refills'),
              Tab(text: 'Nameplates'),
              Tab(text: 'Room Profiles'),
              Tab(text: 'Short Profiles'),
              Tab(text: 'Room Entries'),
            ],
          ),
        ),
        body: Obx(() {
          final user = AuthController.instance.currentUser;
          return TabBarView(
            children: [
              _OwnedItemsTab(
                type: 'avatarFrame',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'entryEffect',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'backgroundTheme',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'roomTheme',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'micRefill',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'nameplate',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'roomProfileBackground',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'shortProfileTheme',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
              _OwnedItemsTab(
                type: 'roomEntry',
                currentUser: user,
                storeService: widget.storeService,
                onRefresh: _refreshUserData,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _OwnedItemsTab extends StatefulWidget {
  final String type;
  final User currentUser;
  final StoreService storeService;
  final VoidCallback onRefresh;

  const _OwnedItemsTab({
    required this.type,
    required this.currentUser,
    required this.storeService,
    required this.onRefresh,
  });

  @override
  State<_OwnedItemsTab> createState() => _OwnedItemsTabState();
}

class _OwnedItemsTabState extends State<_OwnedItemsTab> {
  List<Map<String, dynamic>> _ownedItems = [];
  // Map of storeItemId -> store item details (from market_items)
  final Map<String, Map<String, dynamic>> _itemDetails = {};
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<List<Map<String, dynamic>>>? _itemsSubscription;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _listenToOwnedItems();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OwnedItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.customization?.selectedBadgeId !=
            widget.currentUser.customization?.selectedBadgeId ||
        oldWidget.currentUser.customization?.selectedFrameId !=
            widget.currentUser.customization?.selectedFrameId ||
        oldWidget.currentUser.customization?.selectedEntryEffectId !=
            widget.currentUser.customization?.selectedEntryEffectId ||
        oldWidget.currentUser.customization?.selectedRoomEntryId !=
            widget.currentUser.customization?.selectedRoomEntryId ||
        oldWidget.currentUser.customization?.selectedBackgroundThemeId !=
            widget.currentUser.customization?.selectedBackgroundThemeId ||
        oldWidget.currentUser.customization?.selectedRoomThemeId !=
            widget.currentUser.customization?.selectedRoomThemeId ||
        oldWidget.currentUser.customization?.selectedMicRefillId !=
            widget.currentUser.customization?.selectedMicRefillId ||
        oldWidget.currentUser.customization?.selectedRoomProfileBackgroundId !=
            widget.currentUser.customization?.selectedRoomProfileBackgroundId ||
        oldWidget.currentUser != widget.currentUser) {
      setState(() {});
    }
  }

  void _showLivePreview(BuildContext context, Map<String, dynamic> item, String type) {
    final name = item['name'] as String? ?? item['storeItemName'] as String? ?? 'Unknown';
    final description = item['description'] as String? ?? '';
    final fileUrl = (item['fileUrl'] ?? item['thumbnailUrl'] ?? item['imageUrl'] ?? item['image'] ?? '') as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C2D35), Color(0xFF15161A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Use / Remove Button
            Builder(
              builder: (ctx) {
                  final storeItemId = item['storeItemId'] as String? ?? item['id'] as String? ?? '';
                  final equippedId = _getEquippedId();
                  final isEquipped = equippedId == storeItemId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (isEquipped) {
                            await _unequipItem(name);
                          } else {
                            await _equipItem(storeItemId, name);
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                        icon: Icon(
                          isEquipped ? Icons.remove_circle_outline : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text(isEquipped ? 'Remove' : 'Use'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped ? Colors.grey.shade700 : Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.08,
                            child: CustomPaint(
                              painter: GridPainter(),
                            ),
                          ),
                        ),
                        if (type == 'avatarFrame' || type == 'frame' || type == 'micRefill')
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.teal.shade800,
                                backgroundImage: (widget.currentUser.photoUrl.isNotEmpty &&
                                        widget.currentUser.photoUrl.startsWith('http'))
                                    ? CachedNetworkImageProvider(widget.currentUser.photoUrl)
                                    : null,
                                child: (widget.currentUser.photoUrl.isEmpty ||
                                        !widget.currentUser.photoUrl.startsWith('http'))
                                    ? const Icon(Icons.person, size: 55, color: Colors.white70)
                                    : null,
                              ),
                              SizedBox(
                                width: type == 'micRefill' ? 210 : 135,
                                height: type == 'micRefill' ? 210 : 135,
                                child: UniversalAssetWidget(
                                  key: ValueKey(fileUrl),
                                  url: fileUrl,
                                  fit: BoxFit.contain,
                                  isAlphaVideo: false,
                                ),
                              ),
                            ],
                          )
                        else if (type == 'badge')
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'VIP User Name',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: UniversalAssetWidget(
                                      url: fileUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Badge preview inside user profile banner',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          )
                        else if (type == 'backgroundTheme' || type == 'profileSkin')
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: UniversalAssetWidget(
                                    url: fileUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Container(color: Colors.black45),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.white24,
                                        child: const Icon(Icons.person, size: 40, color: Colors.white),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text('Simulated Profile Page Skin', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox.expand(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: UniversalAssetWidget(
                                url: fileUrl,
                                fit: BoxFit.contain,
                                isAlphaVideo: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.pinkAccent.withValues(alpha: 0.3),
                    elevation: 8,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listenToOwnedItems() {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      _itemsSubscription?.cancel();
      _itemsSubscription = widget.storeService
          .getUserStoreItemsByTypeStream(widget.currentUser.userId, widget.type)
          .listen((ownedItems) async {
        
        // Fetch full details for each new owned item from market_items
        final Map<String, Map<String, dynamic>> groupedItems = {};

        for (final owned in ownedItems) {
          final storeItemId = owned['storeItemId'] as String?;
          if (storeItemId == null) continue;

          if (groupedItems.containsKey(storeItemId)) {
            // Pick max expiresAt to extend validity visually
            final currentValidUntil = groupedItems[storeItemId]!['expiresAt'] as Timestamp?;
            final newValidUntil = owned['expiresAt'] as Timestamp?;
            
            if (currentValidUntil != null && newValidUntil != null) {
              if (newValidUntil.toDate().isAfter(currentValidUntil.toDate())) {
                groupedItems[storeItemId]!['expiresAt'] = newValidUntil;
              }
            } else if (newValidUntil != null) {
              groupedItems[storeItemId]!['expiresAt'] = newValidUntil;
            }
          } else {
            groupedItems[storeItemId] = Map<String, dynamic>.from(owned);
          }
        }
        
        final now = DateTime.now();
        final uniqueOwnedItems = groupedItems.values.where((item) {
          final exp = item['expiresAt'] as Timestamp?;
          if (exp == null) return true;
          return exp.toDate().isAfter(now);
        }).toList();

        for (final owned in uniqueOwnedItems) {
          final storeItemId = owned['storeItemId'] as String?;
          if (storeItemId != null && !_itemDetails.containsKey(storeItemId)) {
            try {
              final details =
                  await widget.storeService.getStoreItemDetails(storeItemId);
              if (details != null) {
                _itemDetails[storeItemId] = details;
                // Add starRating back to owned item so we can sort easily
                owned['starRating'] = details['starRating'] ?? 1;
              }
            } catch (e) {
              debugPrint('Failed to load details for $storeItemId: $e');
            }
          } else if (_itemDetails.containsKey(storeItemId)) {
            owned['starRating'] = _itemDetails[storeItemId]!['starRating'] ?? 1;
          }
        }

        // Sort by starRating DESC
        uniqueOwnedItems.sort((a, b) {
          final int starA = a['starRating'] as int? ?? 1;
          final int starB = b['starRating'] as int? ?? 1;
          return starB.compareTo(starA);
        });

        if (mounted) {
          setState(() {
            _ownedItems = uniqueOwnedItems;
            _isLoading = false;
          });
          
          // Auto-unequip if the currently equipped item is expired (missing from uniqueOwnedItems)
          final equippedId = _getEquippedId();
          if (equippedId != null && equippedId.isNotEmpty) {
            final isStillValid = uniqueOwnedItems.any((item) => item['storeItemId'] == equippedId);
            if (!isStillValid) {
               // Item is expired, unequip it
               widget.storeService.unequipItem(widget.currentUser.userId, widget.type).catchError((e) {
                 debugPrint('Failed to auto-unequip expired item $equippedId: $e');
                 return false;
               });
            }
          }
        }
      }, onError: (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load items: $e';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to setup stream: $e';
        });
      }
    }
  }

  Future<void> _equipItem(String storeItemId, String itemName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipping $itemName...')),
      );

      await widget.storeService.equipItem(
        widget.currentUser.userId,
        storeItemId,
        widget.type,
      );

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Equipped $itemName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to equip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unequipItem(String itemName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unequipping $itemName...')),
      );

      await widget.storeService.unequipItem(
        widget.currentUser.userId,
        widget.type,
      );

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unequipped $itemName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unequip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _getEquippedId() {
    final customization = widget.currentUser.customization;
    if (customization == null) return null;
    switch (widget.type) {
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
      case 'roomTheme':
        return customization.selectedRoomThemeId;
      case 'micRefill':
        return customization.selectedMicRefillId;
      case 'nameplate':
        return customization.selectedNameplateId;
      case 'roomEntry':
        return customization.selectedRoomEntryId;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _listenToOwnedItems();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final validItems = _ownedItems.where((item) {
      final exp = item['expiresAt'] as Timestamp?;
      if (exp == null) return true;
      return exp.toDate().isAfter(now);
    }).toList();

    if (validItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items owned in this category',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Visit the Store to purchase items',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: validItems.length,
      itemBuilder: (context, index) {
        return _buildOwnedItemCard(validItems[index]);
      },
    );
  }

  Widget _buildOwnedItemCard(Map<String, dynamic> ownedItem) {
    final storeItemId = ownedItem['storeItemId'] as String? ?? '';
    final details = _itemDetails[storeItemId];

    // Use details from market_items if available, fallback to user_store_items data
    final name =
        details?['name'] as String? ?? ownedItem['storeItemName'] as String? ?? 'Unknown Item';
    final description = details?['description'] as String? ?? '';

    // Get image from market_items details or fallback to user_store_items data
    String? imageUrl;
    if (details != null) {
      imageUrl = (details['thumbnailUrl'] ??
          details['fileUrl'] ??
          details['imageUrl'] ??
          details['image'] ??
          details['icon']) as String?;
    }
    imageUrl ??= (ownedItem['thumbnailUrl'] ??
        ownedItem['fileUrl'] ??
        ownedItem['imageUrl'] ??
        ownedItem['image'] ??
        ownedItem['icon']) as String?;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = null;
    }

    // Check equipped status
    final customization = widget.currentUser.customization;
    final bool isEquipped = widget.type == 'nameplate'
        ? (customization?.selectedNameplateIds.contains(storeItemId) ?? false)
        : (_getEquippedId() == storeItemId);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEquipped
            ? const BorderSide(color: Colors.pink, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      _showLivePreview(context, details ?? ownedItem, widget.type);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.grey[200],
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: imageUrl.toLowerCase().endsWith('.svg')
                                ? SvgPicture.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    placeholderBuilder: (context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : (widget.type == 'micRefill'
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Colors.teal.shade800,
                                            child: const Icon(Icons.person, size: 30, color: Colors.white70),
                                          ),
                                          SizedBox(
                                            width: 100,
                                            height: 100,
                                            child: UniversalAssetWidget(
                                              key: ValueKey(imageUrl),
                                              url: imageUrl,
                                              fit: BoxFit.contain,
                                              isAlphaVideo: false,
                                            ),
                                          ),
                                        ],
                                      )
                                    : UniversalAssetWidget(
                                        key: ValueKey(imageUrl),
                                        url: imageUrl,
                                        fit: (widget.type == 'avatarFrame' || widget.type == 'frame')
                                            ? BoxFit.contain
                                            : BoxFit.cover,
                                        isAlphaVideo: false,
                                      )),
                          )
                        : const Center(
                            child:
                                Icon(Icons.image, size: 48, color: Colors.grey)),
                  ),
                ),
                // Equipped badge
                if (isEquipped)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'EQUIPPED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Info + button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Star Rating Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${ownedItem['starRating'] ?? 1}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double squareSize = 8;
    final Paint lightPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final Paint darkPaint = Paint()..color = Colors.transparent;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final bool isLight = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

