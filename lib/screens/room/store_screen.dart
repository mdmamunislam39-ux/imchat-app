import 'package:flutter/material.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

/// Store screen for purchasing items with diamonds
class StoreScreen extends StatefulWidget {
  final User currentUser;
  final WalletService walletService;
  final StoreService storeService;

  const StoreScreen({
    super.key,
    required this.currentUser,
    required this.walletService,
    required this.storeService,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
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
    return Obx(() {
      final user = AuthController.instance.currentUser;
      return DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Store'),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(color: Colors.black),
            iconTheme: const IconThemeData(color: Colors.black),
            titleTextStyle: const TextStyle(
                color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            actions: [
              // Coins Balance (Displayed as Diamonds)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond, color: Colors.pink, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${user.diamonds}',
                      style: const TextStyle(
                        color: Colors.pink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _StoreTab(
                type: 'avatarFrame',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
              _StoreTab(
                type: 'entryEffect',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
              _StoreTab(
                type: 'backgroundTheme',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
              _StoreTab(
                type: 'roomTheme',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
              _StoreTab(
                type: 'micRefill',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _StoreTab extends StatefulWidget {
  final String type;
  final User currentUser;
  final WalletService walletService;
  final StoreService storeService;
  final VoidCallback onPurchaseSuccess;

  const _StoreTab({
    required this.type,
    required this.currentUser,
    required this.walletService,
    required this.storeService,
    required this.onPurchaseSuccess,
  });

  @override
  State<_StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<_StoreTab> {
  List<Map<String, dynamic>> _items = [];
  Set<String> _ownedItemIds = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant _StoreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.customization?.selectedBadgeId !=
            widget.currentUser.customization?.selectedBadgeId ||
        oldWidget.currentUser.customization?.selectedFrameId !=
            widget.currentUser.customization?.selectedFrameId ||
        oldWidget.currentUser.customization?.selectedEntryEffectId !=
            widget.currentUser.customization?.selectedEntryEffectId ||
        oldWidget.currentUser.customization?.selectedBackgroundThemeId !=
            widget.currentUser.customization?.selectedBackgroundThemeId ||
        oldWidget.currentUser.customization?.selectedMicRefillId !=
            widget.currentUser.customization?.selectedMicRefillId ||
        oldWidget.currentUser != widget.currentUser) {
      setState(() {});
    }
  }

  void _showLivePreview(BuildContext context, Map<String, dynamic> item, String type) {
    final name = item['name'] as String? ?? 'Unknown';
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
            const SizedBox(height: 8),
            Text(
              item['expirationDuration'] != null ? 'Validity: ${item['expirationDuration']} Days' : 'Permanent',
              style: const TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
                        if (type == 'avatarFrame' || type == 'frame')
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFA42D),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: CachedCircleAvatar(
                                  imageUrl: widget.currentUser.photoUrl,
                                  radius: 35,
                                  isOnline: widget.currentUser.isOnline,
                                ),
                              ),
                              SizedBox(
                                width: 105,
                                height: 105,
                                child: UniversalAssetWidget(
                                  url: fileUrl,
                                  fit: BoxFit.cover,
                                  isAlphaVideo: true,
                                ),
                              ),
                            ],
                          )
                        else if (type == 'backgroundTheme' || type == 'profileSkin' || type == 'roomTheme')
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
                                      if (type == 'roomTheme')
                                        const Icon(Icons.mic, size: 40, color: Colors.white)
                                      else
                                        CircleAvatar(
                                          radius: 35,
                                          backgroundColor: Colors.white24,
                                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                                        ),
                                      const SizedBox(height: 10),
                                      Text(
                                        type == 'roomTheme' ? 'Simulated Voice Room Background' : 'Simulated Profile Page Skin',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                                      ),
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _purchaseItem(item);
                      },
                      icon: const Icon(Icons.shopping_cart, size: 18),
                      label: const Text('Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showGiftDialog(item);
                      },
                      icon: const Icon(Icons.card_giftcard, size: 18),
                      label: const Text('Send to Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadItems() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      final itemsFuture = widget.storeService.getStoreItemsByType(widget.type);
      final ownedItemsFuture = widget.storeService
          .getUserStoreItemsByType(widget.currentUser.userId, widget.type);

      final results = await Future.wait([itemsFuture, ownedItemsFuture]);
      final items = results[0];
      final ownedItems = results[1];

      if (mounted) {
        setState(() {
          _items = items;
          _ownedItemIds =
              ownedItems.map((item) => item['storeItemId'] as String).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load items: $e';
        });
      }
    }
  }

  Future<void> _equipItem(Map<String, dynamic> item) async {
    try {
      final itemId = item['id'] as String;
      final itemName = item['name'] as String;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipping $itemName...')),
      );

      await widget.storeService.equipItem(
        widget.currentUser.userId,
        itemId,
        widget.type,
      );

      widget.onPurchaseSuccess(); // Refresh user data

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

  Future<void> _unequipItem(Map<String, dynamic> item) async {
    try {
      final itemName = item['name'] as String;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unequipping $itemName...')),
      );

      await widget.storeService.unequipItem(
        widget.currentUser.userId,
        widget.type,
      );

      widget.onPurchaseSuccess(); // Refresh user data

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

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    try {
      final itemId = item['id'] as String;
      final itemName = item['name'] as String;

      // Determine currency and cost
      final diamondPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;
      final int cost = diamondPrice;

      final currentBalance = widget.currentUser.diamonds;

      if (currentBalance < cost) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient diamonds. You need $cost diamonds.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Purchase'),
          content: Text(
              'Are you sure you want to purchase "$itemName" for $cost diamonds?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Purchase'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchasing $itemName...')),
        );

        await widget.walletService.purchaseStoreItem(
          userId: widget.currentUser.userId,
          storeItemId: itemId,
          cost: cost,
          description: 'Purchased $itemName',
        );

        // Update local ownership state immediately
        setState(() {
          _ownedItemIds.add(itemId);
        });

        widget.onPurchaseSuccess();

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased $itemName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGiftDialog(Map<String, dynamic> item) {
    final TextEditingController searchIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Gift to Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter the Search ID of the friend you want to gift "${item['name']}" to.'),
              const SizedBox(height: 16),
              TextField(
                controller: searchIdController,
                decoration: InputDecoration(
                  labelText: 'Friend\'s Search ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.search),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final searchId = searchIdController.text.trim();
                if (searchId.isNotEmpty) {
                  Navigator.pop(context);
                  _giftItemToFriend(item, searchId);
                }
              },
              child: const Text('Search & Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _giftItemToFriend(Map<String, dynamic> item, String searchId) async {
    try {
      // Find user by searchId
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('searchId', isEqualTo: searchId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found with this Search ID'), backgroundColor: Colors.red),
        );
        return;
      }

      final receiverDoc = querySnapshot.docs.first;
      final receiverId = receiverDoc.id;
      final receiverName = receiverDoc.data()['fullname'] ?? 'Unknown User';

      final itemId = item['id'] as String;
      final itemName = item['name'] as String;
      final diamondPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;
      final cost = diamondPrice;

      // Confirm dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Gift'),
          content: Text('Are you sure you want to spend $cost diamonds to send "$itemName" to $receiverName?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      );

      if (confirmed == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sending gift to $receiverName...')));

        await widget.walletService.giftStoreItem(
          senderId: widget.currentUser.userId,
          receiverId: receiverId,
          storeItemId: itemId,
          cost: cost,
          description: 'Gifted $itemName to $receiverName',
        );

        // Refresh sender balance
        widget.onPurchaseSuccess();

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully gifted $itemName to $receiverName!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send gift: $e'), backgroundColor: Colors.red),
      );
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
              onPressed: _loadItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No items available in this category',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.70, // Slightly taller for equip buttons
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildStoreItemCard(item);
      },
    );
  }

  Widget _buildStoreItemCard(Map<String, dynamic> item) {
    debugPrint('🖼️ Item data: $item'); // Debug print to check keys

    final itemId = item['id'] as String;
    final name = item['name'] as String? ?? 'Unknown Item';
    final description = item['description'] as String? ?? '';

    // Price Logic
    final int price = (item['diamondPrice'] as num?)?.toInt() ?? 0;

    // Always show as diamonds (PINK/DIAMOND ICON)
    const Color priceColor = Colors.pink;
    const IconData priceIcon = Icons.diamond;

    // Check ownership and equipment
    final bool isOwned = _ownedItemIds.contains(itemId);

    // Determine equipped status based on type
    String? currentEquippedId;
    final customization = widget.currentUser.customization;
    if (customization != null) {
      switch (widget.type) {
        case 'badge':
          currentEquippedId = customization.selectedBadgeId;
          break;
        case 'avatarFrame':
        case 'frame':
          currentEquippedId = customization.selectedFrameId;
          break;
        case 'entryEffect':
          currentEquippedId = customization.selectedEntryEffectId;
          break;
        case 'backgroundTheme':
        case 'profileSkin':
          currentEquippedId = customization.selectedBackgroundThemeId;
          break;
        case 'micRefill':
          currentEquippedId = customization.selectedMicRefillId;
          break;
      }
    }

    final bool isEquipped = currentEquippedId == itemId;

    // Check multiple possible keys for the image
    String? imageUrl = (item['thumbnailUrl'] ??
        item['fileUrl'] ??
        item['imageUrl'] ??
        item['image'] ??
        item['icon']) as String?;

    // Validate URL
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = null;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  _showLivePreview(context, item, widget.type);
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
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(12)),
                        child: imageUrl.toLowerCase().endsWith('.svg')
                            ? SvgPicture.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                placeholderBuilder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : UniversalAssetWidget(
                                url: imageUrl,
                                fit: BoxFit.cover,
                                isAlphaVideo: true,
                              ),
                      )
                    : const Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            ),
          ),
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
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['expirationDuration'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Validity: ${item['expirationDuration']} Days',
                      style: const TextStyle(fontSize: 10, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isOwned)
                      Row(
                        children: [
                          Icon(priceIcon, size: 14, color: priceColor),
                          const SizedBox(width: 2),
                          Text(
                            '$price',
                            style: TextStyle(
                                color: priceColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    SizedBox(
                      height: 30,
                      child: isOwned
                          ? widget.type == 'roomTheme'
                              ? OutlinedButton(
                                  onPressed: null,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.grey),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: const Text('Equip in Room',
                                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                                )
                              : isEquipped
                                  ? OutlinedButton(
                                      onPressed: () => _unequipItem(item),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.grey),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                      ),
                                      child: const Text('Unequip',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _equipItem(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                      ),
                                      child: const Text('Equip',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.white)),
                                    )
                          : ElevatedButton(
                              onPressed: () => _purchaseItem(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: priceColor,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text('Purchase',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white)),
                            ),
                    ),
                  ],
                ),
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
