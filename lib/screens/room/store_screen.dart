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
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

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
        length: 7,
        child: Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            title: Text('mall'.tr),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                child: const BackButton(color: Colors.black),
              ),
            ),
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
                    const DynamicDiamondIcon(width: 16, height: 16),
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
            bottom: TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
              isScrollable: true,
              tabs: [
                Tab(text: 'frames'.tr),
                Tab(text: 'entry_effects'.tr),
                Tab(text: 'profile_skins'.tr),
                Tab(text: 'room_themes'.tr),
                Tab(text: 'mic_refills'.tr),
                Tab(text: 'short_profiles'.tr),
                Tab(text: 'room_entries'.tr),
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
              _StoreTab(
                type: 'shortProfileTheme',
                currentUser: user,
                walletService: widget.walletService,
                storeService: widget.storeService,
                onPurchaseSuccess: _refreshUserData,
              ),
              _StoreTab(
                type: 'roomEntry',
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
        oldWidget.currentUser.customization?.selectedShortProfileThemeId !=
            widget.currentUser.customization?.selectedShortProfileThemeId ||
        oldWidget.currentUser != widget.currentUser) {
      setState(() {});
    }
  }

  void _showLivePreview(BuildContext context, Map<String, dynamic> item, String type) {
    final name = item['name'] as String? ?? 'Unknown';
    final description = item['description'] as String? ?? '';
    final fileUrl = (item['fileUrl'] ??
            item['animationUrl'] ??
            item['frameUrl'] ??
            item['frameMediaUrl'] ??
            item['svgaUrl'] ??
            item['assetUrl'] ??
            item['mediaUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '')
        .toString();

    final normalizedType = (item['type'] ?? item['category'] ?? type).toString().toLowerCase();
    final bool isFrame = normalizedType == 'avatarframe' ||
        normalizedType == 'frame' ||
        normalizedType == 'frames' ||
        normalizedType == 'avatar_frame';
    final bool isMicRefill = normalizedType == 'micrefill' || normalizedType == 'mic_refill';

    // Parse validity prices if available
    final Map<String, dynamic>? validityPrices = item['validityPrices'] != null
        ? Map<String, dynamic>.from(item['validityPrices'])
        : null;

    final int defaultPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;
    final int defaultDays = item['expirationDuration'] is int ? item['expirationDuration'] : 7;

    // Standard validity options
    final List<int> validityOptions = [3, 7, 15, 30];
    
    // Initial selected days
    int selectedDays = defaultDays > 0 && validityOptions.contains(defaultDays)
        ? defaultDays
        : 7;

    int getPriceForDays(int days) {
      if (validityPrices != null && validityPrices.containsKey(days.toString())) {
        final val = validityPrices[days.toString()];
        if (val is num) return val.round();
      }
      if (defaultDays > 0 && defaultPrice > 0) {
        return ((defaultPrice / defaultDays) * days).round();
      }
      return defaultPrice;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final int currentPrice = getPriceForDays(selectedDays);
          final String formattedPrice = currentPrice.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              );

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
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
                const SizedBox(height: 16),
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
                            if (isFrame || isMicRefill)
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isMicRefill)
                                    SizedBox(
                                      width: 140,
                                      height: 140,
                                      child: UniversalAssetWidget(
                                        key: ValueKey(fileUrl),
                                        url: fileUrl,
                                        fit: BoxFit.contain,
                                        isAlphaVideo: true,
                                      ),
                                    ),
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
                                      userId: widget.currentUser.userId,
                                      frameId: isMicRefill
                                          ? widget.currentUser.customization?.selectedFrameId
                                          : null,
                                      showFrame: isMicRefill,
                                      isOnline: widget.currentUser.isOnline,
                                    ),
                                  ),
                                  if (isFrame)
                                    SizedBox(
                                      width: 110,
                                      height: 110,
                                      child: UniversalAssetWidget(
                                        key: ValueKey(fileUrl),
                                        url: fileUrl,
                                        fit: BoxFit.contain,
                                        isAlphaVideo: true,
                                      ),
                                    ),
                                ],
                              )
                            else if (type == 'backgroundTheme' || type == 'profileSkin' || type == 'roomTheme' || type == 'shortProfileTheme')
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
                                              child: Icon(type == 'shortProfileTheme' ? Icons.portrait : Icons.person, size: 40, color: Colors.white),
                                            ),
                                          const SizedBox(height: 10),
                                          Text(
                                            type == 'roomTheme' ? 'Simulated Voice Room Background' : type == 'shortProfileTheme' ? 'Simulated Short Profile Theme' : 'Simulated Profile Page Skin',
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

                const SizedBox(height: 12),

                // ─── Select Validity Section (Matching Screenshot) ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Validity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: validityOptions.map((days) {
                            final bool isSelected = selectedDays == days;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10.0),
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    selectedDays = days;
                                  });
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1D61F2)
                                        : Colors.white.withAlpha(18),
                                    borderRadius: BorderRadius.circular(24),
                                    border: isSelected
                                        ? Border.all(color: Colors.blueAccent)
                                        : Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    '$days days',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Price Display Box (Matching Screenshot) ───
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Price',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                const DynamicDiamondIcon(width: 22, height: 22),
                                const SizedBox(width: 8),
                                Text(
                                  formattedPrice,
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _purchaseItem(item, selectedPrice: currentPrice, selectedValidityDays: selectedDays);
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
                              _showGiftDialog(item, selectedPrice: currentPrice, selectedValidityDays: selectedDays);
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
                ),
              ],
            ),
          );
        },
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

  Future<void> _purchaseItem(Map<String, dynamic> item, {int? selectedPrice, int? selectedValidityDays}) async {
    try {
      final itemId = item['id'] as String;
      final itemName = item['name'] as String;

      // Determine currency and cost
      final diamondPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;
      final int cost = selectedPrice ?? diamondPrice;

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
          description: 'Purchased $itemName (${selectedValidityDays ?? item['expirationDuration'] ?? 0} days)',
          validityDays: selectedValidityDays,
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

  void _showGiftDialog(Map<String, dynamic> item, {int? selectedPrice, int? selectedValidityDays}) {
    final TextEditingController searchIdController = TextEditingController();
    Map<String, dynamic>? foundUser;
    String? foundUserId;
    bool isSearching = false;
    String searchError = '';

    final itemName = item['name'] as String? ?? 'Item';
    final diamondPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> performSearch() async {
              final searchId = searchIdController.text.trim();
              if (searchId.isEmpty) return;

              setDialogState(() {
                isSearching = true;
                searchError = '';
                foundUser = null;
                foundUserId = null;
              });

              try {
                // 1. Search by searchId (String)
                var querySnapshot = await FirebaseFirestore.instance
                    .collection('Users')
                    .where('searchId', isEqualTo: searchId)
                    .limit(1)
                    .get();

                // 2. Search by searchId (int) if empty
                if (querySnapshot.docs.isEmpty) {
                  final numInput = int.tryParse(searchId);
                  if (numInput != null) {
                    querySnapshot = await FirebaseFirestore.instance
                        .collection('Users')
                        .where('searchId', isEqualTo: numInput)
                        .limit(1)
                        .get();
                  }
                }

                // 3. Search by doc ID if empty
                if (querySnapshot.docs.isEmpty) {
                  final doc = await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(searchId)
                      .get();
                  if (doc.exists) {
                    setDialogState(() {
                      foundUser = doc.data();
                      foundUserId = doc.id;
                      isSearching = false;
                    });
                    return;
                  }
                }

                if (querySnapshot.docs.isNotEmpty) {
                  final doc = querySnapshot.docs.first;
                  setDialogState(() {
                    foundUser = doc.data();
                    foundUserId = doc.id;
                    isSearching = false;
                  });
                } else {
                  setDialogState(() {
                    isSearching = false;
                    searchError = 'No user found with Search ID "$searchId"';
                  });
                }
              } catch (e) {
                setDialogState(() {
                  isSearching = false;
                  searchError = 'Search error: $e';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Send Gift to Friend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the Search ID of the friend you want to gift "$itemName" ($diamondPrice 💎) to.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchIdController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => performSearch(),
                      decoration: InputDecoration(
                        labelText: 'Friend\'s Search ID',
                        hintText: 'Enter ID (e.g. 123456)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.purpleAccent),
                          onPressed: performSearch,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    if (searchError.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          searchError,
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (foundUser != null) ...[
                      const Text(
                        'Recipient Profile:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CachedCircleAvatar(
                              imageUrl: (foundUser!['photoUrl'] ?? foundUser!['userPhoto'] ?? foundUser!['avatar'] ?? '') as String,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (foundUser!['fullname'] ?? foundUser!['username'] ?? foundUser!['name'] ?? 'User') as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${foundUser!['searchId'] ?? foundUserId ?? ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                if (foundUser == null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: performSearch,
                    child: const Text(
                      'Search User',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2A6D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _giftItemToUserDoc(
                        item,
                        foundUserId!,
                        (foundUser!['fullname'] ?? foundUser!['username'] ?? 'User') as String,
                        selectedPrice: selectedPrice,
                        selectedValidityDays: selectedValidityDays,
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Send Gift ($diamondPrice 💎)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _giftItemToUserDoc(Map<String, dynamic> item, String receiverId, String receiverName, {int? selectedPrice, int? selectedValidityDays}) async {
    try {
      final itemId = item['id'] as String;
      final itemName = item['name'] as String;
      final diamondPrice = (item['diamondPrice'] as num?)?.toInt() ?? 0;
      final cost = selectedPrice ?? diamondPrice;

      final currentBalance = widget.currentUser.diamonds;
      if (currentBalance < cost) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient diamonds. You need $cost diamonds to gift this item.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Gift'),
          content: Text('Are you sure you want to spend $cost diamonds to send "$itemName" to $receiverName?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
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
          description: 'Gifted $itemName to $receiverName (${selectedValidityDays ?? item['expirationDuration'] ?? 0} days)',
          validityDays: selectedValidityDays,
        );

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

    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    return GridView.builder(
      padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildStoreItemCard(item);
      },
    );
  }

  Widget _buildStoreItemCard(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final int price = (item['diamondPrice'] as num?)?.toInt() ?? 0;

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
        case 'shortProfileTheme':
          currentEquippedId = customization.selectedShortProfileThemeId;
          break;
        case 'roomEntry':
          currentEquippedId = customization.selectedRoomEntryId;
          break;
      }
    }

    final bool isEquipped = currentEquippedId == itemId;

    // Check multiple possible keys for the image
    String? imageUrl = (item['thumbnailUrl'] ??
            item['fileUrl'] ??
            item['animationUrl'] ??
            item['frameUrl'] ??
            item['frameMediaUrl'] ??
            item['svgaUrl'] ??
            item['assetUrl'] ??
            item['mediaUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            item['icon'])
        ?.toString();

    // Validate URL
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = null;
    }

    final durationText = item['expirationDuration'] != null
        ? '${item['expirationDuration']} Days'
        : '15 Days';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        children: [
          // Top Row: Validity & Test Wear
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Clock icon + Validity text
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      size: 11,
                      color: Color(0xFFFF4D6D),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    durationText,
                    style: const TextStyle(
                      color: Color(0xFFFF4D6D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Right: Test wear button (Opens preview)
              GestureDetector(
                onTap: () {
                  _showLivePreview(context, item, widget.type);
                },
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9C27B0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Test wear',
                      style: TextStyle(
                        color: Color(0xFF9C27B0),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Center Area: Asset Preview Image
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showLivePreview(context, item, widget.type);
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? (imageUrl.toLowerCase().endsWith('.svg')
                          ? SvgPicture.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              placeholderBuilder: (context) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : (widget.type == 'micRefill'
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 65,
                                      height: 65,
                                      child: UniversalAssetWidget(
                                        url: imageUrl,
                                        fit: BoxFit.contain,
                                        isAlphaVideo: true,
                                      ),
                                    ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA42D).withValues(alpha: 0.85),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.mic, color: Colors.white, size: 20),
                                    ),
                                  ],
                                )
                              : UniversalAssetWidget(
                                  url: imageUrl,
                                  fit: BoxFit.contain,
                                  isAlphaVideo: true,
                                )))
                      : const Icon(Icons.image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),

          // Price Row: Diamond Icon + Price
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DynamicDiamondIcon(width: 18, height: 18),
                const SizedBox(width: 4),
                Text(
                  '$price',
                  style: const TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Row: Dual Gradient Action Buttons (Buy & Send)
          Row(
            children: [
              // Left Pill Button: Buy / Equip / Unequip
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A6D), Color(0xFFFF5E8A)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        if (!isOwned) {
                          _purchaseItem(item);
                        } else if (isEquipped) {
                          _unequipItem(item);
                        } else {
                          _equipItem(item);
                        }
                      },
                      child: Center(
                        child: Text(
                          isOwned
                              ? (isEquipped ? 'Unequip' : 'Equip')
                              : 'Buy',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right Pill Button: Send (Gifting)
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E44AD), Color(0xFFA569BD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => _showGiftDialog(item),
                      child: const Center(
                        child: Text(
                          'Send',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
