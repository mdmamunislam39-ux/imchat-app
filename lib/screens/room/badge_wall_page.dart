import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/dialogs/badge_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

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

  List<Map<String, dynamic>> _userOwnedBadges = [];
  List<Map<String, dynamic>> _allCatalogBadges = [];
  List<Map<String, dynamic>> _userOwnedNameplates = [];
  List<Map<String, dynamic>> _allCatalogNameplates = [];
  Map<String, dynamic>? _userProfileData;
  String _activeTab = 'Badge';

  StreamSubscription<QuerySnapshot>? _badgesSubscription;
  StreamSubscription<QuerySnapshot>? _nameplatesSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<User?>? _authSubscription;

  int _getBadgeTier(Map<String, dynamic> item) {
    final name = (item['name'] ?? item['storeItemName'] ?? item['title'] ?? '')
        .toString()
        .toLowerCase();
    final cat =
        (item['subCategory'] ?? item['category'] ?? item['badgeSubCategory'] ?? '')
            .toString()
            .toLowerCase();
    final id = (item['storeItemId'] ?? item['id'] ?? '').toString().toLowerCase();
    final tag = (item['tag'] ?? item['badgeTag'] ?? '').toString().toLowerCase();

    final bool isOfficialOrVerif = (cat == 'verification' && !cat.contains('svip') && !cat.contains('vip')) ||
        cat.contains('official') ||
        name.contains('official') ||
        name.contains('verif') ||
        name.contains('assistant') ||
        name.contains('admin') ||
        name.contains('moderator') ||
        name.contains('staff') ||
        name.contains('ভেরিফাই') ||
        name.contains('অফিসিয়াল') ||
        id.contains('official') ||
        id.contains('verif') ||
        tag.contains('official') ||
        tag.contains('verif');

    final bool isVip = name.contains('svip') ||
        name.contains('vip') ||
        name.contains('premium') ||
        name.contains('member') ||
        name.contains('এসভিআইপি') ||
        name.contains('ভিআইপি') ||
        cat.contains('svip') ||
        cat.contains('vip') ||
        cat.contains('premium') ||
        cat.contains('member') ||
        id.contains('svip') ||
        id.contains('vip') ||
        tag.contains('vip') ||
        tag.contains('svip');

    if (isOfficialOrVerif && !isVip) return 3; // Official & Verification (Highest)
    if (isVip) return 2;                      // VIP & SVIP
    if (isOfficialOrVerif) return 3;
    return 1;                                 // Other / Non-verify
  }

  int _getVerifyLevel(Map<String, dynamic> item) {
    int explicitLevel = 0;

    for (final key in [
      'verifyLevel',
      'verificationLevel',
      'officialLevel',
      'badgeLevel',
      'levelNum',
      'level',
    ]) {
      final val = item[key];
      if (val is num && val > explicitLevel) {
        explicitLevel = val.toInt();
      } else if (val is String && val.isNotEmpty) {
        final parsed = int.tryParse(val);
        if (parsed != null && parsed > explicitLevel) {
          explicitLevel = parsed;
        } else {
          final match = RegExp(r'(\d+)').firstMatch(val);
          if (match != null) {
            final numVal = int.tryParse(match.group(1)!);
            if (numVal != null && numVal > explicitLevel) explicitLevel = numVal;
          }
        }
      }
    }

    if (explicitLevel > 0) {
      return explicitLevel;
    }

    final name =
        (item['name'] ?? item['storeItemName'] ?? item['title'] ?? '').toString();
    final match = RegExp(r'(?:level|lvl|official|verif|v|svip|vip)\s*(\d+)',
            caseSensitive: false)
        .firstMatch(name);
    if (match != null) {
      final val = int.tryParse(match.group(1)!);
      if (val != null && val > explicitLevel) explicitLevel = val;
    }

    if (explicitLevel > 0) {
      return explicitLevel;
    }

    final int tier = _getBadgeTier(item);
    if (tier == 3) {
      return 2; // Official / Verification badges default to level 2
    } else if (tier == 2) {
      return 1; // VIP / SVIP badges default to level 1
    }

    return 0; // Non-verified badges have level 0
  }

  int _getStarCount(dynamic rating, [Map<String, dynamic>? item]) {
    int maxStars = 1;

    if (rating is num && rating > maxStars) {
      maxStars = rating.toInt();
    } else if (rating is String && rating.isNotEmpty) {
      final parsed = int.tryParse(rating);
      if (parsed != null && parsed > maxStars) {
        maxStars = parsed;
      } else {
        final match = RegExp(r'(\d+)').firstMatch(rating);
        if (match != null) {
          final val = int.tryParse(match.group(1)!);
          if (val != null && val > maxStars) maxStars = val;
        }
      }
    }

    if (item != null) {
      for (final key in [
        'starRating',
        'stars',
        'star',
        'rating',
        'tier'
      ]) {
        final val = item[key];
        if (val is num && val > maxStars) {
          maxStars = val.toInt();
        } else if (val is String && val.isNotEmpty) {
          final parsed = int.tryParse(val);
          if (parsed != null && parsed > maxStars) {
            maxStars = parsed;
          } else {
            final match = RegExp(r'(\d+)').firstMatch(val);
            if (match != null) {
              final numVal = int.tryParse(match.group(1)!);
              if (numVal != null && numVal > maxStars) maxStars = numVal;
            }
          }
        }
      }

      final name =
          (item['name'] ?? item['storeItemName'] ?? item['title'] ?? '').toString();
      final starMatch =
          RegExp(r'(\d+)\s*(?:star|stars|★)', caseSensitive: false).firstMatch(name);
      if (starMatch != null) {
        final val = int.tryParse(starMatch.group(1)!);
        if (val != null && val > maxStars) maxStars = val;
      }

      final upper = name.toUpperCase();
      if (upper.contains(' IV') || upper.endsWith('IV')) {
        if (4 > maxStars) maxStars = 4;
      } else if (upper.contains(' III') || upper.endsWith('III')) {
        if (3 > maxStars) maxStars = 3;
      } else if (upper.contains(' II') || upper.endsWith('II')) {
        if (2 > maxStars) maxStars = 2;
      } else if (upper.contains(' V') || upper.endsWith('V')) {
        if (5 > maxStars) maxStars = 5;
      }
    }

    return maxStars;
  }

  int _getStarRating(dynamic rating, [Map<String, dynamic>? item]) {
    return _getStarCount(rating, item);
  }

  Map<String, int> _catalogAdminIndexMap = {};

  int _getAdminIndex(Map<String, dynamic> b) {
    if (_catalogAdminIndexMap.isEmpty) return -1;
    final storeItemId = (b['storeItemId'] ?? '').toString();
    if (storeItemId.isNotEmpty && _catalogAdminIndexMap.containsKey(storeItemId)) {
      return _catalogAdminIndexMap[storeItemId]!;
    }
    final id = (b['id'] ?? '').toString();
    if (id.isNotEmpty && _catalogAdminIndexMap.containsKey(id)) {
      return _catalogAdminIndexMap[id]!;
    }
    final img = (b['imageUrl'] ?? '').toString().trim();
    if (img.isNotEmpty && _catalogAdminIndexMap.containsKey(img)) {
      return _catalogAdminIndexMap[img]!;
    }
    final name = (b['name'] ?? b['storeItemName'] ?? '').toString().toLowerCase().trim();
    if (name.isNotEmpty && _catalogAdminIndexMap.containsKey(name)) {
      return _catalogAdminIndexMap[name]!;
    }
    return -1;
  }

  int _compareBadges(Map<String, dynamic> a, Map<String, dynamic> b) {
    // 1. Unlocked badges before locked badges
    final bool unlockedA = a['isUnlocked'] == true;
    final bool unlockedB = b['isUnlocked'] == true;
    if (unlockedA != unlockedB) {
      return unlockedA ? -1 : 1;
    }

    // 2. Primary: Verify Level ("স্টার এর চেয়ে ভেরিফাই লেবেল এর প্রাধান্য বেশি")
    final int vLevelA = _getVerifyLevel(a);
    final int vLevelB = _getVerifyLevel(b);
    if (vLevelA != vLevelB) {
      return vLevelB.compareTo(vLevelA); // Higher verify level strictly on top!
    }

    // 3. Secondary: Star Level ("তার পরে স্টার, যত স্টার কমবে তত নিচে যাবে")
    // "আর ২ টাই যদি বেশি থাকে তাহলে আরও টপ"
    final int starA = _getStarCount(a['starRating'], a);
    final int starB = _getStarCount(b['starRating'], b);
    if (starA != starB) {
      return starB.compareTo(starA); // Higher stars on top, as stars decrease it goes lower!
    }

    // 4. Tier tie-breaker (Official > VIP > Non-verified)
    final int tierA = _getBadgeTier(a);
    final int tierB = _getBadgeTier(b);
    if (tierA != tierB) {
      return tierB.compareTo(tierA);
    }

    // 5. Explicit admin order / sortOrder / index (lowest number on top)
    final orderA = a['order'] ?? a['sortOrder'] ?? a['index'] ?? a['priority'];
    final orderB = b['order'] ?? b['sortOrder'] ?? b['index'] ?? b['priority'];
    if (orderA is num && orderB is num && orderA != orderB) {
      return orderA.compareTo(orderB);
    }
    if (orderA is num && orderB == null) return -1;
    if (orderA == null && orderB is num) return 1;

    // 5. Admin Panel catalog order (top to bottom as displayed in Admin Panel)
    final int idxA = _getAdminIndex(a);
    final int idxB = _getAdminIndex(b);
    if (idxA != -1 && idxB != -1 && idxA != idxB) {
      return idxA.compareTo(idxB);
    }
    if (idxA != -1 && idxB == -1) return -1;
    if (idxA == -1 && idxB != -1) return 1;

    // 6. Admin Panel timestamp ordering: createdAt or assignedAt descending (newest on top)
    final dateA = a['createdAt'] ?? a['assignedAt'];
    final dateB = b['createdAt'] ?? b['assignedAt'];
    if (dateA is Timestamp && dateB is Timestamp && dateA != dateB) {
      return dateB.compareTo(dateA);
    }
    if (dateA is Timestamp && dateB == null) return -1;
    if (dateA == null && dateB is Timestamp) return 1;

    // 7. Alphabetical fallback
    final String nameA = (a['name'] ?? a['storeItemName'] ?? '').toString();
    final String nameB = (b['name'] ?? b['storeItemName'] ?? '').toString();
    return nameA.compareTo(nameB);
  }

  @override
  void initState() {
    super.initState();
    _userOwnedBadges = List<Map<String, dynamic>>.from(widget.badgeItems);
    _storeService.checkAndCleanupExpiredUserItems(widget.userID);
    _loadUserProfile();
    _loadAllCatalogBadges();
    _subscribeToBadgesLive();
    _loadAllCatalogNameplates();
    _subscribeToNameplatesLive();
  }

  @override
  void dispose() {
    _badgesSubscription?.cancel();
    _nameplatesSubscription?.cancel();
    _userSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _loadUserProfile() {
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('Users')
        .doc(widget.userID)
        .snapshots()
        .listen((doc) {
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _userProfileData = doc.data();
        });
      }
    });

    final currentUserId = AuthController.instance.currentUser.userId;
    if (widget.userID == currentUserId) {
      _authSubscription?.cancel();
      _authSubscription =
          AuthController.instance.currentUserStream.listen((user) {
        if (mounted && user != null) {
          setState(() {
            _userProfileData ??= {};
            if (user.fullname.trim().isNotEmpty) {
              _userProfileData!['fullname'] = user.fullname.trim();
            }
            if (user.photoUrl.trim().isNotEmpty) {
              _userProfileData!['photoUrl'] = user.photoUrl.trim();
            }
          });
        }
      });
    }
  }

  Future<void> _loadAllCatalogBadges() async {
    try {
      final List<Map<String, dynamic>> catalog = [];

      // Query market_items collection
      final marketSnap = await _firestore
          .collection('market_items')
          .where('type', isEqualTo: 'badge')
          .get();

      for (final doc in marketSnap.docs) {
        final data = doc.data();
        catalog.add({
          'id': doc.id,
          'storeItemId': doc.id,
          'name': data['name'] ?? data['title'] ?? 'Badge',
          'imageUrl': data['thumbnailUrl'] ??
              data['fileUrl'] ??
              data['imageUrl'] ??
              data['image'],
          'subCategory': data['badgeSubCategory'] ??
              data['subCategory'] ??
              data['category'] ??
              '',
          'description': data['description'] ??
              'Become an official assistant to get this honor',
          'tag': data['tag'] ?? data['badgeTag'] ?? '',
          'createdAt': data['createdAt'],
          'assignedAt': data['assignedAt'],
          'order': data['order'] ?? data['sortOrder'] ?? data['index'] ?? data['priority'],
          'sortOrder': data['sortOrder'] ?? data['order'],
          'starRating': _getStarRating(data['starRating'] ??
              data['stars'] ??
              data['rating'] ??
              data['level']),
          'verifyLevel': data['verifyLevel'] ??
              data['verificationLevel'] ??
              data['officialLevel'] ??
              0,
        });
      }

      // Query official_items collection as fallback / complement
      final officialSnap = await _firestore
          .collection('official_items')
          .where('category', isEqualTo: 'badge')
          .get();

      for (final doc in officialSnap.docs) {
        final data = doc.data();
        if (!catalog.any(
            (item) => item['id'] == doc.id || item['storeItemId'] == doc.id)) {
          catalog.add({
            'id': doc.id,
            'storeItemId': doc.id,
            'name': data['name'] ?? data['title'] ?? 'Badge',
            'imageUrl': data['thumbnailUrl'] ??
                data['fileUrl'] ??
                data['imageUrl'] ??
                data['image'],
            'subCategory': data['badgeSubCategory'] ??
                data['subCategory'] ??
                '',
            'description': data['description'] ??
                'Become an official assistant to get this honor',
            'tag': data['tag'] ?? data['badgeTag'] ?? '',
            'createdAt': data['createdAt'],
            'assignedAt': data['assignedAt'],
            'order': data['order'] ?? data['sortOrder'] ?? data['index'] ?? data['priority'],
            'sortOrder': data['sortOrder'] ?? data['order'],
            'starRating': _getStarRating(data['starRating'] ??
                data['stars'] ??
                data['rating'] ??
                data['level']),
            'verifyLevel': data['verifyLevel'] ??
                data['verificationLevel'] ??
                data['officialLevel'] ??
                0,
          });
        }
      }

      // Sort catalog exactly as AdminAssetsService does in the Admin Panel
      catalog.sort((a, b) {
        final orderA = a['order'] ?? a['sortOrder'] ?? a['index'] ?? a['priority'];
        final orderB = b['order'] ?? b['sortOrder'] ?? b['index'] ?? b['priority'];
        if (orderA is num && orderB is num && orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate != null && bDate != null && aDate != bDate) {
          return bDate.compareTo(aDate);
        }
        final starA = a['starRating'] as int? ?? 1;
        final starB = b['starRating'] as int? ?? 1;
        if (starB != starA) return starB.compareTo(starA);
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });

      final Map<String, int> indexMap = {};
      for (int i = 0; i < catalog.length; i++) {
        catalog[i]['adminCatalogIndex'] = i;
        final id = catalog[i]['id']?.toString() ?? '';
        final storeItemId = catalog[i]['storeItemId']?.toString() ?? '';
        final name = (catalog[i]['name'] ?? '').toString().toLowerCase().trim();
        final img = (catalog[i]['imageUrl'] ?? '').toString().trim();
        if (id.isNotEmpty) indexMap[id] = i;
        if (storeItemId.isNotEmpty) indexMap[storeItemId] = i;
        if (name.isNotEmpty) indexMap[name] = i;
        if (img.isNotEmpty) indexMap[img] = i;
      }

      if (mounted) {
        setState(() {
          _allCatalogBadges = catalog;
          _catalogAdminIndexMap = indexMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading catalog badges: $e');
    }
  }

  void _subscribeToBadgesLive() {
    _badgesSubscription?.cancel();
    _badgesSubscription = _firestore
        .collection('user_store_items')
        .where('userId', isEqualTo: widget.userID)
        .where('itemType', isEqualTo: 'badge')
        .where('isActive', isEqualTo: true)
        .limit(150)
        .snapshots()
        .listen((badgeDocs) async {
      try {
        if (badgeDocs.docs.isNotEmpty) {
          final List<Map<String, dynamic>> loadedBadges =
              badgeDocs.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'storeItemId': data['storeItemId'] ?? '',
              'storeItemName': data['storeItemName'] ?? data['name'] ?? 'Badge',
              'expiresAt': data['expiresAt'],
              'assignedAt': data['assignedAt'],
              'createdAt': data['createdAt'],
              'order': data['order'] ?? data['sortOrder'] ?? data['index'] ?? data['priority'],
              'imageUrl': data['imageUrl'] ??
                  data['pngUrl'] ??
                  data['thumbnailUrl'] ??
                  data['fileUrl'],
              'description': data['description'] ??
                  'Become an official assistant to get this honor',
              'subCategory': data['badgeSubCategory'] ??
                  data['subCategory'] ??
                  data['category'] ??
                  '',
              'starRating': _getStarRating(data['starRating'] ??
                  data['stars'] ??
                  data['rating'] ??
                  data['level']),
              'verifyLevel': data['verifyLevel'] ??
                  data['verificationLevel'] ??
                  data['officialLevel'] ??
                  0,
            };
          }).toList();

          // Fetch detail from market_items or official_items for missing fields
          for (int i = 0; i < loadedBadges.length; i++) {
            final storeItemId = loadedBadges[i]['storeItemId'] as String;
            if (storeItemId.isNotEmpty) {
              try {
                var details =
                    await _storeService.getStoreItemDetails(storeItemId);
                if (details == null) {
                  try {
                    final offDoc = await _firestore
                        .collection('official_items')
                        .doc(storeItemId)
                        .get();
                    if (offDoc.exists && offDoc.data() != null) {
                      details = offDoc.data();
                    }
                  } catch (_) {}
                }
                if (details != null) {
                  if (details['createdAt'] != null && loadedBadges[i]['createdAt'] == null) {
                    loadedBadges[i]['createdAt'] = details['createdAt'];
                  }
                  if (details['order'] != null || details['sortOrder'] != null || details['index'] != null) {
                    loadedBadges[i]['order'] = details['order'] ?? details['sortOrder'] ?? details['index'];
                  }
                  loadedBadges[i]['imageUrl'] = details['thumbnailUrl'] ??
                      details['fileUrl'] ??
                      details['imageUrl'] ??
                      details['image'] ??
                      loadedBadges[i]['imageUrl'];
                  if (details['description'] != null &&
                      details['description'].toString().isNotEmpty) {
                    loadedBadges[i]['description'] = details['description'];
                  }
                  if (details['badgeSubCategory'] != null ||
                      details['subCategory'] != null ||
                      details['category'] != null) {
                    loadedBadges[i]['subCategory'] =
                        details['badgeSubCategory'] ??
                            details['subCategory'] ??
                            details['category'];
                  }
                  if (details['name'] != null || details['title'] != null) {
                    loadedBadges[i]['storeItemName'] = details['name'] ??
                        details['title'] ??
                        loadedBadges[i]['storeItemName'];
                  }
                  final detailRating = details['starRating'] ??
                      details['stars'] ??
                      details['rating'] ??
                      details['level'];
                  if (detailRating != null) {
                    loadedBadges[i]['starRating'] =
                        _getStarRating(detailRating, details);
                  }
                  final detailVerify = details['verifyLevel'] ??
                      details['verificationLevel'] ??
                      details['officialLevel'];
                  if (detailVerify != null) {
                    loadedBadges[i]['verifyLevel'] = detailVerify;
                  }
                }
              } catch (_) {}
            }
          }

          // Filter out expired items
          final now = DateTime.now();
          loadedBadges.removeWhere((item) {
            final exp = item['expiresAt'];
            if (exp is Timestamp) {
              final expDate = exp.toDate();
              if (expDate.year < 2090 && expDate.isBefore(now)) {
                return true;
              }
            }
            return false;
          });

          // Deduplicate
          final Map<String, Map<String, dynamic>> dedup = {};
          for (final entry in loadedBadges) {
            final storeItemId = entry['storeItemId'] as String?;
            if (storeItemId != null && storeItemId.isNotEmpty) {
              if (!dedup.containsKey(storeItemId)) {
                dedup[storeItemId] = entry;
              }
            } else {
              dedup[entry['id'] ??
                  DateTime.now().microsecondsSinceEpoch.toString()] = entry;
            }
          }

          // Automatically merge badges from user customization.ownedBadges (Requirement 6)
          if (_userProfileData != null) {
            final cust =
                _userProfileData!['customization'] as Map<String, dynamic>?;
            final List<dynamic> ownedBadges = cust?['ownedBadges'] ?? [];
            for (var badgeUrl in ownedBadges) {
              if (badgeUrl is String && badgeUrl.isNotEmpty) {
                if (!dedup.values.any((b) => b['imageUrl'] == badgeUrl)) {
                  dedup[badgeUrl] = {
                    'id': badgeUrl,
                    'storeItemId': badgeUrl,
                    'storeItemName': 'VIP / Member Badge',
                    'imageUrl': badgeUrl,
                    'description':
                        'Exclusive member badge representing user status.',
                    'subCategory': 'Verification',
                    'starRating': 1,
                    'expiresAt': null,
                  };
                }
              }
            }
          }

          final List<Map<String, dynamic>> activeBadges =
              dedup.values.where((item) {
            final exp = item['expiresAt'] as Timestamp?;
            if (exp == null) return true;
            return exp.toDate().year >= 2090 || exp.toDate().isAfter(now);
          }).toList();

          if (mounted) {
            setState(() {
              _userOwnedBadges = activeBadges;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _userOwnedBadges = [];
            });
          }
        }
      } catch (e) {
        debugPrint('❌ Error updating badges live on wall: $e');
      }
    }, onError: (e) {
      debugPrint('❌ Stream error loading badges live: $e');
    });
  }

  Future<void> _loadAllCatalogNameplates() async {
    try {
      final List<Map<String, dynamic>> catalog = [];

      // Query market_items collection for nameplates
      final marketSnap = await _firestore
          .collection('market_items')
          .where('type', isEqualTo: 'nameplate')
          .get();

      for (final doc in marketSnap.docs) {
        final data = doc.data();
        catalog.add({
          'id': doc.id,
          'storeItemId': doc.id,
          'name': data['name'] ?? data['title'] ?? 'Nameplate',
          'imageUrl': data['thumbnailUrl'] ??
              data['fileUrl'] ??
              data['imageUrl'] ??
              data['image'],
          'description': data['description'] ??
              'A beautiful nameplate to decorate your profile.',
          'starRating': data['starRating'] ?? 1,
        });
      }

      // Query official_items collection for nameplates
      final officialSnap = await _firestore
          .collection('official_items')
          .where('category', isEqualTo: 'nameplate')
          .get();

      for (final doc in officialSnap.docs) {
        final data = doc.data();
        if (!catalog.any(
            (item) => item['id'] == doc.id || item['storeItemId'] == doc.id)) {
          catalog.add({
            'id': doc.id,
            'storeItemId': doc.id,
            'name': data['name'] ?? data['title'] ?? 'Nameplate',
            'imageUrl': data['thumbnailUrl'] ??
                data['fileUrl'] ??
                data['imageUrl'] ??
                data['image'],
            'description': data['description'] ??
                'A beautiful nameplate to decorate your profile.',
            'starRating': data['starRating'] ?? 1,
          });
        }
      }

      if (mounted) {
        setState(() {
          _allCatalogNameplates = catalog;
        });
      }
    } catch (e) {
      debugPrint('Error loading catalog nameplates: $e');
    }
  }

  void _subscribeToNameplatesLive() {
    _nameplatesSubscription?.cancel();
    _nameplatesSubscription = _firestore
        .collection('user_store_items')
        .where('userId', isEqualTo: widget.userID)
        .where('itemType', isEqualTo: 'nameplate')
        .where('isActive', isEqualTo: true)
        .limit(100)
        .snapshots()
        .listen((nameplateDocs) async {
      try {
        final List<Map<String, dynamic>> loadedNameplates = [];
        for (final doc in nameplateDocs.docs) {
          final data = doc.data();
          final entry = {
            'id': doc.id,
            'storeItemId': data['storeItemId'] ?? '',
            'storeItemName': data['storeItemName'] ?? 'Nameplate',
            'expiresAt': data['expiresAt'],
            'assignedAt': data['assignedAt'],
            'imageUrl': data['imageUrl'] ?? data['pngUrl'],
            'starRating': 1,
          };

          final storeItemId = entry['storeItemId'] as String;
          if (storeItemId.isNotEmpty) {
            try {
              final details =
                  await _storeService.getStoreItemDetails(storeItemId);
              if (details != null) {
                entry['imageUrl'] = details['thumbnailUrl'] ??
                    details['fileUrl'] ??
                    details['imageUrl'] ??
                    details['image'] ??
                    entry['imageUrl'];
                entry['description'] = details['description'] ??
                    'A beautiful nameplate to decorate your profile.';
                entry['storeItemName'] =
                    details['name'] ?? entry['storeItemName'];
                entry['starRating'] = details['starRating'] ?? 1;
              }
            } catch (_) {}
          }
          loadedNameplates.add(entry);
        }

        // Deduplicate
        final Map<String, Map<String, dynamic>> dedup = {};
        for (final entry in loadedNameplates) {
          final storeItemId = entry['storeItemId'] as String?;
          if (storeItemId != null && storeItemId.isNotEmpty) {
            if (!dedup.containsKey(storeItemId)) {
              dedup[storeItemId] = entry;
            }
          } else {
            dedup[entry['id'] ??
                DateTime.now().microsecondsSinceEpoch.toString()] = entry;
          }
        }

        final now = DateTime.now();
        final List<Map<String, dynamic>> activeNameplates =
            dedup.values.where((item) {
          final exp = item['expiresAt'] as Timestamp?;
          if (exp == null) return true;
          return exp.toDate().isAfter(now);
        }).toList();

        if (mounted) {
          setState(() {
            _userOwnedNameplates = activeNameplates;
          });
        }
      } catch (e) {
        debugPrint('❌ Error updating nameplates live: $e');
      }
    }, onError: (e) {
      debugPrint('❌ Stream error nameplates live: $e');
    });
  }

  List<Map<String, dynamic>> _getEquippedNameplates() {
    if (_userProfileData == null) return [];
    final customization =
        _userProfileData!['customization'] as Map<String, dynamic>?;
    if (customization == null) return [];

    final selectedNameplateId = customization['selectedNameplateId'] as String?;
    final selectedNameplateIds =
        (customization['selectedNameplateIds'] as List?)
                ?.whereType<String>()
                .toList() ??
            [];

    final List<String> equippedIds = [...selectedNameplateIds];
    if (selectedNameplateId != null &&
        selectedNameplateId.isNotEmpty &&
        !equippedIds.contains(selectedNameplateId)) {
      equippedIds.insert(0, selectedNameplateId);
    }

    if (equippedIds.isEmpty) return [];

    final List<Map<String, dynamic>> result = [];
    for (final id in equippedIds) {
      var found = _userOwnedNameplates
          .firstWhereOrNull((item) => item['storeItemId'] == id);
      found ??= _allCatalogNameplates
          .firstWhereOrNull((item) => item['storeItemId'] == id);
      if (found != null &&
          !result.any((item) => (item['storeItemId'] ?? item['id']) == id)) {
        result.add(found);
      }
    }
    return result;
  }

  void _showNameplateDetails(Map<String, dynamic> nameplate, bool isUnlocked) {
    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;
    final name = nameplate['storeItemName'] ?? nameplate['name'] ?? 'Nameplate';
    final imageUrl = nameplate['imageUrl'] as String?;
    final description = nameplate['description'] as String? ??
        'A beautiful nameplate to decorate your profile.';
    final expiresAt = nameplate['expiresAt'];
    final storeItemId = nameplate['storeItemId'] ?? nameplate['id'] ?? '';
    final rating = _getStarRating(nameplate['starRating']);

    final customization =
        _userProfileData?['customization'] as Map<String, dynamic>?;
    final selectedNameplateId =
        customization?['selectedNameplateId'] as String?;
    final selectedNameplateIds =
        customization?['selectedNameplateIds'] as List<dynamic>?;

    bool isEquipped = false;
    if (selectedNameplateId != null && selectedNameplateId.isNotEmpty) {
      isEquipped = selectedNameplateId == storeItemId;
    } else if (selectedNameplateIds != null &&
        selectedNameplateIds.isNotEmpty) {
      isEquipped = selectedNameplateIds.contains(storeItemId);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 110,
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUnlocked
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? (isUnlocked
                            ? UniversalAssetWidget(
                                url: imageUrl,
                                fit: BoxFit.contain,
                                looping: true,
                              )
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.grey,
                                  BlendMode.saturation,
                                ),
                                child: UniversalAssetWidget(
                                  url: imageUrl,
                                  fit: BoxFit.contain,
                                  looping: false,
                                ),
                              ))
                        : const Icon(Icons.badge_outlined,
                            size: 64, color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2022),
                      fontFamily: 'Outfit',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isUnlocked ? 'Unlocked' : 'Locked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '$rating',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF686D76),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (isUnlocked && expiresAt != null) ...[
                    Text(
                      'Expires: ${_formatExpiryDate(expiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Equip / Unequip actions
                  if (isOwner && isUnlocked && storeItemId.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                            isEquipped
                                ? Icons.remove_circle_outline
                                : Icons.check_circle_outline,
                            size: 18),
                        label: Text(isEquipped ? 'Remove' : 'Use Nameplate'),
                        onPressed: () async {
                          if (isEquipped) {
                            try {
                              await _storeService.unequipItem(
                                currentUser.userId,
                                'nameplate',
                                storeItemId,
                              );
                              setDialogState(() => isEquipped = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Nameplate "$name" removed!'),
                                  backgroundColor: Colors.grey.shade700,
                                ));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
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
                                'nameplate',
                              );
                              setDialogState(() => isEquipped = true);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Nameplate "$name" equipped!'),
                                  backgroundColor: Colors.green,
                                ));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          }
                          // Refresh local user profile view
                          _loadUserProfile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped
                              ? Colors.grey.shade700
                              : const Color(0xFF29B6F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showBadgeDetails(Map<String, dynamic> badge, bool isUnlocked) {
    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;

    BadgeDetailDialog.show(
      context,
      badge: badge,
      isOwner: isOwner,
      isUnlocked: isUnlocked,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Badge Wall Info',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Badges represent your achievements, activity, and prestigious status in the app.\n\n'
          'Only active badges assigned to you from the admin team or earned through events are displayed here during their validity period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;

    // Check all possible avatar/image fields for real-time fallback
    final avatarUrl = _userProfileData?['photoUrl'] ??
        _userProfileData?['imageUrl'] ??
        _userProfileData?['profileImageUrl'] ??
        _userProfileData?['image'] ??
        _userProfileData?['profilePic'] ??
        _userProfileData?['avatarUrl'] ??
        _userProfileData?['userImageUrl'] ??
        (isOwner ? currentUser.photoUrl : '');

    String displayName = '';
    if (_userProfileData != null) {
      final fn = _userProfileData!['fullname'];
      if (fn != null && fn.toString().trim().isNotEmpty) {
        displayName = fn.toString().trim();
      } else {
        final n = _userProfileData!['name'] ??
            _userProfileData!['username'] ??
            _userProfileData!['nickname'];
        if (n != null && n.toString().trim().isNotEmpty) {
          displayName = n.toString().trim();
        }
      }
    }
    if (displayName.isEmpty) {
      if (isOwner && currentUser.fullname.trim().isNotEmpty) {
        displayName = currentUser.fullname.trim();
      } else if (widget.userName.trim().isNotEmpty) {
        displayName = widget.userName.trim();
      } else {
        displayName = 'User';
      }
    }

    // Combine all catalog badges with user owned badges
    final Map<String, Map<String, dynamic>> combinedBadgesMap = {};

    // Add catalog badges first
    for (final catBadge in _allCatalogBadges) {
      final key = catBadge['storeItemId'] ?? catBadge['id'];
      combinedBadgesMap[key] = {
        ...catBadge,
        'isUnlocked': false,
      };
    }

    // Mark owned badges as unlocked
    for (final owned in _userOwnedBadges) {
      final key = owned['storeItemId'] ?? owned['id'];
      if (combinedBadgesMap.containsKey(key)) {
        combinedBadgesMap[key]!['isUnlocked'] = true;
        combinedBadgesMap[key]!['expiresAt'] = owned['expiresAt'];
        combinedBadgesMap[key]!['assignedAt'] = owned['assignedAt'];
        if (owned['createdAt'] != null) {
          combinedBadgesMap[key]!['createdAt'] = owned['createdAt'];
        }
        if (owned['order'] != null) {
          combinedBadgesMap[key]!['order'] = owned['order'];
        }
        if (owned['starRating'] != null) {
          combinedBadgesMap[key]!['starRating'] =
              _getStarRating(owned['starRating'], owned);
        }
        if (owned['verifyLevel'] != null) {
          combinedBadgesMap[key]!['verifyLevel'] = owned['verifyLevel'];
        }
        if (owned['description'] != null &&
            owned['description'].toString().isNotEmpty) {
          combinedBadgesMap[key]!['description'] = owned['description'];
        }
        if (owned['subCategory'] != null) {
          combinedBadgesMap[key]!['subCategory'] = owned['subCategory'];
        }
      } else {
        combinedBadgesMap[key] = {
          'id': key,
          'storeItemId': key,
          'name': owned['storeItemName'] ?? owned['name'] ?? 'Badge',
          'imageUrl': owned['imageUrl'],
          'subCategory': owned['subCategory'] ?? '',
          'description': owned['description'] ??
              'Become an official assistant to get this honor',
          'isUnlocked': true,
          'expiresAt': owned['expiresAt'],
          'assignedAt': owned['assignedAt'],
          'createdAt': owned['createdAt'],
          'order': owned['order'],
          'starRating': _getStarRating(owned['starRating'], owned),
          'verifyLevel': owned['verifyLevel'] ?? _getVerifyLevel(owned),
        };
      }
    }

    final allDisplayBadges = combinedBadgesMap.values
        .where((b) => b['isUnlocked'] == true)
        .toList();
    allDisplayBadges.sort(_compareBadges);

    // Helper to check if badge belongs to Verification
    bool isVerificationBadge(Map<String, dynamic> b) {
      final cat =
          (b['subCategory'] ?? b['category'] ?? '').toString().toLowerCase();
      final name =
          (b['name'] ?? b['storeItemName'] ?? '').toString().toLowerCase();
      return cat.contains('verif') ||
          cat.contains('official') ||
          name.contains('verif') ||
          name.contains('official');
    }

    String normalizeCategory(Map<String, dynamic> b) {
      if (isVerificationBadge(b) || _getVerifyLevel(b) > 0) return 'Verification';
      final cat = (b['subCategory'] ?? b['category'] ?? '').toString().trim();
      final lower = cat.toLowerCase();
      if (lower.contains('achieve')) return 'Achievement';
      if (lower.contains('honor')) return 'Honor';
      if (lower.contains('activ')) return 'Activity';
      if (lower.contains('special')) return 'Special';
      if (cat.isNotEmpty && cat.toLowerCase() != 'verification') {
        return cat[0].toUpperCase() + cat.substring(1);
      }
      return 'Verification';
    }

    // Group badges by subCategory for top-to-bottom display
    final Map<String, List<Map<String, dynamic>>> groupedBadges = {};
    final defaultCategories = [
      'Verification',
      'Achievement',
      'Honor',
      'Activity',
      'Special'
    ];

    for (final cat in defaultCategories) {
      groupedBadges[cat] = [];
    }

    for (final badge in allDisplayBadges) {
      final cat = normalizeCategory(badge);
      if (!groupedBadges.containsKey(cat)) {
        groupedBadges[cat] = [];
      }
      groupedBadges[cat]!.add(badge);
    }

    // Remove empty categories if no items exist for them
    groupedBadges.removeWhere((key, list) => list.isEmpty);

    // Sort the badges inside each category strictly by our hierarchy comparator:
    // 1) Verification badges with higher stars at top
    // 2) Verification badges with lower stars below
    // 3) VIP & SVIP badges below verification badges (higher stars first, SVIP before VIP)
    // 4) Other badges below VIP & SVIP
    for (final cat in groupedBadges.keys) {
      groupedBadges[cat]!.sort(_compareBadges);
    }

    // Combine all catalog nameplates with user owned nameplates
    final Map<String, Map<String, dynamic>> combinedNameplatesMap = {};

    for (final catNP in _allCatalogNameplates) {
      final key = catNP['storeItemId'] ?? catNP['id'];
      combinedNameplatesMap[key] = {
        ...catNP,
        'isUnlocked': false,
      };
    }

    for (final owned in _userOwnedNameplates) {
      final key = owned['storeItemId'] ?? owned['id'];
      if (combinedNameplatesMap.containsKey(key)) {
        combinedNameplatesMap[key]!['isUnlocked'] = true;
        combinedNameplatesMap[key]!['expiresAt'] = owned['expiresAt'];
      } else {
        combinedNameplatesMap[key] = {
          'id': key,
          'storeItemId': key,
          'name': owned['storeItemName'] ?? 'Nameplate',
          'imageUrl': owned['imageUrl'],
          'description': owned['description'] ??
              'A beautiful nameplate to decorate your profile.',
          'isUnlocked': true,
          'expiresAt': owned['expiresAt'],
          'starRating': owned['starRating'] ?? 1,
        };
      }
    }

    final allDisplayNameplates = combinedNameplatesMap.values
        .where((np) => np['isUnlocked'] == true)
        .toList();
    final equippedNameplates = _getEquippedNameplates();

    final List<Map<String, dynamic>> availableNameplates = [];
    for (final np in allDisplayNameplates) {
      final id = np['storeItemId'] ?? np['id'];
      if (equippedNameplates
          .any((emp) => (emp['storeItemId'] ?? emp['id']) == id)) {
        continue;
      }
      availableNameplates.add(np);
    }

    Widget buildBadgeView() {
      if (groupedBadges.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 54, color: Colors.grey),
                const SizedBox(height: 12),
                Text('No badges found',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groupedBadges.keys.length,
        itemBuilder: (context, catIndex) {
          final catName = groupedBadges.keys.elementAt(catIndex);
          final badgesList = groupedBadges[catName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  catName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2022),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: badgesList.length,
                itemBuilder: (context, index) {
                  final badge = badgesList[index];
                  final isUnlocked = badge['isUnlocked'] == true;
                  final imageUrl = badge['imageUrl'] as String?;
                  final name =
                      badge['name'] ?? badge['storeItemName'] ?? 'Badge';

                  return GestureDetector(
                    onTap: () => _showBadgeDetails(badge, isUnlocked),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? UniversalAssetWidget(
                                      url: imageUrl,
                                      fit: BoxFit.contain,
                                      looping: true,
                                    )
                                  : const Icon(
                                      Icons.shield,
                                      color: Colors.amber,
                                      size: 40,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, bottom: 12),
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF2D3142),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 2,
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
              const SizedBox(height: 12),
            ],
          );
        },
      );
    }

    Widget buildNameplateView() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My Nameplate Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'My Nameplate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          if (equippedNameplates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: equippedNameplates.map((equippedNameplate) {
                  return SizedBox(
                    width: 140,
                    child: GestureDetector(
                      onTap: () =>
                          _showNameplateDetails(equippedNameplate, true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: equippedNameplate['imageUrl'] != null &&
                                      (equippedNameplate['imageUrl'] as String)
                                          .isNotEmpty
                                  ? SizedBox(
                                      height: 40,
                                      child: UniversalAssetWidget(
                                        url: equippedNameplate['imageUrl'],
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const Icon(Icons.badge_outlined,
                                      size: 40, color: Colors.amber),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                equippedNameplate['storeItemName'] ??
                                    equippedNameplate['name'] ??
                                    'Nameplate',
                                style: const TextStyle(
                                  color: Color(0xFF2D3142),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 10),
                                        Text(
                                          ' ${_getStarRating(equippedNameplate['starRating'])}',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatExpiryDate(
                                        equippedNameplate['expiresAt']),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No nameplate equipped yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),

          const SizedBox(height: 20),

          // Available Nameplate Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Available nameplate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          if (availableNameplates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'No other nameplates available',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: availableNameplates.length,
              itemBuilder: (context, index) {
                final np = availableNameplates[index];
                final isUnlocked = np['isUnlocked'] == true;
                final imageUrl = np['imageUrl'] as String?;
                final name = np['name'] ?? np['storeItemName'] ?? 'Nameplate';
                final rating = _getStarRating(np['starRating']);

                return GestureDetector(
                  onTap: () => _showNameplateDetails(np, isUnlocked),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? UniversalAssetWidget(
                                    url: imageUrl,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(
                                    Icons.badge_outlined,
                                    color: Colors.amber,
                                    size: 32,
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 8, right: 8, bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF2D3142),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 8),
                                    Text(
                                      ' $rating',
                                      style: const TextStyle(
                                        color: Colors.amber,
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
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E2022)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Honor',
          style: TextStyle(
            color: Color(0xFF1E2022),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF1E2022)),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // User Avatar Section
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF81D4FA),
                          Color(0xFF80CBC4),
                          Color(0xFFA5D6A7)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.lightBlue.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: Container(
                      width: 78,
                      height: 78,
                      color: Colors.white,
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 44,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 44,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // User Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '★$displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2022),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),

            // Equipped Nameplate Badge Pills under User Name
            if (equippedNameplates.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...equippedNameplates.map((equippedNameplate) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (equippedNameplate['imageUrl'] != null &&
                                (equippedNameplate['imageUrl'] as String)
                                    .isNotEmpty)
                              Image.network(
                                equippedNameplate['imageUrl'],
                                height: 14,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.stars,
                                    color: Colors.white,
                                    size: 14),
                              )
                            else
                              const Icon(Icons.stars,
                                  color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              equippedNameplate['storeItemName'] ??
                                  equippedNameplate['name'] ??
                                  'Nameplate',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (isOwner) ...[
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeTab = 'Nameplate';
                          });
                        },
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (isOwner) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeTab = 'Nameplate';
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Set Nameplate',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Tab Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeTab = 'Nameplate';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 'Nameplate'
                                ? const Color(0xFF29B6F6)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Nameplate ${_userOwnedNameplates.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 'Nameplate'
                              ? const Color(0xFF29B6F6)
                              : Colors.grey.shade500,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeTab = 'Badge';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 'Badge'
                                ? const Color(0xFF29B6F6)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Badge ${_userOwnedBadges.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 'Badge'
                              ? const Color(0xFF29B6F6)
                              : Colors.grey.shade500,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (_activeTab == 'Nameplate')
              buildNameplateView()
            else
              buildBadgeView(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
