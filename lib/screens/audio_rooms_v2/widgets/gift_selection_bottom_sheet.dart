import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/controllers/gift_combo_controller.dart';
import 'package:chat_messenger/AdminPane/models/gift.dart';
import 'package:chat_messenger/AdminPane/services/gift_service.dart';
import 'package:chat_messenger/services/emoji_chat_service.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/room/wallet_screen.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

class GiftSelectionBottomSheet extends StatefulWidget {
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;
  final List<AudioRoomParticipant> participants;

  const GiftSelectionBottomSheet({
    super.key,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
    required this.participants,
  });

  @override
  State<GiftSelectionBottomSheet> createState() =>
      _GiftSelectionBottomSheetState();
}

class _GiftSelectionBottomSheetState extends State<GiftSelectionBottomSheet>
    with TickerProviderStateMixin {
  static List<Gift>? _staticCachedGifts;
  static List<String>? _staticCategories;

  final GiftService _giftService = GiftService();
  List<Gift> _allActiveGifts = [];
  List<Gift> _gifts = [];
  List<String> _categories = [];
  bool _isLoading = true;
  bool _isCategoriesLoading = true;
  String _selectedCategory = '';
  Gift? _selectedGift;
  TabController? _tabController;
  int _debugTotalDocs = 0;
  int _debugActiveGifts = 0;
  StreamSubscription<QuerySnapshot>? _giftsSubscription;

  // Track selected receivers (multiple)
  final Set<String> _selectedReceiverIds = {};
  // Map for quick lookup of participant data
  final Map<String, AudioRoomParticipant> _participantMap = {};
  // Seated participants for top list
  final List<AudioRoomParticipant> _seatedParticipants = [];
  // Quantity of gifts to send
  int _selectedQuantity = 1;
  // Guard against double taps / multiple pop calls
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Immediate 0ms initialization if static memory cache is present
    if (_staticCachedGifts != null && _staticCachedGifts!.isNotEmpty && _staticCategories != null) {
      _allActiveGifts = List.from(_staticCachedGifts!);
      _categories = List.from(_staticCategories!);
      _selectedCategory = _categories.first;
      _gifts = _allActiveGifts.where((g) => g.category == _selectedCategory).toList();
      _selectedGift = _gifts.isNotEmpty ? _gifts.first : null;
      _tabController = TabController(length: _categories.length, vsync: this);
      _isLoading = false;
      _isCategoriesLoading = false;
    }

    // Build participant map and seated list
    for (final p in widget.participants) {
      _participantMap[p.userId] = p;
      if (p.seatNumber != null || p.isHost) {
        _seatedParticipants.add(p);
      }
    }
    
    // Check if the explicitly passed receiver is in the room but NOT in the seated list
    if (widget.receiverId != widget.senderId) {
      AudioRoomParticipant? receiverPart = _participantMap[widget.receiverId];
      
      if (receiverPart != null) {
        if (!_seatedParticipants.any((p) => p.userId == widget.receiverId)) {
          // Add them to the selectable list so they show up in the UI
          _seatedParticipants.add(receiverPart);
        }
        
        // Pre-select the receiver
        if (_seatedParticipants.any((p) => p.userId == widget.receiverId)) {
          _selectedReceiverIds.add(widget.receiverId);
        }
      } else {
        // The receiver (e.g. Host) is not in the room. Do not add them.
        // Fall back to selecting the first available non-sender participant.
        for (final p in _seatedParticipants) {
          if (p.userId != widget.senderId) {
            _selectedReceiverIds.add(p.userId);
            break;
          }
        }
      }
    } else {
      // If sender was passed as receiver, select first non-sender participant
      for (final p in _seatedParticipants) {
        if (p.userId != widget.senderId) {
          _selectedReceiverIds.add(p.userId);
          break;
        }
      }
    }
    _listenToGifts();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _giftsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenToGifts() async {
    debugPrint('🎁 [GiftSelection] Setting up gifts listener...');
    
    // 1. Try local Firestore cache FIRST (0ms latency, works offline / low internet)
    try {
      final cacheSnapshot = await _giftService.firestore
          .collection('gift')
          .get(const GetOptions(source: Source.cache));
      if (mounted && cacheSnapshot.docs.isNotEmpty) {
        _processSnapshot(cacheSnapshot);
      }
    } catch (_) {}

    // 2. Attach real-time listener for future updates
    _giftsSubscription = _giftService.firestore
        .collection('gift')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _processSnapshot(snapshot);
    }, onError: (e) {
      debugPrint('❌ GiftSelectionBottomSheet: Error listening to gifts: $e');
      if (mounted && _gifts.isEmpty) {
        setState(() {
          _isCategoriesLoading = false;
          _isLoading = false;
        });
      }
    });
  }

  void _processSnapshot(QuerySnapshot snapshot) {
    debugPrint('🎁 [GiftSelection] Stream snapshot received: ${snapshot.docs.length} documents');
    
    try {
      final activeGifts = <Gift>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Check for legacy array-based documents (e.g. doc.id = 'Event', 'Hot')
          if (data.containsKey('gifts') && data['gifts'] is List) {
            final oldGiftsList = data['gifts'] as List;
            for (int i = 0; i < oldGiftsList.length; i++) {
              try {
                if (oldGiftsList[i] is! Map) continue;
                final oldGiftData = oldGiftsList[i] as Map<String, dynamic>;
                
                // Filter out deactivated gifts
                final bool giftIsActive = oldGiftData['isActive'] ?? true;
                if (!giftIsActive) continue;
                
                final oldName = oldGiftData['name'] ?? oldGiftData['giftName'] ?? '';
                if (oldName.toString().trim().isEmpty) continue;
                
                final oldCredits = oldGiftData['credits'] ?? oldGiftData['diamondAmount'] ?? oldGiftData['price'] ?? oldGiftData['coin'] ?? oldGiftData['coins'] ?? 0;
                final oldPngUrl = oldGiftData['pngUrl'] ?? oldGiftData['imageUrl'] ?? oldGiftData['giftImageUrl'] ?? oldGiftData['icon'];
                final oldSvgaUrl = oldGiftData['svgaUrl'] ?? oldGiftData['animationUrl'];
                
                activeGifts.add(Gift(
                  id: '${doc.id}_$i',
                  name: oldName.toString(),
                  category: oldGiftData['category'] ?? doc.id,
                  credits: (num.tryParse(oldCredits.toString()) ?? 0).toInt(),
                  pngUrl: oldPngUrl?.toString(),
                  svgaUrl: oldSvgaUrl?.toString(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isActive: true,
                ));
              } catch (e) {
                // Ignore individual malformed legacy gifts
              }
            }
          }
          // Check for new Admin Panel format (single document per gift)
          else if (data.containsKey('name') && data['name'] != null && data['name'].toString().trim().isNotEmpty) {
            final gift = Gift.fromJson({...data, 'id': doc.id});
            if (gift.isActive) {
              activeGifts.add(gift);
            }
          }
        } catch (e, st) {
          debugPrint('❌ [GiftSelection] Failed to parse doc ${doc.id}: $e\n$st');
        }
      }

      debugPrint('🎁 [GiftSelection] Parsed ${activeGifts.length} active gifts');

      // Check for category order from categories_config doc
      List<String> configuredOrder = [];
      for (final doc in snapshot.docs) {
        if (doc.id == 'categories_config') {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final rawOrder = data['categories'] ?? data['order'];
            if (rawOrder is List) {
              configuredOrder = rawOrder.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
            }
          }
          break;
        }
      }

      if (configuredOrder.isEmpty) {
        configuredOrder = ['Hot', 'Event', 'Lucky', 'Local', 'Privilege', 'Trick', 'Customized'];
      }

      final presentCategories = activeGifts.map((g) => g.category).toSet();
      final orderedCategories = <String>[];

      for (final cat in configuredOrder) {
        if (presentCategories.contains(cat) || snapshot.docs.any((d) => d.id == cat)) {
          orderedCategories.add(cat);
        }
      }

      for (final cat in presentCategories) {
        if (!orderedCategories.contains(cat)) {
          orderedCategories.add(cat);
        }
      }

      final categories = orderedCategories.isNotEmpty ? orderedCategories : configuredOrder;
    
      // Ultra-fast proactive background preloading for all active gifts (SVGA, MP4, PNG, WebP)
      final List<String> urlsToPreload = [];
      for (final g in activeGifts) {
        if (g.svgaUrl != null && g.svgaUrl!.trim().isNotEmpty) {
          urlsToPreload.add(g.svgaUrl!.trim());
        }
        if (g.pngUrl != null && g.pngUrl!.trim().isNotEmpty) {
          urlsToPreload.add(g.pngUrl!.trim());
        }
      }
      if (urlsToPreload.isNotEmpty) {
        FastAssetCache.preloadBatch(urlsToPreload);
      }

      _staticCachedGifts = activeGifts;
      _staticCategories = categories;

      setState(() {
        _debugTotalDocs = snapshot.docs.length;
        _debugActiveGifts = activeGifts.length;
        _categories = categories;
        _allActiveGifts = activeGifts;
        
        // If categories are empty, stop loading
        if (categories.isEmpty) {
          _gifts = [];
          _isCategoriesLoading = false;
          _isLoading = false;
          return;
        }

        // If selected category is no longer valid or empty, pick the first one
        if (!_categories.contains(_selectedCategory) || _selectedCategory.isEmpty) {
          _selectedCategory = _categories.first;
        }

        // Filter gifts for the selected category
        _gifts = _allActiveGifts.where((g) => g.category == _selectedCategory).toList();
        
        // Update selected gift if the previous one is no longer in this category
        if (_selectedGift == null || !_gifts.any((g) => g.id == _selectedGift!.id)) {
          _selectedGift = _gifts.isNotEmpty ? _gifts.first : null;
        }
        
        // Re-initialize tab controller if length changed
        if (_tabController?.length != categories.length) {
          _tabController?.dispose();
          _tabController = TabController(length: categories.length, vsync: this);
        }

        _isCategoriesLoading = false;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('❌ [GiftSelection] Critical error processing gifts: $e\n$st');
      if (mounted) {
        setState(() {
          _isCategoriesLoading = false;
          _isLoading = false;
        });
      }
    }
  }





  void _navigateToRecharge() {
    Get.back(); // close bottom sheet
    final user = AuthController.instance.currentUser;
    Get.to(() => DiamondRechargePage(
          diamondBalance: user.diamonds,
          walletService: WalletService(),
          userId: user.userId,
        ));
  }

  void _showErrorSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: action,
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    if (category.isEmpty) return category;
    return _capitalize(category);
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }


  /// Calculate total cost based on selected receivers
  int _getTotalCost() {
    if (_selectedGift == null) return 0;
    return _selectedGift!.credits * _selectedQuantity * _selectedReceiverIds.length;
  }

  void _sendGift() {
    if (_isSending) return;

    if (_selectedGift == null) {
      _showErrorSnackBar('Please select a gift to send');
      return;
    }

    if (_selectedReceiverIds.isEmpty) {
      _showErrorSnackBar('Please select at least one recipient');
      return;
    }

    final totalCost = _getTotalCost();
    final userBalance = AuthController.instance.currentUser.diamonds;
    if (userBalance < totalCost) {
      _showErrorSnackBar(
          'Insufficient diamonds. You need $totalCost diamonds but have $userBalance.',
          action: SnackBarAction(
            label: 'Recharge',
            textColor: Colors.white,
            onPressed: _navigateToRecharge,
          ),
      );
      return;
    }

    if (!AuthController.instance.deductDiamonds(totalCost)) {
      _showErrorSnackBar(
          'Insufficient diamonds. You need $totalCost diamonds but have $userBalance.',
          action: SnackBarAction(
            label: 'Recharge',
            textColor: Colors.white,
            onPressed: _navigateToRecharge,
          ),
      );
      return;
    }

    _isSending = true;

    // Capture all needed values BEFORE closing the sheet
    final gift = _selectedGift!;
    final quantity = _selectedQuantity;
    final roomId = widget.roomId;
    final senderId = widget.senderId;
    final senderName = widget.senderName;
    final senderImageUrl = widget.senderImageUrl;
    final displayName = quantity > 1 ? '${gift.name} x$quantity' : gift.name;
    final giftCredits = gift.credits * quantity;

    final List<Map<String, dynamic>> receiversList = [];
    for (final receiverId in _selectedReceiverIds) {
      final participant = _participantMap[receiverId];
      if (participant != null) {
        receiversList.add({
          'id': participant.userId,
          'name': participant.userName,
          'imageUrl': participant.userImageUrl,
          'seatNumber': participant.seatNumber,
        });
      }
    }

    debugPrint('🎁 [GiftSelection] Instant-sending gift: $displayName to ${receiversList.length} recipients');

    // Close the bottom sheet IMMEDIATELY
    Navigator.of(context).pop();

    // Defer combo timer & background tasks to post-frame callback so Navigator pop completes smoothly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GiftComboController.instance.startComboSession(
        gift: gift,
        receivers: receiversList,
        quantity: quantity,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        initialComboCount: 1,
      );

      _processGiftInBackground(
        gift: gift,
        displayName: displayName,
        giftCredits: giftCredits,
        quantity: quantity,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        receiversList: receiversList,
      );
    });
  }

  /// Runs all Firebase operations in the background without blocking the UI
  Future<void> _processGiftInBackground({
    required Gift gift,
    required String displayName,
    required int giftCredits,
    required int quantity,
    required String roomId,
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required List<Map<String, dynamic>> receiversList,
  }) async {
    final totalCredits = giftCredits * receiversList.length;
    try {
      // 1. Send gifts
      await _giftService.sendGifts(
        giftId: gift.id,
        giftName: gift.name,
        giftPngUrl: gift.pngUrl ?? '',
        giftSvgaUrl: gift.svgaUrl,
        giftCredits: gift.credits,
        quantity: quantity,
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        receivers: receiversList,
        roomId: roomId,
        sendChatMessage: false,
      );

      // 2. Send chat messages in parallel (don't wait for each one)
      for (final receiver in receiversList) {
        EmojiChatService.sendGiftMessage(
          roomId: roomId,
          userId: senderId,
          username: senderName,
          userAvatar: senderImageUrl,
          receiverName: receiver['name'],
          giftName: displayName,
          giftImageUrl: gift.pngUrl ?? '',
          giftCredits: giftCredits,
        ).catchError((e) {
          debugPrint('❌ [GiftSelection] Failed to send chat message: $e');
        });
      }

      // 3. Update PK Battle Score in background (read PK state if needed)
      _updatePkScoreInBackground(
        roomId: roomId,
        receiversList: receiversList,
        giftCredits: giftCredits,
      );

      debugPrint('✅ [GiftSelection] Background gift processing complete!');
    } catch (e) {
      debugPrint('❌ [GiftSelection] Background gift error: $e');
      AuthController.instance.refundDiamonds(totalCredits);
      Get.snackbar(
        'Gift Failed',
        'Could not complete the gift transaction: $e',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Update PK battle scores silently in the background
  Future<void> _updatePkScoreInBackground({
    required String roomId,
    required List<Map<String, dynamic>> receiversList,
    required int giftCredits,
  }) async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(roomId)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!roomDoc.exists) return;
      final roomData = roomDoc.data() as Map<String, dynamic>;
      if (roomData['pkBattleState'] == null) return;

      final pkState = PKBattleState.fromJson(roomData['pkBattleState']);
      if (!pkState.isActive) return;

      int leftScoreInc = 0;
      int rightScoreInc = 0;
      final teamSize = pkState.teamSize;
      final updates = <String, dynamic>{};

      for (final receiver in receiversList) {
        final seatNum = receiver['seatNumber'] as int?;
        final receiverId = receiver['id'] as String?;
        if (seatNum != null && receiverId != null) {
          if (seatNum >= 1 && seatNum <= teamSize) {
            leftScoreInc += giftCredits;
            updates['pkBattleState.individualScores.$receiverId'] = FieldValue.increment(giftCredits);
          } else if (seatNum > teamSize && seatNum <= teamSize * 2) {
            rightScoreInc += giftCredits;
            updates['pkBattleState.individualScores.$receiverId'] = FieldValue.increment(giftCredits);
          }
        }
      }

      if (updates.isNotEmpty || leftScoreInc > 0 || rightScoreInc > 0) {
        if (leftScoreInc > 0) updates['pkBattleState.leftTeamScore'] = FieldValue.increment(leftScoreInc);
        if (rightScoreInc > 0) updates['pkBattleState.rightTeamScore'] = FieldValue.increment(rightScoreInc);

        FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .doc(roomId)
            .update(updates)
            .catchError((e) {
          debugPrint('❌ [GiftSelection] Failed to update PK score: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ [GiftSelection] Failed to read/update PK state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const cyanColor = Color(0xFF18E7C7);
    const bgColor = Color(0xFF1E2322);

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.46, // Reduced from 0.5 to trim extra top space
          decoration: const BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12), // Reduced spacing since the container itself is smaller

              // Participants Row
              SizedBox(
                height: 50, // Reduced from 60 to match smaller items
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _seatedParticipants.length,
                        itemBuilder: (context, index) {
                          final participant = _seatedParticipants[index];
                          final isSelected =
                              _selectedReceiverIds.contains(participant.userId);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedReceiverIds.remove(participant.userId);
                                } else {
                                  _selectedReceiverIds.add(participant.userId);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    width: 40, // Reduced from 48
                                    height: 40, // Reduced from 48
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? cyanColor
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 18, // Reduced from 22
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: participant.userImageUrl != null
                                          ? NetworkImage(participant.userImageUrl!)
                                          : null,
                                      child: participant.userImageUrl == null
                                          ? const Icon(Icons.person, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  // Bottom badge
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      height: 20,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: cyanColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: bgColor, width: 2),
                                      ),
                                      child: participant.isHost
                                          ? const Icon(Icons.home,
                                              size: 10, color: Colors.white)
                                          : Text(
                                              '${participant.seatNumber ?? ""}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // "All" button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final allOtherIds = _seatedParticipants
                              .where((p) => p.userId != widget.senderId)
                              .map((p) => p.userId)
                              .toSet();
                          if (_selectedReceiverIds.length == allOtherIds.length) {
                            _selectedReceiverIds.clear();
                          } else {
                            _selectedReceiverIds
                              ..clear()
                              ..addAll(allOtherIds);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        width: 40, // Reduced from 48
                        height: 40, // Reduced from 48
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyanColor,
                        ),
                        child: const Center(
                          child: Text(
                            'All',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10, // Reduced from 12
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8), // Decreased from 16 to keep items closer to tabs

              // Category tabs
              if (_isCategoriesLoading)
                Container(
                  height: 35,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: cyanColor,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_categories.isNotEmpty && _tabController != null)
                Container(
                  height: 35,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: TabBar(
                    controller: _tabController!,
                    isScrollable: true,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    unselectedLabelColor: Colors.grey[400],
                    labelColor: Colors.white,
                    indicatorColor: cyanColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: _categories.map((category) {
                      return Tab(
                        text: _getCategoryDisplayName(category),
                      );
                    }).toList(),
                    onTap: (index) {
                      setState(() {
                        _selectedCategory = _categories[index];
                        // Filter locally since we already have all active gifts from the stream
                        _gifts = _allActiveGifts.where((g) => g.category == _selectedCategory).toList();
                        _selectedGift = _gifts.isNotEmpty ? _gifts.first : null;
                      });
                    },
                  ),
                ),

              const SizedBox(height: 8),

              // Gifts grid
              Expanded(
                child: _isCategoriesLoading || _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: cyanColor,
                          strokeWidth: 2,
                        ),
                      )
                    : _categories.isEmpty || _gifts.isEmpty
                        ? Center(
                            child: Text(
                              'No gifts found\nTotal Docs: $_debugTotalDocs | Active: $_debugActiveGifts',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _gifts.length,
                            itemBuilder: (context, index) {
                              final gift = _gifts[index];
                              final isSelected = _selectedGift?.id == gift.id;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedGift = gift;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? cyanColor
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SelectedGiftPulse(
                                            isSelected: isSelected,
                                            child: UniversalAssetWidget(
                                              url: gift.pngUrl,
                                              width: 55,
                                              height: 55,
                                              fit: BoxFit.contain,
                                              placeholder: const Icon(
                                                Icons.card_giftcard,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            gift.name,
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 10,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const DynamicDiamondIcon(
                                                width: 10,
                                                height: 10,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${gift.credits}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (gift.svgaUrl != null &&
                                          gift.svgaUrl!.isNotEmpty)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: cyanColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome,
                                              color: Colors.white,
                                              size: 8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Bottom Action Bar
              SafeArea(
                bottom: true,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: Colors.transparent,
                child: Row(
                  children: [
                    // Balance display
                    const DynamicDiamondIcon(
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 6),
                    Obx(() => Text(
                      '${AuthController.instance.currentUser.diamonds}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _navigateToRecharge,
                      child: const Text(
                        'Recharge>',
                        style: TextStyle(
                          color: cyanColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Send Button Combo
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        border: Border.all(color: cyanColor, width: 1.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quantity Selector
                          PopupMenuButton<int>(
                            initialValue: _selectedQuantity,
                            color: const Color(0xFF2A2A2A),
                            onSelected: (int value) {
                              setState(() {
                                _selectedQuantity = value;
                              });
                            },
                            offset: const Offset(0, -200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                              const PopupMenuItem<int>(
                                value: 999,
                                child: Text('999', style: TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem<int>(
                                value: 99,
                                child: Text('99', style: TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem<int>(
                                value: 9,
                                child: Text('9', style: TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem<int>(
                                value: 1,
                                child: Text('1', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Text(
                                    '$_selectedQuantity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_up,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Send Button
                          GestureDetector(
                            onTap: _selectedGift == null
                                ? null
                                : _sendGift,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: cyanColor,
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(16)),
                              ),
                              child: const Text(
                                  'Send',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A helper widget to animate scaling (zoom in/out heartbeat effect) when a gift is selected.
class SelectedGiftPulse extends StatefulWidget {
  final Widget child;
  final bool isSelected;

  const SelectedGiftPulse({
    super.key,
    required this.child,
    required this.isSelected,
  });

  @override
  State<SelectedGiftPulse> createState() => _SelectedGiftPulseState();
}

class _SelectedGiftPulseState extends State<SelectedGiftPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SelectedGiftPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isSelected ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

