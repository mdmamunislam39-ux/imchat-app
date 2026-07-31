import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GiftWallPage extends StatefulWidget {
  final String userId;
  final String userName;
  final List<Map<String, dynamic>> gifts;

  const GiftWallPage({
    super.key,
    required this.userId,
    required this.userName,
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

  @override
  void initState() {
    super.initState();
    _gifts = List<Map<String, dynamic>>.from(widget.gifts);
    _listenToGiftWall();
  }

  @override
  void dispose() {
    _receivedSub?.cancel();
    _activeSub?.cancel();
    super.dispose();
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
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*x?\s*\d+\s*x?\s*\)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*combo\s*\)$', caseSensitive: false), '');
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
    final mergedDocs = <String, Map<String, dynamic>>{
      ..._activeDocs,
      ..._receivedDocs,
    };
    final giftMap = <String, Map<String, dynamic>>{};

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
      item['totalValue'] = (item['totalValue'] as int) + (credits * quantity);

      final previousTimestamp = item['lastTimestamp'] as DateTime;
      if (timestamp.isAfter(previousTimestamp)) {
        item['lastTimestamp'] = timestamp;
      }
    }

    final updated = giftMap.values.toList()
      ..sort((a, b) {
        final valueCompare =
            (b['totalValue'] as int).compareTo(a['totalValue'] as int);
        if (valueCompare != 0) return valueCompare;
        return (b['lastTimestamp'] as DateTime)
            .compareTo(a['lastTimestamp'] as DateTime);
      });

    if (mounted) {
      setState(() => _gifts = updated);
    } else {
      _gifts = updated;
    }
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

  @override
  Widget build(BuildContext context) {
    final sortedGifts = List<Map<String, dynamic>>.from(_gifts)
      ..sort((a, b) => (b['totalValue'] as int? ?? 0)
          .compareTo(a['totalValue'] as int? ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Gifts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: sortedGifts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No gifts received yet',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: sortedGifts.length,
              itemBuilder: (context, index) {
                final gift = sortedGifts[index];
                final imageUrl = gift['giftImageUrl'] as String? ?? '';
                final count = gift['count'] as int? ?? 1;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.card_giftcard,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.card_giftcard,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          '×$count',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
}
