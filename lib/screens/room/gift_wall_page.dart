import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GiftWallPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userImage;
  final List<Map<String, dynamic>> gifts;

  const GiftWallPage({
    super.key,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.gifts,
  });

  @override
  State<GiftWallPage> createState() => _GiftWallPageState();
}

class _GiftWallPageState extends State<GiftWallPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _receivedDocs = {};
  final Map<String, Map<String, dynamic>> _activeDocs = {};

  late List<Map<String, dynamic>> _gifts;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _receivedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  String? _userAvatarUrl;
  String _sortMode = 'price'; // 'price' or 'quantity'
  final int _selectedTabIndex = 0; // 0 = Gift Display
  int _totalGiftQuantity = 0;
  int _totalGiftPoints = 0;

  @override
  void initState() {
    super.initState();
    _userAvatarUrl = widget.userImage;
    _gifts = List<Map<String, dynamic>>.from(widget.gifts);

    // Initial sum calculation from widget.gifts to avoid empty screen flash
    int initQty = 0;
    int initPoints = 0;
    for (final g in _gifts) {
      final count = g['count'] as int? ?? 1;
      final credits = g['credits'] as int? ?? 0;
      final totalVal = g['totalValue'] as int? ?? (credits * count);
      initQty += count;
      initPoints += totalVal;
    }
    _totalGiftQuantity = initQty;
    _totalGiftPoints = initPoints;

    _loadSortPreference();
    _listenToGiftWall();
    _listenToUserData();
  }

  Future<void> _loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('gift_sort_mode');
      if (savedMode != null && savedMode.isNotEmpty && mounted) {
        setState(() {
          _sortMode = savedMode;
          _sortGiftsList(_gifts);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading gift sort pref: $e');
    }
  }

  Future<void> _saveSortPreference(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gift_sort_mode', mode);
    } catch (e) {
      debugPrint('❌ Error saving gift sort pref: $e');
    }
  }

  @override
  void dispose() {
    _receivedSub?.cancel();
    _activeSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _listenToUserData() {
    _userSub = _firestore
        .collection('Users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final photoUrl =
            data['photoUrl'] as String? ?? data['userImage'] as String? ?? '';
        if (photoUrl.isNotEmpty && mounted) {
          setState(() {
            _userAvatarUrl = photoUrl;
          });
        }
      }
    }, onError: (e) {
      debugPrint('❌ Gift wall user profile listen error: $e');
    });
  }

  void _listenToGiftWall() {
    _receivedSub = _firestore
        .collection('user_received_gifts')
        .where('receiverId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      _replaceDocs(_receivedDocs, snapshot);
      _rebuildGifts();
    }, onError: (error) {
      debugPrint('❌ Gift wall received-gifts listen error: $error');
    });

    _activeSub = _firestore
        .collection('gift_transactions')
        .where('receiverId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      _replaceDocs(_activeDocs, snapshot);
      _rebuildGifts();
    }, onError: (error) {
      debugPrint('❌ Gift wall live transaction listen error: $error');
    });
  }

  void _replaceDocs(
    Map<String, Map<String, dynamic>> target,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    target
      ..clear()
      ..addEntries(snapshot.docs.map((doc) {
        return MapEntry(doc.id, {'id': doc.id, ...doc.data()});
      }));
  }

  String _cleanGiftName(String name) {
    var cleaned = name.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+x\s*\d+$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+\s*x$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*\(\s*x?\s*\d+\s*x?\s*\)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*\(\s*combo\s*\)$', caseSensitive: false), '');
    return cleaned.trim();
  }

  String _getGiftGroupKey(Map<String, dynamic> data) {
    final rawName = _stringValue(data, ['giftName', 'name'], 'Gift');
    final cleanName = _cleanGiftName(rawName).toLowerCase();
    final rawImageUrl = _stringValue(
      data,
      ['giftPngUrl', 'giftImageUrl', 'pngUrl', 'imageUrl'],
      '',
    );
    final cleanImageUrl = rawImageUrl.split('?').first.trim().toLowerCase();

    if (cleanImageUrl.isNotEmpty) {
      return '$cleanName|$cleanImageUrl';
    }

    final explicitGiftId = data['giftId']?.toString().trim() ?? '';
    if (explicitGiftId.isNotEmpty) {
      return '$cleanName|$explicitGiftId';
    }

    return cleanName;
  }

  void _rebuildGifts() {
    if (_activeDocs.isEmpty && _receivedDocs.isEmpty) {
      if (_gifts.isNotEmpty) {
        _sortGiftsList(_gifts);
      }
      return;
    }

    final mergedDocs = <String, Map<String, dynamic>>{
      ..._activeDocs,
      ..._receivedDocs,
    };

    final giftMap = <String, Map<String, dynamic>>{};
    int quantitySum = 0;
    int pointsSum = 0;

    for (final data in mergedDocs.values) {
      final rawGiftName = _stringValue(data, ['giftName', 'name'], 'Gift');
      final cleanName = _cleanGiftName(rawGiftName);
      final imageUrl = _stringValue(
        data,
        ['giftPngUrl', 'giftImageUrl', 'pngUrl', 'imageUrl'],
        '',
      );
      final credits = _intValue(data['credits'] ?? data['diamondAmount']);
      final quantity =
          _intValue(data['quantity'] ?? data['count'], fallback: 1);
      final timestamp = _dateValue(data['timestamp']);
      final key = _getGiftGroupKey(data);

      final totalItemVal = credits * quantity;
      quantitySum += quantity;
      pointsSum += totalItemVal;

      // Group Gift items
      final item = giftMap.putIfAbsent(key, () {
        return {
          'giftName': cleanName,
          'giftImageUrl': imageUrl,
          'credits': credits,
          'count': 0,
          'totalValue': 0,
          'lastTimestamp': timestamp,
        };
      });

      item['count'] = (item['count'] as int) + quantity;
      item['totalValue'] = (item['totalValue'] as int) + totalItemVal;

      final previousTimestamp = item['lastTimestamp'] as DateTime;
      if (timestamp.isAfter(previousTimestamp)) {
        item['lastTimestamp'] = timestamp;
      }
    }

    final updatedGifts = giftMap.values.toList();
    _sortGiftsList(updatedGifts);

    if (mounted) {
      setState(() {
        _gifts = updatedGifts;
        _totalGiftQuantity = quantitySum;
        _totalGiftPoints = pointsSum;
      });
    } else {
      _gifts = updatedGifts;
      _totalGiftQuantity = quantitySum;
      _totalGiftPoints = pointsSum;
    }
  }

  void _sortGiftsList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      if (_sortMode == 'quantity') {
        final countCompare =
            (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0);
        if (countCompare != 0) return countCompare;
        final unitCompare =
            (b['credits'] as int? ?? 0).compareTo(a['credits'] as int? ?? 0);
        if (unitCompare != 0) return unitCompare;
        final valueCompare =
            (b['totalValue'] as int? ?? 0).compareTo(a['totalValue'] as int? ?? 0);
        if (valueCompare != 0) return valueCompare;
      } else {
        // 'price' mode: Sort by diamond price (credits) descending
        final unitCompare =
            (b['credits'] as int? ?? 0).compareTo(a['credits'] as int? ?? 0);
        if (unitCompare != 0) return unitCompare;
        final valueCompare =
            (b['totalValue'] as int? ?? 0).compareTo(a['totalValue'] as int? ?? 0);
        if (valueCompare != 0) return valueCompare;
        final countCompare =
            (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0);
        if (countCompare != 0) return countCompare;
      }
      return (b['lastTimestamp'] as DateTime? ?? DateTime.now())
          .compareTo(a['lastTimestamp'] as DateTime? ?? DateTime.now());
    });
  }

  String _stringValue(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D36),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF263963)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sort_gifts_by'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSortOptionItem(
                    title: 'quantity'.tr,
                    isSelected: _sortMode == 'quantity',
                    onTap: () {
                      setState(() {
                        _sortMode = 'quantity';
                        _sortGiftsList(_gifts);
                      });
                      _saveSortPreference('quantity');
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildSortOptionItem(
                    title: 'value'.tr,
                    isSelected: _sortMode == 'price',
                    onTap: () {
                      setState(() {
                        _sortMode = 'price';
                        _sortGiftsList(_gifts);
                      });
                      _saveSortPreference('price');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOptionItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2E52) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showGiftPointsInfoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1B38), Color(0xFF0A1227)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF2C4376), width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'gift_wall'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'gift_wall_info_subtitle'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              // Gift Points Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⭐ ', style: TextStyle(fontSize: 16)),
                  Text(
                    'gift_points'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' ⭐', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              // Rules Card Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF122044).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF283E6C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RuleBulletPoint(text: 'gift_wall_rule_1'.tr),
                    const SizedBox(height: 12),
                    _RuleBulletPoint(text: 'gift_wall_rule_2'.tr),
                    const SizedBox(height: 12),
                    _RuleBulletPoint(text: 'gift_wall_rule_3'.tr),
                    const SizedBox(height: 12),
                    _RuleBulletPoint(text: 'gift_wall_rule_4'.tr),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0075FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'got_it'.tr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF070E22),
              Color(0xFF0C1B3E),
              Color(0xFF060B1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1.5),
                        ),
                        child: const Icon(Icons.question_mark_rounded,
                            color: Colors.white, size: 14),
                      ),
                      onPressed: _showGiftPointsInfoDialog,
                    ),
                  ],
                ),
              ),

              // Profile & Gift Points Header Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Avatar with glowing ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0072FF).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF101B35),
                        backgroundImage: (_userAvatarUrl != null &&
                                _userAvatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(_userAvatarUrl!)
                            : null,
                        child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 36)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Username
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Points & Status Box
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB703),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.black87,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatNumber(_totalGiftPoints),
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3563),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E4B88)),
                          ),
                          child: Text(
                            '$_totalGiftQuantity ${'Gift'.tr}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab Selector Header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1B2C52), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabButton(title: 'gift_display'.tr, index: 0),
                  ],
                ),
              ),

              // Tab Body Content
              Expanded(
                child: _buildGiftDisplayTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isSelected = _selectedTabIndex == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 3,
          width: isSelected ? 40 : 0,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0075FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildGiftDisplayTab() {
    return Column(
      children: [
        // Controls Row: "Other Gifts" & "By price / By quantity ∨"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'other_gifts'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: _showSortMenu,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _sortMode == 'quantity'
                            ? 'by_quantity'.tr
                            : 'by_price'.tr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid Content
        Expanded(
          child: _gifts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 64,
                        color: Color(0xFF263A63),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'no_gifts_received'.tr,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _gifts.length,
                  itemBuilder: (context, index) {
                    final gift = _gifts[index];
                    final imageUrl = gift['giftImageUrl'] as String? ?? '';
                    final count = gift['count'] as int? ?? 1;

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101B35).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E2F54)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF0075FF),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.card_giftcard_rounded,
                                        color: Colors.white38,
                                        size: 28,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Colors.white38,
                                      size: 28,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '×$count',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RuleBulletPoint extends StatelessWidget {
  final String text;
  const _RuleBulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            color: Color(0xFF00C6FF),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xDDFFFFFF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
