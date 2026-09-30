import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import '../../../services/store_service.dart';
import '../../../services/wallet_service.dart';
import 'dart:async';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/golden_seat_widget.dart';


class RoomDecorSheet extends StatefulWidget {
  final String userId;
  final AudioRoomV2 currentRoom;
  final AudioRoomsBloc audioRoomsBloc;

  const RoomDecorSheet({
    super.key,
    required this.userId,
    required this.currentRoom,
    required this.audioRoomsBloc,
  });

  @override
  State<RoomDecorSheet> createState() => _RoomDecorSheetState();
}

class _RoomDecorSheetState extends State<RoomDecorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StoreService _storeService = StoreService();
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _backgroundItems = [];
  List<Map<String, dynamic>> _seatDecorItems = [];
  List<Map<String, dynamic>> _userItems = [];
  int _userDiamonds = 0;

  StreamSubscription? _backgroundSub;
  StreamSubscription? _seatDecorSub;
  StreamSubscription? _userItemsSub;
  StreamSubscription? _userDocSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToData();
  }

  @override
  void dispose() {
    _backgroundSub?.cancel();
    _seatDecorSub?.cancel();
    _userItemsSub?.cancel();
    _userDocSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenToData() {
    setState(() => _isLoading = true);

    int loadedCount = 0;
    void checkLoading() {
      loadedCount++;
      if (loadedCount >= 3 && mounted) {
        setState(() => _isLoading = false);
      }
    }

    _backgroundSub = _storeService
        .getStoreItemsByTypeStream('backgroundTheme')
        .listen((items) {
      if (mounted) {
        setState(() => _backgroundItems = items);
        if (_isLoading) checkLoading();
      }
    }, onError: (e) {
      debugPrint('Error loading background items: $e');
      if (mounted && _isLoading) checkLoading();
    });

    _seatDecorSub =
        _storeService.getStoreItemsByTypeStream('seatDecor').listen((items) {
      if (mounted) {
        final defaultFreeModes = [
          {
            'id': 'free_mode_original',
            'name': 'Classic Mic & Owner (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.original,
          },
          {
            'id': 'free_mode_golden',
            'name': 'Golden Sofa & Host (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.golden,
          },
          {
            'id': 'free_mode_cyberEmerald',
            'name': 'Cyber Emerald Neon (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.cyberEmerald,
          },
          {
            'id': 'free_mode_purple',
            'name': 'Neon Purple & Gold (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.purple,
          },
          {
            'id': 'free_mode_dashedPink',
            'name': 'Dashed Pink (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.dashedPink,
          },
          {
            'id': 'free_mode_dashedOrange',
            'name': 'Dashed Orange (Free)',
            'type': 'seatDecor',
            'isFreeMode': true,
            'diamondPrice': 0,
            'seatColorMode': SeatColorMode.dashedOrange,
          }
        ];

        final List<Map<String, dynamic>> resolvedItems = [];
        final Set<String> seenIds = {};

        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw);
          final id = item['id']?.toString() ?? '';
          seenIds.add(id);

          SeatColorMode? mode;
          final scm = item['seatColorMode']?.toString().toLowerCase();
          final nameLower = (item['name'] ?? '').toString().toLowerCase();
          if (id == 'free_mode_golden' || (scm != null && (scm.contains('golden') || scm.contains('sofa'))) || (nameLower.contains('golden sofa') && (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty))) {
            mode = SeatColorMode.golden;
          } else if (id == 'free_mode_cyberEmerald' || (scm != null && (scm.contains('cyber') || scm.contains('emerald'))) || (nameLower.contains('cyber emerald') && (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty))) {
            mode = SeatColorMode.cyberEmerald;
          } else if (id == 'free_mode_purple' || (scm != null && scm.contains('purple')) || (nameLower.contains('neon purple') && (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty))) {
            mode = SeatColorMode.purple;
          } else if (id == 'free_mode_dashedpink' || id == 'free_mode_dashedPink' || (scm != null && scm.contains('dashedpink'))) {
            mode = SeatColorMode.dashedPink;
          } else if (id == 'free_mode_dashedorange' || id == 'free_mode_dashedOrange' || (scm != null && scm.contains('dashedorange'))) {
            mode = SeatColorMode.dashedOrange;
          } else if (id == 'free_mode_original' || id == 'free_mode_classic_mic_owner' || (scm != null && scm.contains('original')) || (nameLower.contains('classic mic') && (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty))) {
            mode = SeatColorMode.original;
          }

          if (mode != null) {
            item['seatColorMode'] = mode;
            item['isFreeMode'] = (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty);
          }

          final price = (item['diamondPrice'] as num?)?.toInt() ?? 0;
          if (price <= 0) {
            item['isFree'] = true;
          }

          resolvedItems.add(item);
        }

        if (items.isEmpty) {
          resolvedItems.addAll(defaultFreeModes);
        }

        setState(() => _seatDecorItems = resolvedItems);
        if (_isLoading) checkLoading();
      }
    }, onError: (e) {
      debugPrint('Error loading seat decor items: $e');
      if (mounted && _isLoading) checkLoading();
    });

    _userItemsSub =
        _storeService.getUserStoreItemsStream(widget.userId).listen((items) {
      if (mounted) {
        setState(() => _userItems = items);
        if (_isLoading) checkLoading();
      }
    }, onError: (e) {
      debugPrint('Error loading user items: $e');
      if (mounted && _isLoading) checkLoading();
    });

    _userDocSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          _userDiamonds = (snapshot.data()?['diamonds'] as num?)?.toInt() ?? 0;
        });
      }
    }, onError: (e) {
      debugPrint('Error loading user document: $e');
    });
  }

  bool _isItemUnlocked(Map<String, dynamic> item) {
    if (item['isFreeMode'] == true || item['isFree'] == true) return true;
    final price = (item['diamondPrice'] as num?)?.toInt() ?? 0;
    if (price <= 0) return true;
    final id = item['id']?.toString() ?? '';
    if (id.startsWith('free_mode_')) return true;
    return _userItems.any((userItem) => userItem['storeItemId'] == id);
  }

  void _onItemTapped(Map<String, dynamic> item, String type) {
    if (!_isItemUnlocked(item)) {
      _showPurchaseDialog(item);
      return;
    }

    if (type == 'backgroundTheme') {
      widget.audioRoomsBloc.add(UpdateBackgroundImage(
        roomId: widget.currentRoom.id,
        userId: widget.userId,
        imageUrl: item['fileUrl'],
      ));
    } else if (type == 'seatDecor') {
      final bool isFreeItem = item['isFreeMode'] == true ||
          item['isFree'] == true ||
          (item['diamondPrice'] as num?)?.toInt() == 0 ||
          item['id'] == 'free_mode_classic_mic_owner' ||
          item['id'] == 'free_mode_golden' ||
          item['id'] == 'free_mode_purple' ||
          item['id'] == 'free_mode_original' ||
          (item['fileUrl'] == null || item['fileUrl'].toString().trim().isEmpty);

      if (isFreeItem) {
        SeatColorMode mode = SeatColorMode.original;
        final rawMode = item['seatColorMode'];
        if (rawMode is SeatColorMode) {
          mode = rawMode;
        } else if (rawMode is String) {
          final l = rawMode.toLowerCase();
          if (l.contains('golden') || l.contains('sofa')) {
            mode = SeatColorMode.golden;
          } else if (l.contains('dashedpink')) {
            mode = SeatColorMode.dashedPink;
          } else if (l.contains('dashedorange')) {
            mode = SeatColorMode.dashedOrange;
          } else if (l.contains('cyber') || l.contains('emerald')) {
            mode = SeatColorMode.cyberEmerald;
          } else if (l.contains('purple')) {
            mode = SeatColorMode.purple;
          } else {
            mode = SeatColorMode.original;
          }
        }
        final updatedSettings = widget.currentRoom.settings.copyWith(
          seatColorMode: mode,
          isSeatAnimated: item['isAnimated'] == true || item['isAnimated'] == 'true',
          seatAnimationType: item['animationType']?.toString() ?? 'rotatingRing',
          seatAnimationColor: item['animationColor']?.toString() ?? '#00FFE0',
          seatAnimationSpeed: (item['animationSpeed'] as num?)?.toDouble() ?? 1.0,
          clearSeatDecor: true,
        );
        widget.audioRoomsBloc.add(UpdateRoomSettings(
          roomId: widget.currentRoom.id,
          userId: widget.userId,
          settings: updatedSettings,
        ));
      } else {
        final updatedSettings = widget.currentRoom.settings.copyWith(
          hostSeatDecorUrl: item['hostSeatDecorUrl'] ?? item['hostFileUrl'] ?? item['fileUrl'],
          seatDecorUrl: item['fileUrl'],
          lockedSeatDecorUrl: item['lockedFileUrl'] ?? item['lockedSeatDecorUrl'] ?? item['fileUrl'],
          seatColorMode: SeatColorMode.original,
          isSeatAnimated: item['isAnimated'] == true || item['isAnimated'] == 'true',
          seatAnimationType: item['animationType']?.toString() ?? 'rotatingRing',
          seatAnimationColor: item['animationColor']?.toString() ?? '#00FFE0',
          seatAnimationSpeed: (item['animationSpeed'] as num?)?.toDouble() ?? 1.0,
        );

        widget.audioRoomsBloc.add(UpdateRoomSettings(
          roomId: widget.currentRoom.id,
          userId: widget.userId,
          settings: updatedSettings,
        ));
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['name']} applied!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPurchaseDialog(Map<String, dynamic> item) {
    final int price = (item['diamondPrice'] as num?)?.toInt() ?? 0;
    final bool hasEnough = _userDiamonds >= price;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        bool isPurchasing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Purchase Item',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black26,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: AnimatedSeatDecorWidget(
                        isAnimated: item['isAnimated'] == true || item['isAnimated'] == 'true',
                        animationType: item['animationType']?.toString() ?? 'rotatingRing',
                        glowColor: (item['animationColor'] != null && item['animationColor'].toString().isNotEmpty)
                            ? (item['animationColor'].toString().startsWith('#')
                                ? Color(int.parse('0xFF' + item['animationColor'].toString().replaceAll('#', '')))
                                : const Color(0xFF00FFE0))
                            : const Color(0xFF00FFE0),
                        animationSpeed: (item['animationSpeed'] as num?)?.toDouble() ?? 1.0,
                        size: 46,
                        child: item['isFreeMode'] == true
                          ? Container(
                              color: Colors.black45,
                              child: Center(
                                child: (item['seatColorMode'] == SeatColorMode.cyberEmerald || item['seatColorMode'] == 'cyberEmerald')
                                  ? const CyberEmeraldDiamondOrbWidget(
                                      size: 46,
                                      child: GoldenSofaIcon(width: 24, height: 21, isNeonPurple: true),
                                    )
                                  : (item['seatColorMode'] == SeatColorMode.purple || item['seatColorMode'] == 'purple')
                                  ? const NeonPurpleGlassOrbWidget(
                                      size: 46,
                                      child: GoldenSofaIcon(width: 24, height: 21, isNeonPurple: true),
                                    )
                                  : (item['seatColorMode'] == SeatColorMode.golden || item['seatColorMode'] == 'golden')
                                      ? const GoldenGlassOrbWidget(
                                          size: 46,
                                          child: GoldenSofaIcon(width: 24, height: 21),
                                        )
                                  : (item['seatColorMode'] == SeatColorMode.original || item['seatColorMode'] == 'original')
                                      ? Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(alpha: 0.16),
                                            border: Border.all(color: Colors.white38, width: 1.5),
                                          ),
                                          child: const Icon(Icons.mic_rounded, color: Colors.white70, size: 24),
                                        )
                                      : item['seatColorMode'] ==
                                              SeatColorMode.dashedPink
                                          ? const Icon(Icons.music_note,
                                              color: Colors.pink, size: 40)
                                          : Image.asset(
                                              'assets/icons/sofa_ic.webp',
                                              height: 40,
                                              color: Colors.orange),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: item['thumbnailUrl'] ??
                                    item['fileUrl'] ??
                                    '',
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Price: ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        DynamicDiamondIcon(height: 16,
                          width: 16,),
                        const SizedBox(width: 4),
                        Text(
                          '$price',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Balance: ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        DynamicDiamondIcon(height: 16,
                          width: 16,),
                        const SizedBox(width: 4),
                        Text(
                          '$_userDiamonds',
                          style: TextStyle(
                            color: hasEnough ? Colors.green : Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isPurchasing)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !hasEnough
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        isPurchasing = true;
                                      });
                                      try {
                                        final success = await _walletService
                                            .purchaseStoreItem(
                                          userId: widget.userId,
                                          storeItemId: item['id'],
                                          cost: price,
                                          description:
                                              'Purchased ${item['name']}',
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(
                                              context); // Close purchase dialog

                                          if (success) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${item['name']} purchased successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Failed to purchase item.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white10,
                                disabledForegroundColor: Colors.white24,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Purchase'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onRemoveDecor(String type) {
    if (type == 'backgroundTheme') {
      widget.audioRoomsBloc.add(UpdateBackgroundImage(
        roomId: widget.currentRoom.id,
        userId: widget.userId,
        imageUrl: null,
      ));
    } else if (type == 'seatDecor') {
      final updatedSettings = widget.currentRoom.settings.copyWith(
        hostSeatDecorUrl: null,
        seatDecorUrl: null,
        lockedSeatDecorUrl: null,
        clearSeatDecor: true,
      );

      widget.audioRoomsBloc.add(UpdateRoomSettings(
        roomId: widget.currentRoom.id,
        userId: widget.userId,
        settings: updatedSettings,
      ));
    }
    Navigator.pop(context);
  }

  Widget _buildGrid(List<Map<String, dynamic>> items, String type) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (items.isEmpty) {
      return const Center(
        child:
            Text('No items available', style: TextStyle(color: Colors.white70)),
      );
    }

    String? currentUrl;
    if (type == 'backgroundTheme') {
      currentUrl = widget.currentRoom.settings.backgroundImageUrl;
    } else {
      currentUrl = widget.currentRoom.settings.seatDecorUrl;
    }

    return Column(
      children: [
        if (currentUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _onRemoveDecor(type),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('Remove Current Decor',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isUnlocked = _isItemUnlocked(item);
              final isSelected = item['isFreeMode'] == true
                  ? ((widget.currentRoom.settings.seatDecorUrl == null ||
                          widget.currentRoom.settings.seatDecorUrl!.trim().isEmpty) &&
                      widget.currentRoom.settings.seatColorMode ==
                          item['seatColorMode'])
                  : (item['fileUrl'] == currentUrl || (item['hostSeatDecorUrl'] != null && item['hostSeatDecorUrl'] == widget.currentRoom.settings.hostSeatDecorUrl));

              return GestureDetector(
                onTap: () => _onItemTapped(item, type),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                    color: Colors.black45,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item['isFreeMode'] == true)
                        Container(
                          color: Colors.black45,
                          child: Center(
                            child: (item['seatColorMode'] == SeatColorMode.purple || item['seatColorMode'] == 'purple')
                                ? const NeonPurpleGlassOrbWidget(
                                    size: 46,
                                    child: GoldenSofaIcon(width: 24, height: 21, isNeonPurple: true),
                                  )
                                : (item['seatColorMode'] == SeatColorMode.golden || item['seatColorMode'] == 'golden')
                                    ? const GoldenGlassOrbWidget(
                                        size: 46,
                                        child: GoldenSofaIcon(width: 24, height: 21),
                                      )
                                : (item['seatColorMode'] == SeatColorMode.original || item['seatColorMode'] == 'original')
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.16),
                                          border: Border.all(color: Colors.white38, width: 1.5),
                                        ),
                                        child: const Icon(Icons.mic_rounded, color: Colors.white70, size: 24),
                                      )
                                    : item['seatColorMode'] ==
                                            SeatColorMode.dashedPink
                                        ? const Icon(Icons.music_note,
                                            color: Colors.pink, size: 40)
                                        : Image.asset('assets/icons/sofa_ic.webp',
                                            height: 40, color: Colors.orange),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl:
                                item['thumbnailUrl'] ?? item['fileUrl'] ?? '',
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.white54),
                          ),
                        ),
                      if (isSelected)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        ),
                      if (!isUnlocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.lock,
                                  color: Colors.white70, size: 32),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isUnlocked)
                                Row(
                                  children: [
                                    DynamicDiamondIcon(height: 10,
                                      width: 10,),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item['diamondPrice'] ?? 0}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                            ],
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'Room Decor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DynamicDiamondIcon(height: 14,
                        width: 14,),
                      const SizedBox(width: 4),
                      Text(
                        '$_userDiamonds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Background'),
              Tab(text: 'Seat Decor'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(_backgroundItems, 'backgroundTheme'),
                _buildGrid(_seatDecorItems, 'seatDecor'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
