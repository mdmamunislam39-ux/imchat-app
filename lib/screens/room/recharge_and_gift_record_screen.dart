import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum GiftRecordType { send, received }

class RechargeAndGiftRecordScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex; // 0 for Recharge, 1 for Gift Record

  const RechargeAndGiftRecordScreen({
    super.key,
    required this.userId,
    this.initialTabIndex = 1,
  });

  @override
  State<RechargeAndGiftRecordScreen> createState() =>
      _RechargeAndGiftRecordScreenState();
}

class _RechargeAndGiftRecordScreenState
    extends State<RechargeAndGiftRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GiftRecordType _selectedGiftType = GiftRecordType.received;
  String _giftFilter = 'All'; // 'All', 'This Month', 'Last Month'
  String _rechargeFilter = 'All'; // 'All', 'Approved', 'Pending'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('MMM dd HH:mm:ss').format(dt);
  }

  String _formatMonthYear(DateTime dt) {
    return DateFormat('MMM, yyyy').format(dt);
  }

  DateTime _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }

  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  num _parseNum(dynamic value, [num fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0091EA),
          indicatorWeight: 3.5,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.black,
          unselectedLabelColor: const Color(0xFF9E9E9E),
          labelStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Recharge'),
            Tab(text: 'Gift Record'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRechargeHistoryTab(),
          _buildGiftRecordTab(),
        ],
      ),
    );
  }

  // ==========================================
  // GIFT RECORD TAB (Send & Received)
  // ==========================================
  Widget _buildGiftRecordTab() {
    return Column(
      children: [
        // Sub-Tabs: Send / Received pill switcher
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedGiftType != GiftRecordType.send) {
                      setState(() => _selectedGiftType = GiftRecordType.send);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedGiftType == GiftRecordType.send
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selectedGiftType == GiftRecordType.send
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Send',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _selectedGiftType == GiftRecordType.send
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _selectedGiftType == GiftRecordType.send
                            ? Colors.black
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedGiftType != GiftRecordType.received) {
                      setState(
                        () => _selectedGiftType = GiftRecordType.received,
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedGiftType == GiftRecordType.received
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selectedGiftType == GiftRecordType.received
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Received',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _selectedGiftType == GiftRecordType.received
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _selectedGiftType == GiftRecordType.received
                            ? Colors.black
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stream of gifts based on Send or Received
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_received_gifts')
                .where(
                  _selectedGiftType == GiftRecordType.received
                      ? 'receiverId'
                      : 'senderId',
                  isEqualTo: widget.userId,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading gifts: ${snapshot.error}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              final now = DateTime.now();
              final docs = snapshot.data?.docs ?? [];

              // Map documents to clean Map items
              List<Map<String, dynamic>> items = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dt = _parseTimestamp(data['timestamp']);
                final int credits = _parseInt(data['credits']);
                final int qty = _parseInt(data['quantity'] ?? data['count'], 1);
                final int fallbackTotal = credits * (qty > 0 ? qty : 1);
                final int totalCredits = _parseInt(data['totalCredits'], fallbackTotal);

                return {
                  'id': doc.id,
                  'giftName': data['giftName'] ?? 'Gift',
                  'giftPngUrl': data['giftPngUrl'] ?? '',
                  'senderName': data['senderName'] ?? 'User',
                  'senderImageUrl': data['senderImageUrl'] ?? '',
                  'receiverName': data['receiverName'] ?? 'User',
                  'receiverImageUrl': data['receiverImageUrl'] ?? '',
                  'credits': credits,
                  'quantity': qty > 0 ? qty : 1,
                  'totalDiamonds': totalCredits,
                  'timestamp': dt,
                };
              }).toList();

              // Sort descending by timestamp
              items.sort(
                (a, b) => (b['timestamp'] as DateTime).compareTo(
                  a['timestamp'] as DateTime,
                ),
              );

              // Calculate Today and This Month stats
              int todayDiamonds = 0;
              int thisMonthDiamonds = 0;

              for (final item in items) {
                final dt = item['timestamp'] as DateTime;
                final dias = item['totalDiamonds'] as int;

                if (dt.year == now.year &&
                    dt.month == now.month &&
                    dt.day == now.day) {
                  todayDiamonds += dias;
                }
                if (dt.year == now.year && dt.month == now.month) {
                  thisMonthDiamonds += dias;
                }
              }

              // Filter if applied
              if (_giftFilter == 'This Month') {
                items = items.where((item) {
                  final dt = item['timestamp'] as DateTime;
                  return dt.year == now.year && dt.month == now.month;
                }).toList();
              } else if (_giftFilter == 'Last Month') {
                final lastMonthDate = DateTime(now.year, now.month - 1, 1);
                items = items.where((item) {
                  final dt = item['timestamp'] as DateTime;
                  return dt.year == lastMonthDate.year &&
                      dt.month == lastMonthDate.month;
                }).toList();
              }

              // Group items by month
              final Map<String, List<Map<String, dynamic>>> grouped = {};
              final Map<String, int> monthTotals = {};

              for (final item in items) {
                final dt = item['timestamp'] as DateTime;
                final monthKey = _formatMonthYear(dt);
                grouped.putIfAbsent(monthKey, () => []).add(item);
                monthTotals[monthKey] =
                    (monthTotals[monthKey] ?? 0) + (item['totalDiamonds'] as int);
              }

              return Column(
                children: [
                  // Stats Summary Card: Today | This Month
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Today Column
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Today',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.help_outline,
                                    size: 13,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const DynamicDiamondIcon(
                                    width: 15,
                                    height: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    todayDiamonds.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Vertical Divider
                        Container(
                          height: 32,
                          width: 1,
                          color: Colors.grey[200],
                        ),

                        // This Month Column
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'This Month',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const DynamicDiamondIcon(
                                    width: 15,
                                    height: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    thisMonthDiamonds.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
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

                  // Detail & Filter Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detail',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                        PopupMenuButton<String>(
                          initialValue: _giftFilter,
                          onSelected: (val) {
                            setState(() => _giftFilter = val);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _giftFilter,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF616161),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: Color(0xFF616161),
                              ),
                            ],
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'All',
                              child: Text('All'),
                            ),
                            const PopupMenuItem(
                              value: 'This Month',
                              child: Text('This Month'),
                            ),
                            const PopupMenuItem(
                              value: 'Last Month',
                              child: Text('Last Month'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // List of records
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  size: 54,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedGiftType == GiftRecordType.received
                                      ? 'No received gift records found'
                                      : 'No sent gift records found',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: grouped.keys.length,
                            itemBuilder: (context, groupIndex) {
                              final monthKey =
                                  grouped.keys.elementAt(groupIndex);
                              final monthItems = grouped[monthKey] ?? [];
                              final monthTotal = monthTotals[monthKey] ?? 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Month Header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          monthKey,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const DynamicDiamondIcon(
                                              width: 12,
                                              height: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              monthTotal.toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Month Items in White Card
                                  Container(
                                    color: Colors.white,
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: monthItems.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        indent: 72,
                                        color: Colors.grey[100],
                                      ),
                                      itemBuilder: (context, index) {
                                        final item = monthItems[index];
                                        return _buildGiftItemRow(item);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGiftItemRow(Map<String, dynamic> item) {
    final isReceived = _selectedGiftType == GiftRecordType.received;
    final partnerName = isReceived ? item['senderName'] : item['receiverName'];
    final partnerImage =
        isReceived ? item['senderImageUrl'] : item['receiverImageUrl'];
    final giftName = item['giftName'];
    final quantity = item['quantity'];
    final diamonds = item['totalDiamonds'];
    final dt = item['timestamp'] as DateTime;
    final giftPng = item['giftPngUrl'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Gift Image
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: giftPng.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: giftPng,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFFD81B60),
                      size: 26,
                    ),
                  )
                : const Icon(
                    Icons.card_giftcard,
                    color: Color(0xFFD81B60),
                    size: 26,
                  ),
          ),
          const SizedBox(width: 12),

          // Gift details: NamexCount, partner avatar & name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${giftName}x$quantity',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2128),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CachedCircleAvatar(
                      imageUrl: partnerImage,
                      radius: 8.5,
                      showFrame: false,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        partnerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Diamond count & Timestamp
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DynamicDiamondIcon(width: 13, height: 13),
                  const SizedBox(width: 4),
                  Text(
                    diamonds.toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2128),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(dt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RECHARGE HISTORY TAB
  // ==========================================
  Widget _buildRechargeHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rechargeOrders')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, orderSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('seller_transactions')
              .where('userId', isEqualTo: widget.userId)
              .snapshots(),
          builder: (context, sellerSnap) {
            if (orderSnap.connectionState == ConnectionState.waiting &&
                sellerSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final orderDocs = orderSnap.data?.docs ?? [];
            final sellerDocs = sellerSnap.data?.docs ?? [];

            List<Map<String, dynamic>> recharges = [];

            // 1. Process Online Recharge Orders
            for (final doc in orderDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final dt = _parseTimestamp(data['createdAt']);
              final num amount = _parseNum(data['amount']);
              final int diamondAmount = _parseInt(data['diamondAmount']);
              final int bonusDiamonds = _parseInt(data['bonusDiamonds']);
              final String status =
                  (data['status'] ?? 'pending').toString().toLowerCase();

              recharges.add({
                'id': doc.id,
                'amount': amount,
                'diamondAmount': diamondAmount,
                'bonusDiamonds': bonusDiamonds,
                'totalDiamonds': diamondAmount + bonusDiamonds,
                'paymentMethod': data['paymentMethod'] ?? 'Online',
                'trxId':
                    (data['transactionId'] ?? data['trxId'] ?? '').toString(),
                'status': status,
                'isSeller': false,
                'description': '',
                'timestamp': dt,
              });
            }

            // 2. Process Diamond Seller Recharges
            for (final doc in sellerDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final dt = _parseTimestamp(data['createdAt']);
              final int diamondAmount = _parseInt(data['amount']);
              final String desc = (data['description'] ?? '').toString();

              recharges.add({
                'id': doc.id,
                'amount': 0,
                'diamondAmount': diamondAmount,
                'bonusDiamonds': 0,
                'totalDiamonds': diamondAmount,
                'paymentMethod': 'Diamond Seller',
                'trxId': doc.id.length > 8
                    ? doc.id.substring(0, 8).toUpperCase()
                    : doc.id.toUpperCase(),
                'status': 'approved',
                'isSeller': true,
                'description': desc.isNotEmpty
                    ? desc
                    : 'Recharge from Authorized Seller',
                'timestamp': dt,
              });
            }

            // Sort descending by timestamp
            recharges.sort(
              (a, b) => (b['timestamp'] as DateTime).compareTo(
                a['timestamp'] as DateTime,
              ),
            );

            // Calculate Today & This Month recharge totals
            int todayRechargeDiamonds = 0;
            int thisMonthRechargeDiamonds = 0;

            for (final item in recharges) {
              final dt = item['timestamp'] as DateTime;
              final dias = item['totalDiamonds'] as int;
              final status = item['status'] as String;

              // Count approved or pending recharges
              if (status != 'rejected') {
                if (dt.year == now.year &&
                    dt.month == now.month &&
                    dt.day == now.day) {
                  todayRechargeDiamonds += dias;
                }
                if (dt.year == now.year && dt.month == now.month) {
                  thisMonthRechargeDiamonds += dias;
                }
              }
            }

            // Apply filter if any
            if (_rechargeFilter == 'Approved') {
              recharges =
                  recharges.where((r) => r['status'] == 'approved').toList();
            } else if (_rechargeFilter == 'Pending') {
              recharges =
                  recharges.where((r) => r['status'] == 'pending').toList();
            }

            // Group by month
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            final Map<String, int> monthTotals = {};

            for (final item in recharges) {
              final dt = item['timestamp'] as DateTime;
              final monthKey = _formatMonthYear(dt);
              grouped.putIfAbsent(monthKey, () => []).add(item);
              monthTotals[monthKey] =
                  (monthTotals[monthKey] ?? 0) + (item['totalDiamonds'] as int);
            }

            return Column(
              children: [
                // Stats summary card
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Today',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.help_outline,
                                  size: 13,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const DynamicDiamondIcon(
                                  width: 15,
                                  height: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  todayRechargeDiamonds.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: Colors.grey[200],
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'This Month',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const DynamicDiamondIcon(
                                  width: 15,
                                  height: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  thisMonthRechargeDiamonds.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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

                // Filter bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detail',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      PopupMenuButton<String>(
                        initialValue: _rechargeFilter,
                        onSelected: (val) {
                          setState(() => _rechargeFilter = val);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _rechargeFilter,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF616161),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Color(0xFF616161),
                            ),
                          ],
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'All',
                            child: Text('All'),
                          ),
                          const PopupMenuItem(
                            value: 'Approved',
                            child: Text('Approved'),
                          ),
                          const PopupMenuItem(
                            value: 'Pending',
                            child: Text('Pending'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Recharge items
                Expanded(
                  child: recharges.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 54,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No recharge records found',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: grouped.keys.length,
                          itemBuilder: (context, groupIndex) {
                            final monthKey = grouped.keys.elementAt(groupIndex);
                            final monthItems = grouped[monthKey] ?? [];
                            final monthTotal = monthTotals[monthKey] ?? 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        monthKey,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const DynamicDiamondIcon(
                                            width: 12,
                                            height: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            monthTotal.toString(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  color: Colors.white,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: monthItems.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      indent: 72,
                                      color: Colors.grey[100],
                                    ),
                                    itemBuilder: (context, index) {
                                      final item = monthItems[index];
                                      return _buildRechargeItemRow(item);
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRechargeItemRow(Map<String, dynamic> item) {
    final int diamonds = item['totalDiamonds'];
    final num amount = item['amount'];
    final String paymentMethod = item['paymentMethod'];
    final String trxId = item['trxId'];
    final String status = item['status'];
    final DateTime dt = item['timestamp'];
    final bool isSeller = item['isSeller'] == true;

    Color statusColor;
    Color statusBg;
    String statusText;

    if (status == 'approved') {
      statusColor = const Color(0xFF2E7D32);
      statusBg = const Color(0xFFE8F5E9);
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFC62828);
      statusBg = const Color(0xFFFFEBEE);
      statusText = 'Rejected';
    } else {
      statusColor = const Color(0xFFF57F17);
      statusBg = const Color(0xFFFFF8E1);
      statusText = 'Pending';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSeller
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isSeller
                  ? const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFFFFA000),
                      size: 26,
                    )
                  : const DynamicDiamondIcon(width: 28, height: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+$diamonds Diamonds',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2128),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isSeller
                      ? 'Diamond Seller • Transferred to Account'
                      : 'BDT ${amount.toStringAsFixed(2)} • $paymentMethod${trxId.isNotEmpty ? ' • Trx: $trxId' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(dt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
