import 'dart:async';
import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/services/family_service.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';
import 'package:chat_messenger/widgets/relationship_badge_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'gift_wall_page.dart';
import 'badge_wall_page.dart';
import 'package:chat_messenger/dialogs/badge_detail_dialog.dart';
import 'decoration_wall_page.dart';
import 'family_screen.dart';
import 'supporters_page.dart';
import 'intimacy_list_page.dart';
import 'package:chat_messenger/api/message_api.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/components/rich_text_viewer.dart';
import 'package:chat_messenger/screens/news_feed/post_media_viewer.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:chat_messenger/tabs/profile/edit_profile_screen.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';

class ProfilePageForRoom extends StatefulWidget {
  final String userID;
  final String userName;
  final String userImage;
  final String? roomActivityInfo;

  const ProfilePageForRoom({
    super.key,
    required this.userID,
    required this.userName,
    required this.userImage,
    this.roomActivityInfo,
  });

  @override
  State<ProfilePageForRoom> createState() => _ProfilePageForRoomState();
}

class _ProfilePageForRoomState extends State<ProfilePageForRoom> {
  static final _firestore = FirebaseFirestore.instance;
  final StoreService _storeService = StoreService();

  User? _viewedUser;
  bool isFollowing = false;
  bool isFriend = false;
  bool _isFollowActionRunning = false;
  bool isLoadingData = true;
  bool _hasPlayedRoomProfileBackground = false;
  Timer? _bgAnimationTimer;
  final PageController _homePageBgPageController = PageController();
  Timer? _homePageBgTimer;
  int followerCount = 0;
  int followingCount = 0;
  int visitorCount = 0;
  String level = '1';
  String searchId = '';
  int sendingLevel = 1;
  int receivingLevel = 1;
  String sendingLevelName = 'Beginner';
  String receivingLevelName = 'Beginner';
  String? currentFrameUrl;
  String? currentNameplateUrl;
  List<String> currentNameplateUrls = [];
  String bio = '';
  String userType = 'regular';
  String? agencyName;
  String? _roomProfileBackgroundUrl;
  String? _shortProfileThemeUrl;
  int currentDiamonds = 0;
  int beans = 0;
  int coins = 0;
  DateTime? memberSince;
  String? sendingLevelImageUrl;
  String? receivingLevelImageUrl;

  List<Map<String, dynamic>> receivedGifts = [];
  List<Map<String, dynamic>> badgeItems = [];
  List<Map<String, dynamic>> decorationItems = [];
  List<Map<String, dynamic>> supporters = [];
  List<Map<String, dynamic>> allSupporters = [];
  List<String> ownedBadges = [];
  List<Map<String, dynamic>> userRooms = [];
  List<Map<String, dynamic>> relationshipsList = [];
  bool isLoadingRelationships = false;
  String _giftSortMode = 'price';

  List<Map<String, dynamic>> _archiveGiftDocs = [];
  List<Map<String, dynamic>> _activeGiftDocs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _giftArchiveSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _giftActiveSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _userRoomsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _familySubscription;
  Map<String, dynamic>? _familyData;
  final Map<String, Map<String, dynamic>> _cachedUserProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startHomePageBgTimer();
  }

  void _startHomePageBgTimer() {
    _homePageBgTimer?.cancel();
    _homePageBgTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_viewedUser == null || !mounted) return;
      final int bgCount = _viewedUser!.homePageBackgrounds.isNotEmpty
          ? _viewedUser!.homePageBackgrounds.length
          : (_viewedUser!.homePageBackground.isNotEmpty ? 1 : 0);

      if (bgCount > 1 && _homePageBgPageController.hasClients) {
        int nextPage = _homePageBgPageController.page!.round() + 1;
        if (nextPage >= bgCount) {
          nextPage = 0;
        }
        _homePageBgPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<User?> _getUserData() async {
    try {
      if (widget.userID == 'official_team' || widget.userID.startsWith('official_channel_')) {
        return await UserApi.getUser(widget.userID);
      }
      final doc = await _firestore.collection('Users').doc(widget.userID).get();
      if (doc.exists) {
        return User.fromMap(doc.data()!);
      }
      return await UserApi.getUser(widget.userID);
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      return null;
    }
  }

  Future<void> _loadAllData() async {
    try {
      setState(() => isLoadingData = true);

      _viewedUser = await _getUserData();
      if (_viewedUser == null) {
        setState(() => isLoadingData = false);
        return;
      }

      _subscribeToUserDoc();
      final currentUser = AuthController.instance.currentUser;
      final u = _viewedUser!;

      // Record visitor log if it's not the viewed user viewing their own profile
      if (currentUser.userId != u.userId) {
        // Atomic increment of visitorCount in the user doc
        _firestore.collection('Users').doc(u.userId).update(
            {'visitorCount': FieldValue.increment(1)}).catchError((_) {});

        _firestore
            .collection('Users')
            .doc(u.userId)
            .collection('visitors')
            .doc(currentUser.userId)
            .set({
          'visitorId': currentUser.userId,
          'timestamp': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('Error saving visitor log: $e');
        });
      }

      followerCount = u.followers;
      followingCount = u.following;
      visitorCount = u.visitorCount;
      level = u.level.isNotEmpty ? u.level : '1';
      searchId = u.searchId.isNotEmpty ? u.searchId : '';
      bio = u.bio;
      userType = u.userType;
      agencyName = u.agencyName;
      currentDiamonds = u.diamonds;
      beans = u.beans;
      coins = 0;
      memberSince = u.createdAt;

      if (u.sendingLevel != null) {
        sendingLevel = u.sendingLevel!.level;
        sendingLevelName = u.sendingLevel!.levelName;
      }
      if (u.receivingLevel != null) {
        receivingLevel = u.receivingLevel!.level;
        receivingLevelName = u.receivingLevel!.levelName;
      }

      isFriend = await ContactApi.isContact(widget.userID);

      await _loadCustomizationDetails(u);
      _loadGiftSortPreference();
      _checkFollowStatus(currentUser.userId);
      _loadLevelImages();

      if (mounted) {
        setState(() => isLoadingData = false);
      }

      // Load heavy secondary data in background asynchronously
      _loadReceivedGifts();
      _loadStoreItems();
      _loadUserRooms();
      _loadRelationships();
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => isLoadingData = false);
      }
    }
  }

  Future<void> _checkFollowStatus(String currentUserId) async {
    try {
      final doc = await _firestore
          .collection('Users/$currentUserId/following')
          .doc(widget.userID)
          .get();
      isFollowing = doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
    }
  }

  Future<void> _loadReceivedGifts() async {
    try {
      _subscribeToGiftUpdates();
      _subscribeToActiveGiftUpdates();
    } catch (e) {
      debugPrint('❌ Error loading gifts: $e');
      receivedGifts = [];
    }
  }

  void _subscribeToGiftUpdates() {
    _giftArchiveSubscription = _firestore
        .collection('user_received_gifts')
        .where('receiverId', isEqualTo: widget.userID)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      _archiveGiftDocs =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      _rebuildGiftHistory();
    }, onError: (error) {
      debugPrint('❌ Gift archive listen error: $error');
    });
  }

  void _subscribeToActiveGiftUpdates() {
    _giftActiveSubscription = _firestore
        .collection('gift_transactions')
        .where('receiverId', isEqualTo: widget.userID)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      _activeGiftDocs =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      _rebuildGiftHistory();
    }, onError: (error) {
      debugPrint('Live gift transaction listen error: $error');
    });
  }

  StreamSubscription<QuerySnapshot>? _storeItemSubscription;

  void _subscribeToStoreItemUpdates() {
    _storeItemSubscription?.cancel();
    _storeItemSubscription = _firestore
        .collection('user_store_items')
        .where('userId', isEqualTo: widget.userID)
        .snapshots()
        .listen((snapshot) {
      _loadStoreItems();
    }, onError: (error) {
      debugPrint('Store items listen error: $error');
    });
  }

  void _subscribeToUserDoc() {
    _userSubscription = _firestore
        .collection('Users')
        .doc(widget.userID)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;
      final updatedUser = User.fromMap(snapshot.data()!);
      _applyUserData(updatedUser);
    }, onError: (error) {
      debugPrint('❌ User profile listen error: $error');
    });
  }

  void _applyUserData(User u) {
    final previousSending = sendingLevel;
    final previousReceiving = receivingLevel;

    if (mounted) {
      setState(() {
        _viewedUser = u;
        followerCount = u.followers;
        followingCount = u.following;
        visitorCount = u.visitorCount;
        level = u.level.isNotEmpty ? u.level : '1';
        searchId = u.searchId.isNotEmpty ? u.searchId : '';
        bio = u.bio;
        userType = u.userType;
        agencyName = u.agencyName;
        currentDiamonds = u.diamonds;
        beans = u.beans;
        coins = 0;
        memberSince = u.createdAt;
        if (u.sendingLevel != null) {
          sendingLevel = u.sendingLevel!.level;
          sendingLevelName = u.sendingLevel!.levelName;
        }
        if (u.receivingLevel != null) {
          receivingLevel = u.receivingLevel!.level;
          receivingLevelName = u.receivingLevel!.levelName;
        }
      });
    } else {
      _viewedUser = u;
      followerCount = u.followers;
      followingCount = u.following;
      level = u.level.isNotEmpty ? u.level : '1';
      searchId = u.searchId.isNotEmpty ? u.searchId : '';
      bio = u.bio;
      userType = u.userType;
      agencyName = u.agencyName;
      currentDiamonds = u.diamonds;
      beans = u.beans;
      coins = 0;
      memberSince = u.createdAt;
      if (u.sendingLevel != null) {
        sendingLevel = u.sendingLevel!.level;
        sendingLevelName = u.sendingLevel!.levelName;
      }
      if (u.receivingLevel != null) {
        receivingLevel = u.receivingLevel!.level;
        receivingLevelName = u.receivingLevel!.levelName;
      }
    }

    if (previousSending != sendingLevel ||
        previousReceiving != receivingLevel) {
      _loadLevelImages();
    }

    if (u.familyId != null && u.familyId!.isNotEmpty) {
      if (u.familyId!.length > 6 || int.tryParse(u.familyId!) == null) {
        // Auto-migrate this old family on the fly!
        FamilyService().migrateSingleFamily(u.familyId!);
      }

      // Always subscribe to the current familyId so the UI can display real-time data
      if (_familySubscription == null) {
        _subscribeToFamilyDoc(u.familyId!);
      } else if (_familyData != null &&
          _familyData!['familyId'] != u.familyId) {
        _familySubscription?.cancel();
        _subscribeToFamilyDoc(u.familyId!);
      }
    }

    _loadCustomizationDetails(u);
  }

  Future<void> _loadCustomizationDetails(User u) async {
    if (u.customization != null) {
      if (mounted) {
        setState(() {
          ownedBadges = u.customization!.ownedBadges;
        });
        _loadStoreItems();
      }
    }

    String? newFrameUrl;
    String? newNameplateUrl;
    String? newRpBgUrl;

    // Load frame
    if (u.customization?.selectedFrameId != null) {
      try {
        final frameDetails = await _storeService
            .getStoreItemDetails(u.customization!.selectedFrameId!);
        if (frameDetails != null) {
          newFrameUrl = frameDetails['fileUrl'] ??
              frameDetails['thumbnailUrl'] ??
              frameDetails['imageUrl'] ??
              frameDetails['image'];
        }
      } catch (e) {
        debugPrint('❌ Error loading frame: $e');
      }
    }

    // Load nameplate
    List<String> newNameplateUrls = [];
    List<String> nameplateIds = [];
    if (u.customization?.selectedNameplateIds.isNotEmpty == true) {
      nameplateIds = u.customization!.selectedNameplateIds;
    } else if (u.customization?.selectedNameplateId != null &&
        u.customization!.selectedNameplateId!.isNotEmpty) {
      nameplateIds = [u.customization!.selectedNameplateId!];
    }

    if (nameplateIds.isNotEmpty) {
      try {
        newNameplateUrls = await NameplateHelper.getNameplateUrls(nameplateIds);
        if (newNameplateUrls.isNotEmpty) {
          newNameplateUrl = newNameplateUrls.first;
        }
      } catch (e) {
        debugPrint('❌ Error loading nameplates: $e');
      }
    }

    // Load room profile background
    if (u.customization?.selectedRoomProfileBackgroundId != null) {
      try {
        final rpBgDetails = await _storeService.getStoreItemDetails(
            u.customization!.selectedRoomProfileBackgroundId!);
        if (rpBgDetails != null) {
          newRpBgUrl = rpBgDetails['fileUrl'] ??
              rpBgDetails['thumbnailUrl'] ??
              rpBgDetails['imageUrl'] ??
              rpBgDetails['image'];
        }
      } catch (e) {
        debugPrint('❌ Error loading room profile background: $e');
      }
    }

    String? newShortProfileThemeUrl;
    // Load short profile theme
    if (u.customization?.selectedShortProfileThemeId != null) {
      try {
        final themeDetails = await _storeService
            .getStoreItemDetails(u.customization!.selectedShortProfileThemeId!);
        if (themeDetails != null) {
          newShortProfileThemeUrl = themeDetails['fileUrl'] ??
              themeDetails['thumbnailUrl'] ??
              themeDetails['imageUrl'] ??
              themeDetails['image'];
        }
      } catch (e) {
        debugPrint('❌ Error loading short profile theme: $e');
      }
    }

    if (mounted) {
      setState(() {
        currentFrameUrl = newFrameUrl;
        currentNameplateUrl = newNameplateUrl;
        currentNameplateUrls = newNameplateUrls;
        _roomProfileBackgroundUrl = newRpBgUrl;
        _shortProfileThemeUrl = newShortProfileThemeUrl;
      });
    }
  }

  void _subscribeToFamilyDoc(String familyId) {
    _familySubscription = _firestore
        .collection('families')
        .doc(familyId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        if (mounted) {
          setState(() {
            _familyData = snapshot.data();
          });
        } else {
          _familyData = snapshot.data();
        }
      }
    }, onError: (error) {
      debugPrint('❌ Family listen error: $error');
    });
  }

  String _cleanGiftName(String name) {
    var cleaned = name.trim();
    cleaned =
        cleaned.replaceAll(RegExp(r'\s+x\s*\d+$', caseSensitive: false), '');
    cleaned =
        cleaned.replaceAll(RegExp(r'\s+\d+\s*x$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*\(\s*x?\s*\d+\s*x?\s*\)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*\(\s*combo\s*\)$', caseSensitive: false), '');
    return cleaned.trim();
  }

  String _getGiftGroupKey(Map<String, dynamic> data) {
    final rawName = _stringGiftValue(data, ['giftName', 'name']);
    final cleanName =
        _cleanGiftName(rawName.isEmpty ? 'Gift' : rawName).toLowerCase();
    final rawImageUrl = _stringGiftValue(
      data,
      ['giftPngUrl', 'giftImageUrl', 'pngUrl', 'imageUrl'],
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

  void _rebuildGiftHistory() {
    final Map<String, Map<String, dynamic>> giftMap = {};
    final mergedDocs = <String, Map<String, dynamic>>{};
    for (final data in _activeGiftDocs) {
      final id = data['id'] as String? ?? '${data['giftId']}-${data['timestamp']}';
      mergedDocs[id] = data;
    }
    for (final data in _archiveGiftDocs) {
      final id = data['id'] as String? ?? '${data['giftId']}-${data['timestamp']}';
      mergedDocs[id] = data;
    }
    final allDocs = mergedDocs.values;

    for (final data in allDocs) {
      final rawGiftName = _stringGiftValue(data, ['giftName', 'name']);
      final cleanName =
          _cleanGiftName(rawGiftName.isEmpty ? 'Gift' : rawGiftName);
      final giftImageUrl = _stringGiftValue(
        data,
        ['giftPngUrl', 'giftImageUrl', 'pngUrl', 'imageUrl'],
      );
      final credits = _intGiftValue(data['credits'] ?? data['diamondAmount']);
      final quantity =
          _intGiftValue(data['quantity'] ?? data['count'], fallback: 1);
      final key = _getGiftGroupKey(data);

      if (!giftMap.containsKey(key)) {
        giftMap[key] = {
          'giftName': cleanName,
          'giftImageUrl': giftImageUrl,
          'credits': credits,
          'count': 0,
          'totalValue': 0,
          'lastTimestamp': data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }

      giftMap[key]!['count'] = (giftMap[key]!['count'] as int) + quantity;
      giftMap[key]!['totalValue'] =
          (giftMap[key]!['totalValue'] as int) + (credits * quantity);

      final existingTimestamp = giftMap[key]!['lastTimestamp'] as DateTime;
      final newTimestamp = data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now();
      if (newTimestamp.isAfter(existingTimestamp)) {
        giftMap[key]!['lastTimestamp'] = newTimestamp;
      }
    }

    final updatedList = giftMap.values.toList();
    updatedList.sort((a, b) {
      final aDate = a['lastTimestamp'] is DateTime
          ? a['lastTimestamp'] as DateTime
          : DateTime.now();
      final bDate = b['lastTimestamp'] is DateTime
          ? b['lastTimestamp'] as DateTime
          : DateTime.now();

      if (_giftSortMode == 'quantity') {
        final countCompare =
            (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0);
        if (countCompare != 0) return countCompare;
        final unitCompare =
            (b['credits'] as int? ?? 0).compareTo(a['credits'] as int? ?? 0);
        if (unitCompare != 0) return unitCompare;
        final valueCompare = (b['totalValue'] as int? ?? 0)
            .compareTo(a['totalValue'] as int? ?? 0);
        if (valueCompare != 0) return valueCompare;
      } else {
        // 'price' mode: Sort by unit diamond price (credits) descending
        final unitCompare =
            (b['credits'] as int? ?? 0).compareTo(a['credits'] as int? ?? 0);
        if (unitCompare != 0) return unitCompare;
        final valueCompare = (b['totalValue'] as int? ?? 0)
            .compareTo(a['totalValue'] as int? ?? 0);
        if (valueCompare != 0) return valueCompare;
        final countCompare =
            (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0);
        if (countCompare != 0) return countCompare;
      }
      return bDate.compareTo(aDate);
    });

    final Map<String, Map<String, dynamic>> supporterMap = {};
    List<String> missingIds = [];

    for (final data in allDocs) {
      final senderId = data['senderId'] as String?;
      if (senderId == null || senderId.isEmpty) continue;

      final senderName = data['senderName'] as String? ?? 'User';

      String photoUrl = data['senderPhotoUrl'] ??
          data['senderAvatar'] ??
          'https://i.pravatar.cc/150?img=1';
      String searchId = '';

      if (_cachedUserProfiles.containsKey(senderId)) {
        if (_cachedUserProfiles[senderId]!['photoUrl']?.toString().isNotEmpty ==
            true) {
          photoUrl = _cachedUserProfiles[senderId]!['photoUrl'].toString();
        }
        searchId = _cachedUserProfiles[senderId]!['searchId']?.toString() ?? '';
      } else if (!missingIds.contains(senderId)) {
        missingIds.add(senderId);
      }

      final credits = _intGiftValue(data['credits'] ?? data['diamondAmount']);
      final quantity =
          _intGiftValue(data['quantity'] ?? data['count'], fallback: 1);
      final value = credits * quantity;

      if (!supporterMap.containsKey(senderId)) {
        supporterMap[senderId] = {
          'id': senderId,
          'searchId': searchId,
          'name': senderName,
          'photoUrl': photoUrl,
          'totalValue': 0,
        };
      }
      supporterMap[senderId]!['totalValue'] =
          (supporterMap[senderId]!['totalValue'] as int) + value;
    }

    final topSupporters = supporterMap.values.toList()
      ..sort(
          (a, b) => (b['totalValue'] as int).compareTo(a['totalValue'] as int));

    if (mounted) {
      setState(() {
        receivedGifts = updatedList;
        allSupporters = topSupporters;
        supporters = topSupporters.take(3).toList();
      });
    } else {
      receivedGifts = updatedList;
      allSupporters = topSupporters;
      supporters = topSupporters.take(3).toList();
    }

    if (missingIds.isNotEmpty) {
      _fetchMissingUserProfiles(missingIds);
    }
  }

  Future<void> _fetchMissingUserProfiles(List<String> userIds) async {
    bool updated = false;
    for (String uid in userIds) {
      if (_cachedUserProfiles.containsKey(uid)) continue;
      try {
        final doc = await _firestore.collection('Users').doc(uid).get();
        if (doc.exists) {
          _cachedUserProfiles[uid] = {
            'searchId': doc.data()?['searchId']?.toString() ?? '',
            'photoUrl': doc.data()?['photoUrl'] ??
                doc.data()?['imageUrl'] ??
                doc.data()?['profileImageUrl'] ??
                '',
          };
          updated = true;
        } else {
          _cachedUserProfiles[uid] = {'searchId': '', 'photoUrl': ''};
        }
      } catch (e) {
        // Ignore errors
      }
    }
    if (updated && mounted) {
      _rebuildGiftHistory(); // Rebuild UI with fetched details
    }
  }

  String _stringGiftValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  int _intGiftValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  @override
  void dispose() {
    _bgAnimationTimer?.cancel();
    _giftArchiveSubscription?.cancel();
    _giftActiveSubscription?.cancel();
    _userSubscription?.cancel();
    _userRoomsSubscription?.cancel();
    _familySubscription?.cancel();
    _storeItemSubscription?.cancel();
    _bgAnimationTimer?.cancel();
    _homePageBgTimer?.cancel();
    _homePageBgPageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRooms() async {
    try {
      _userRoomsSubscription = _firestore
          .collection('audio_rooms_v2')
          .where('joinedUserIds', arrayContains: widget.userID)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            final allRooms = snapshot.docs
                .map((doc) => AudioRoomV2.fromFirestore(doc))
                .toList();

            int getRoleScore(AudioRoomV2 room) {
              if (room.creatorId == widget.userID) return 0;
              if (room.settings.adminIds.contains(widget.userID)) return 1;
              return 2;
            }

            // Sort rooms: Owner (0) -> Admin (1) -> Member (2)
            allRooms.sort((a, b) {
              return getRoleScore(a).compareTo(getRoleScore(b));
            });

            userRooms = allRooms
                .map((r) => {
                      'room': r,
                      'id': r.id,
                      'imageUrl': r.imageUrl ?? r.creatorImageUrl,
                      'name': r.name,
                      'role': getRoleScore(r),
                      'participants':
                          r.participants.map((p) => p.toJson()).toList(),
                    })
                .toList();
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading user rooms: $e');
      if (mounted) {
        setState(() {
          userRooms = [];
        });
      }
    }
  }

  Future<void> _loadLevelImages() async {
    try {
      // Load sending level image
      final sendDoc = await _firestore
          .collection('level_configurations')
          .doc('sending_config')
          .get();
      if (sendDoc.exists) {
        final levels = sendDoc.data()?['levels'] as List<dynamic>?;
        if (levels != null) {
          for (final lvl in levels) {
            if (lvl['levelNumber']?.toString() == sendingLevel.toString()) {
              sendingLevelImageUrl = lvl['imageUrl'] as String?;
              break;
            }
          }
        }
      }

      // Load receiving level image
      final recDoc = await _firestore
          .collection('level_configurations')
          .doc('receiving_config')
          .get();
      if (recDoc.exists) {
        final levels = recDoc.data()?['levels'] as List<dynamic>?;
        if (levels != null) {
          for (final lvl in levels) {
            if (lvl['levelNumber']?.toString() == receivingLevel.toString()) {
              receivingLevelImageUrl = lvl['imageUrl'] as String?;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading level images: $e');
    }
  }

  bool _isStoreSubscribed = false;

  Future<void> _loadStoreItems() async {
    if (!_isStoreSubscribed) {
      _isStoreSubscribed = true;
      _subscribeToStoreItemUpdates();
    }

    try {
      final snapshot = await _firestore
          .collection('user_store_items')
          .where('userId', isEqualTo: widget.userID)
          .get();

      // 1. Fetch user ownedBadges from user profile / customization
      List<dynamic> userOwnedBadges = List<dynamic>.from(ownedBadges);
      if (userOwnedBadges.isEmpty && _viewedUser?.customization?.ownedBadges != null) {
        userOwnedBadges = List<dynamic>.from(_viewedUser!.customization!.ownedBadges);
      }
      try {
        final userDoc =
            await _firestore.collection('Users').doc(widget.userID).get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          final cust = uData['customization'] as Map<String, dynamic>?;
          final List<dynamic> dbBadges = cust?['ownedBadges'] ?? [];
          for (var b in dbBadges) {
            if (b is String && b.isNotEmpty && !userOwnedBadges.contains(b)) {
              userOwnedBadges.add(b);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching user ownedBadges: $e');
      }

      // 2. Load catalog badges from market_items and official_items
      final List<Map<String, dynamic>> catalog = [];

      try {
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
            'storeItemName': data['name'] ?? data['title'] ?? 'Badge',
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
            'starRating': data['starRating'] ??
                data['stars'] ??
                data['rating'] ??
                data['level'] ??
                1,
            'verifyLevel': data['verifyLevel'] ??
                data['verificationLevel'] ??
                data['officialLevel'] ??
                0,
          });
        }
      } catch (e) {
        debugPrint('Error loading market badges in roomprofile: $e');
      }

      try {
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
              'storeItemName': data['name'] ?? data['title'] ?? 'Badge',
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
              'starRating': data['starRating'] ??
                  data['stars'] ??
                  data['rating'] ??
                  data['level'] ??
                  1,
              'verifyLevel': data['verifyLevel'] ??
                  data['verificationLevel'] ??
                  data['officialLevel'] ??
                  0,
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading official badges in roomprofile: $e');
      }

      // Catalog admin ordering index map
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

      final Map<String, int> catalogAdminIndexMap = {};
      for (int i = 0; i < catalog.length; i++) {
        catalog[i]['adminCatalogIndex'] = i;
        final id = catalog[i]['id']?.toString() ?? '';
        final storeItemId = catalog[i]['storeItemId']?.toString() ?? '';
        final name = (catalog[i]['name'] ?? '').toString().toLowerCase().trim();
        final img = (catalog[i]['imageUrl'] ?? '').toString().trim();
        if (id.isNotEmpty) catalogAdminIndexMap[id] = i;
        if (storeItemId.isNotEmpty) catalogAdminIndexMap[storeItemId] = i;
        if (name.isNotEmpty) catalogAdminIndexMap[name] = i;
        if (img.isNotEmpty) catalogAdminIndexMap[img] = i;
      }

      final List<Map<String, dynamic>> allBadges = [];
      final List<Map<String, dynamic>> allDecorations = [];
      const decorationTypes = [
        'avatarFrame',
        'frame',
        'entryEffect',
        'backgroundTheme',
        'profileSkin',
        'nameplate',
        'svipTag',
        'roomTheme',
        'micRefill',
        'roomProfileBackground',
        'shortProfileTheme',
        'roomEntry',
      ];

      // Add badges from user customization.ownedBadges
      for (var badgeUrl in userOwnedBadges) {
        if (badgeUrl is String && badgeUrl.isNotEmpty) {
          allBadges.add({
            'id': badgeUrl,
            'storeItemId': badgeUrl,
            'storeItemName': 'VIP / Member Badge',
            'itemType': 'badge',
            'imageUrl': badgeUrl,
            'fileUrl': badgeUrl,
            'thumbnailUrl': badgeUrl,
            'badgeUrl': badgeUrl,
            'description': 'Exclusive member badge representing user status.',
            'subCategory': 'VIP',
            'starRating': 1,
            'verifyLevel': 1,
            'assignedAt': Timestamp.now(),
          });
        }
      }

      String extractMediaUrl(Map<String, dynamic> data) {
        for (final key in [
          'imageUrl',
          'thumbnailUrl',
          'fileUrl',
          'badgeUrl',
          'badgeMediaUrl',
          'iconUrl',
          'pngUrl',
          'image',
          'url',
          'mediaUrl',
          'assetUrl',
          'badge',
          'photoUrl',
        ]) {
          final val = data[key];
          if (val != null && val.toString().trim().isNotEmpty) {
            return val.toString().trim();
          }
        }
        return '';
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isActive'] != true) continue;

        final itemType = data['itemType'] as String? ?? '';
        final mediaUrl = extractMediaUrl(data);
        final entry = {
          'id': doc.id,
          'storeItemId': data['storeItemId'] ?? '',
          'storeItemName': data['storeItemName'] ?? data['name'] ?? 'Item',
          'itemType': itemType,
          'expiresAt': data['expiresAt'],
          'assignedAt': data['assignedAt'],
          'createdAt': data['createdAt'],
          'imageUrl': mediaUrl,
          'fileUrl': data['fileUrl'] ?? mediaUrl,
          'thumbnailUrl': data['thumbnailUrl'] ?? mediaUrl,
          'description': data['description'] ?? 'Exclusive item.',
          'subCategory': data['badgeSubCategory'] ??
              data['subCategory'] ??
              data['category'] ??
              '',
          'starRating': data['starRating'] ??
              data['stars'] ??
              data['rating'] ??
              data['level'] ??
              1,
          'verifyLevel': data['verifyLevel'] ??
              data['verificationLevel'] ??
              data['officialLevel'] ??
              0,
          'order': data['order'] ?? data['sortOrder'] ?? data['index'] ?? data['priority'],
        };

        if (itemType == 'badge') {
          allBadges.add(entry);
        } else if (decorationTypes.contains(itemType)) {
          allDecorations.add(entry);
        }
      }

      final dedupBadges = _deduplicateItems(allBadges);
      final dedupDecorations = _deduplicateItems(allDecorations);

      // Load details for all items in parallel
      final allItemsToLoad = [...dedupBadges, ...dedupDecorations];
      final detailFutures = allItemsToLoad.map((item) async {
        final storeItemId = (item['storeItemId'] ?? '').toString();
        if (storeItemId.isNotEmpty) {
          try {
            var details = await _storeService.getStoreItemDetails(storeItemId);
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
              final newImg = extractMediaUrl(details);
              if (newImg.isNotEmpty) {
                item['imageUrl'] = newImg;
              }
              if (details['name'] != null && details['name'].toString().isNotEmpty) {
                item['storeItemName'] = details['name'];
              }
              if (details['description'] != null &&
                  details['description'].toString().isNotEmpty) {
                item['description'] = details['description'];
              }
              if (details['badgeSubCategory'] != null ||
                  details['subCategory'] != null ||
                  details['category'] != null) {
                item['subCategory'] = details['badgeSubCategory'] ??
                    details['subCategory'] ??
                    details['category'];
              }
              if (details['starRating'] != null ||
                  details['stars'] != null ||
                  details['level'] != null) {
                item['starRating'] = details['starRating'] ??
                    details['stars'] ??
                    details['level'];
              }
              final detailVerify = details['verifyLevel'] ??
                  details['verificationLevel'] ??
                  details['officialLevel'];
              if (detailVerify != null) {
                item['verifyLevel'] = detailVerify;
              }
              if (details['order'] != null || details['sortOrder'] != null || details['index'] != null) {
                item['order'] = details['order'] ?? details['sortOrder'] ?? details['index'];
              }
              if (details['createdAt'] != null && item['createdAt'] == null) {
                item['createdAt'] = details['createdAt'];
              }
            } else if (storeItemId.startsWith('http')) {
              item['imageUrl'] = storeItemId;
            }
          } catch (_) {}
        }
      });

      await Future.wait(detailFutures);

      // Dedicated VIP/SVIP badge image resolution fallback
      for (final item in dedupBadges) {
        final currImg = (item['imageUrl'] ?? '').toString().trim();
        if (currImg.isEmpty) {
          final sName = (item['storeItemName'] ?? item['name'] ?? '').toString().toLowerCase();
          final sId = (item['storeItemId'] ?? item['id'] ?? '').toString().toLowerCase();
          if (sName.contains('vip') || sId.contains('vip')) {
            final isSvip = sName.contains('svip') || sId.contains('svip');
            final m = RegExp(r'(\d+)').firstMatch(sName.isNotEmpty ? sName : sId);
            final lvlNum = m != null ? m.group(1)! : '1';
            final col = isSvip ? 'svip_levels' : 'vip_levels';
            final candidateDocIds = isSvip
                ? ['svip$lvlNum', 'level_$lvlNum', 'svip_$lvlNum', lvlNum]
                : ['vip$lvlNum', 'level_$lvlNum', 'vip_$lvlNum', lvlNum];
            for (final dId in candidateDocIds) {
              try {
                final cfgDoc = await _firestore
                    .collection('config')
                    .doc(col)
                    .collection('levels')
                    .doc(dId)
                    .get();
                if (cfgDoc.exists && cfgDoc.data() != null) {
                  final resolved = extractMediaUrl(cfgDoc.data()!);
                  if (resolved.isNotEmpty) {
                    item['imageUrl'] = resolved;
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      int getBadgeTier(Map<String, dynamic> item) {
        final name = (item['name'] ?? item['storeItemName'] ?? item['title'] ?? '')
            .toString()
            .toLowerCase();
        final cat = (item['subCategory'] ?? item['category'] ?? item['badgeSubCategory'] ?? '')
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

        if (isOfficialOrVerif && !isVip) return 3; // Official & Verification
        if (isVip) return 2;                      // VIP & SVIP
        if (isOfficialOrVerif) return 3;
        return 1;                                 // Other / Non-verify
      }

      int getBadgeVerifyLevel(Map<String, dynamic> item) {
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

        final int tier = getBadgeTier(item);
        if (tier == 3) {
          return 2; // Official / Verification badges default to level 2
        } else if (tier == 2) {
          return 1; // VIP / SVIP badges default to level 1
        }

        return 0; // Non-verified badges have level 0
      }

      int getBadgeStar(dynamic rating, Map<String, dynamic> item) {
        int maxStars = 1;
        if (rating is num && rating > maxStars) {
          maxStars = rating.toInt();
        } else if (rating is String && rating.isNotEmpty) {
          final p = int.tryParse(rating);
          if (p != null && p > maxStars) {
            maxStars = p;
          } else {
            final m = RegExp(r'(\d+)').firstMatch(rating);
            if (m != null) {
              final numVal = int.tryParse(m.group(1)!);
              if (numVal != null && numVal > maxStars) maxStars = numVal;
            }
          }
        }

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

        final name = (item['storeItemName'] ?? item['name'] ?? '').toString();
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

        return maxStars;
      }

      int getAdminIndex(Map<String, dynamic> b) {
        if (catalogAdminIndexMap.isEmpty) return -1;
        final storeItemId = (b['storeItemId'] ?? '').toString();
        if (storeItemId.isNotEmpty && catalogAdminIndexMap.containsKey(storeItemId)) {
          return catalogAdminIndexMap[storeItemId]!;
        }
        final id = (b['id'] ?? '').toString();
        if (id.isNotEmpty && catalogAdminIndexMap.containsKey(id)) {
          return catalogAdminIndexMap[id]!;
        }
        final img = (b['imageUrl'] ?? '').toString().trim();
        if (img.isNotEmpty && catalogAdminIndexMap.containsKey(img)) {
          return catalogAdminIndexMap[img]!;
        }
        final name = (b['name'] ?? b['storeItemName'] ?? '').toString().toLowerCase().trim();
        if (name.isNotEmpty && catalogAdminIndexMap.containsKey(name)) {
          return catalogAdminIndexMap[name]!;
        }
        return -1;
      }

      // Combine all catalog badges with user owned badges
      final Map<String, Map<String, dynamic>> combinedBadgesMap = {};

      for (final catBadge in catalog) {
        final key = catBadge['storeItemId'] ?? catBadge['id'];
        combinedBadgesMap[key] = {
          ...catBadge,
          'isUnlocked': false,
        };
      }

      for (final owned in dedupBadges) {
        final key = owned['storeItemId'] ?? owned['id'];
        String? matchKey;
        if (combinedBadgesMap.containsKey(key)) {
          matchKey = key;
        } else {
          for (final entry in combinedBadgesMap.entries) {
            final catImg = (entry.value['imageUrl'] ?? '').toString().trim();
            final ownedImg = (owned['imageUrl'] ?? '').toString().trim();
            if (catImg.isNotEmpty && ownedImg.isNotEmpty && catImg == ownedImg) {
              matchKey = entry.key;
              break;
            }
            final catName = (entry.value['name'] ?? entry.value['storeItemName'] ?? '').toString().toLowerCase().trim();
            final ownedName = (owned['storeItemName'] ?? owned['name'] ?? '').toString().toLowerCase().trim();
            if (catName.isNotEmpty && ownedName.isNotEmpty && catName == ownedName) {
              matchKey = entry.key;
              break;
            }
          }
        }

        if (matchKey != null) {
          final target = combinedBadgesMap[matchKey]!;
          target['isUnlocked'] = true;
          target['expiresAt'] = owned['expiresAt'];
          target['assignedAt'] = owned['assignedAt'];
          if (owned['createdAt'] != null) target['createdAt'] = owned['createdAt'];
          if (owned['order'] != null) target['order'] = owned['order'];
          if (owned['starRating'] != null) target['starRating'] = getBadgeStar(owned['starRating'], owned);
          if (owned['verifyLevel'] != null) target['verifyLevel'] = owned['verifyLevel'];
          if (owned['description'] != null && owned['description'].toString().isNotEmpty) {
            target['description'] = owned['description'];
          }
          if (owned['subCategory'] != null && owned['subCategory'].toString().isNotEmpty) {
            target['subCategory'] = owned['subCategory'];
          }
          final ownedImg = (owned['imageUrl'] ?? '').toString().trim();
          if (ownedImg.isNotEmpty) {
            target['imageUrl'] = ownedImg;
          }
        } else {
          combinedBadgesMap[key] = {
            'id': key,
            'storeItemId': key,
            'name': owned['storeItemName'] ?? owned['name'] ?? 'Badge',
            'storeItemName': owned['storeItemName'] ?? owned['name'] ?? 'Badge',
            'imageUrl': owned['imageUrl'],
            'subCategory': owned['subCategory'] ?? '',
            'description': owned['description'] ?? 'Exclusive badge',
            'isUnlocked': true,
            'expiresAt': owned['expiresAt'],
            'assignedAt': owned['assignedAt'],
            'createdAt': owned['createdAt'],
            'order': owned['order'],
            'starRating': getBadgeStar(owned['starRating'], owned),
            'verifyLevel': owned['verifyLevel'] ?? getBadgeVerifyLevel(owned),
          };
        }
      }

      final allDisplayBadges = combinedBadgesMap.values
          .where((b) => b['isUnlocked'] == true)
          .toList();
      allDisplayBadges.sort((a, b) {
        // 1. Unlocked badges before locked badges
        final bool unlockedA = a['isUnlocked'] == true;
        final bool unlockedB = b['isUnlocked'] == true;
        if (unlockedA != unlockedB) {
          return unlockedA ? -1 : 1;
        }

        // 2. Primary: Verify Level ("স্টার এর চেয়ে ভেরিফাই লেবেল এর প্রাধান্য বেশি")
        final int vLevelA = getBadgeVerifyLevel(a);
        final int vLevelB = getBadgeVerifyLevel(b);
        if (vLevelA != vLevelB) {
          return vLevelB.compareTo(vLevelA);
        }

        // 3. Secondary: Star Level ("তার পরে স্টার, যত স্টার কমবে তত নিচে যাবে")
        final int ratingA = getBadgeStar(a['starRating'], a);
        final int ratingB = getBadgeStar(b['starRating'], b);
        if (ratingB != ratingA) {
          return ratingB.compareTo(ratingA);
        }

        // 4. Tier tie-breaker (Official > VIP > Non-verified)
        final int tierA = getBadgeTier(a);
        final int tierB = getBadgeTier(b);
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

        // 6. Admin Panel catalog order
        final int idxA = getAdminIndex(a);
        final int idxB = getAdminIndex(b);
        if (idxA != -1 && idxB != -1 && idxA != idxB) {
          return idxA.compareTo(idxB);
        }
        if (idxA != -1 && idxB == -1) return -1;
        if (idxA == -1 && idxB != -1) return 1;

        // 7. Timestamp (newer on top)
        final dateA = a['assignedAt'] ?? a['createdAt'];
        final dateB = b['assignedAt'] ?? b['createdAt'];
        if (dateA is Timestamp && dateB is Timestamp && dateA != dateB) {
          return dateB.compareTo(dateA);
        }

        // 8. Alphabetical fallback
        final String nameA = (a['storeItemName'] ?? a['name'] ?? '').toString();
        final String nameB = (b['storeItemName'] ?? b['name'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          badgeItems = allDisplayBadges;
          decorationItems = dedupDecorations;
        });
      } else {
        badgeItems = allDisplayBadges;
        decorationItems = dedupDecorations;
      }
    } catch (e) {
      debugPrint('❌ Error loading store items: $e');
      badgeItems = [];
      decorationItems = [];
    }
  }

  List<Map<String, dynamic>> _deduplicateItems(
      List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> dedup = {};
    for (var item in items) {
      final sId = (item['storeItemId'] ?? '').toString().trim();
      final img = (item['imageUrl'] ?? item['fileUrl'] ?? item['thumbnailUrl'] ?? '')
          .toString()
          .trim();
      final id = (item['id'] ?? '').toString().trim();
      // Use imageUrl as primary key if distinct, otherwise storeItemId
      final key = img.isNotEmpty ? img : (sId.isNotEmpty && sId != 'badge' ? sId : id);
      if (key.isNotEmpty) {
        if (!dedup.containsKey(key)) {
          dedup[key] = item;
        } else {
          final currentExp = item['expiresAt'] as Timestamp?;
          final existingExp = dedup[key]!['expiresAt'] as Timestamp?;
          if (currentExp == null && existingExp != null) {
            dedup[key] = item;
          } else if (currentExp != null && existingExp != null) {
            if (currentExp.toDate().isAfter(existingExp.toDate())) {
              dedup[key] = item;
            }
          }
        }
      } else {
        dedup[DateTime.now().microsecondsSinceEpoch.toString()] = item;
      }
    }
    final now = DateTime.now();
    return dedup.values.where((item) {
      final exp = item['expiresAt'] as Timestamp?;
      if (exp == null) return true;
      return exp.toDate().isAfter(now);
    }).toList();
  }

  Future<void> _toggleFollow() async {
    if (_viewedUser == null || _isFollowActionRunning) return;

    _isFollowActionRunning = true;
    try {
      final currentUser = AuthController.instance.currentUser;
      final currentUserRef =
          _firestore.collection('Users').doc(currentUser.userId);
      final otherUserRef =
          _firestore.collection('Users').doc(_viewedUser!.userId);
      final followingDoc =
          currentUserRef.collection('following').doc(_viewedUser!.userId);
      final followerDoc =
          otherUserRef.collection('followers').doc(currentUser.userId);

      if (!isFollowing) {
        final alreadyFollowing = (await followingDoc.get()).exists;
        if (!alreadyFollowing) {
          await Future.wait([
            followingDoc.set({
              'userId': _viewedUser!.userId,
              'createdAt': FieldValue.serverTimestamp()
            }),
            followerDoc.set({
              'userId': currentUser.userId,
              'createdAt': FieldValue.serverTimestamp()
            }),
            currentUserRef.set({'following': FieldValue.increment(1)},
                SetOptions(merge: true)),
            otherUserRef.set({'followers': FieldValue.increment(1)},
                SetOptions(merge: true)),
          ]);
          // Send follow notification & sound feedback
          try {
            OfficialTeamApi.sendFollowNotification(
              receiverId: _viewedUser!.userId,
              senderName: currentUser.fullname.isNotEmpty
                  ? currentUser.fullname
                  : 'User',
            );
            final player = AudioPlayer();
            await player.play(AssetSource('sounds/sent_msg.mp3'));
          } catch (soundErr) {
            debugPrint('Follow sound error: $soundErr');
          }
        }
        if (mounted) {
          setState(() {
            isFollowing = true;
            followerCount++;
          });
        } else {
          isFollowing = true;
          followerCount++;
        }
        _showSnack('You followed ${widget.userName}');
      } else {
        await Future.wait([
          followingDoc.delete(),
          followerDoc.delete(),
          currentUserRef.set(
              {'following': FieldValue.increment(-1)}, SetOptions(merge: true)),
          otherUserRef.set(
              {'followers': FieldValue.increment(-1)}, SetOptions(merge: true)),
        ]);
        if (mounted) {
          setState(() {
            isFollowing = false;
            followerCount = followerCount > 0 ? followerCount - 1 : 0;
          });
        } else {
          isFollowing = false;
          followerCount = followerCount > 0 ? followerCount - 1 : 0;
        }
        _showSnack('You unfollowed ${widget.userName}');
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
    } finally {
      _isFollowActionRunning = false;
    }
  }

  Future<void> _loadGiftSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('gift_sort_mode');
      if (savedMode != null && savedMode.isNotEmpty) {
        _giftSortMode = savedMode;
      }
      _rebuildGiftHistory();
    } catch (e) {
      debugPrint('❌ Error loading gift sort pref: $e');
    }
  }

  Future<void> _navigateToGiftWall() async {
    await Get.to(() => GiftWallPage(
          userId: widget.userID,
          userName: widget.userName,
          userImage: widget.userImage,
          gifts: receivedGifts,
        ));
    await _loadGiftSortPreference();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
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
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData && _viewedUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading profile...',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    final currentUser = AuthController.instance.currentUser;
    final isOwner = widget.userID == currentUser.userId;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: _buildWhiteCardHeader(),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.tealAccent,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: [
                          Tab(text: 'profile'.tr),
                          Tab(text: 'moment'.tr),
                        ],
                      ),

                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildProfileTab(),
                  _buildMomentTab(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: isOwner ? null : _buildBottomNavigationBar(),
        ),
        if (_roomProfileBackgroundUrl != null &&
            _roomProfileBackgroundUrl!.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: UniversalAssetWidget(
                key: ValueKey(_roomProfileBackgroundUrl),
                url: _roomProfileBackgroundUrl,
                fit: BoxFit.cover,
                isAlphaVideo: true,
                looping: true,
              ),
            ),
          ),
      ],
    );
  }

  // ===== New UI Methods =====

  Widget _buildSliverAppBar() {
    final name = (_viewedUser?.fullname.isNotEmpty == true
            ? _viewedUser!.fullname
            : widget.userName)
        .formattedUsername;
    final bool isOfficial = widget.userID == 'official_team' ||
        widget.userID.startsWith('official_channel_');

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1B2236),
      leading: const BackButton(color: Colors.white),
      actions: [
        if (AuthController.instance.currentUser.userId == widget.userID)
          IconButton(
            icon: const Icon(Icons.edit_document, color: Colors.white),
            onPressed: () {
              Get.to(() => const EditProfileScreen());
            },
          ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final top = constraints.biggest.height;
          final collapsedHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          double opacity = (collapsedHeight + 60 - top) / 60;
          if (opacity < 0.0) opacity = 0.0;
          if (opacity > 1.0) opacity = 1.0;

          return FlexibleSpaceBar(
            centerTitle: true,
            title: Opacity(
              opacity: opacity,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                Builder(
                  builder: (context) {
                    final List<String> bgUrls = [];
                    if (_viewedUser != null) {
                      if (_viewedUser!.homePageBackgrounds.isNotEmpty) {
                        bgUrls.addAll(_viewedUser!.homePageBackgrounds);
                      } else if (_viewedUser!.homePageBackground.isNotEmpty) {
                        bgUrls.add(_viewedUser!.homePageBackground);
                      }
                    }

                    if (bgUrls.isNotEmpty) {
                      return PageView.builder(
                        controller: _homePageBgPageController,
                        itemCount: bgUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              // Open full screen image viewer
                              Get.to(() => PostMediaViewer(
                                    mediaList: bgUrls
                                        .map((url) =>
                                            PostMedia(type: 'image', url: url))
                                        .toList(),
                                    initialIndex: index,
                                  ));
                            },
                            child: UniversalAssetWidget(
                              url: bgUrls[index],
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    }
                    return Container(color: const Color(0xFF1B2236));
                  },
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                // Profile Info (Avatar, Name, ID)
                Positioned(
                  left: 20,
                  bottom: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CachedCircleAvatar(
                        imageUrl: (_viewedUser?.photoUrl.isNotEmpty == true)
                            ? _viewedUser!.photoUrl
                            : (widget.userImage.isNotEmpty
                                ? widget.userImage
                                : (isOfficial ? 'assets/images/app_logo.png' : "https://i.pravatar.cc/150?img=9")),
                        userId: widget.userID,
                        radius: 40,
                        frameUrl: currentFrameUrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _viewedUser != null
                              ? AnimatedSvipName.fromUser(
                                  user: _viewedUser!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : AnimatedSvipName.fromUserId(
                                  userId: widget.userID,
                                  defaultName: widget.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          if (_viewedUser?.isVerified == true || isOfficial) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ],
                          const SizedBox(width: 8),
                          if (!isOfficial)
                            Builder(builder: (context) {
                              final isBoy =
                                  _viewedUser?.gender.toLowerCase() == 'boy' ||
                                      _viewedUser?.gender.toLowerCase() == 'male';
                              final color =
                                  isBoy ? Colors.blueAccent : Colors.pinkAccent;
                              final icon = isBoy ? Icons.male : Icons.female;

                              int age = 18; // default
                              if (_viewedUser?.birthday != null &&
                                  _viewedUser!.birthday.isNotEmpty) {
                                try {
                                  final parts = _viewedUser!.birthday.split('-');
                                  if (parts.length >= 3) {
                                    final year = int.tryParse(parts[0]);
                                    if (year != null) {
                                      age = DateTime.now().year - year;
                                    }
                                  }
                                } catch (_) {}
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, color: Colors.white, size: 12),
                                    const SizedBox(width: 2),
                                    Text('$age',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10)),
                                  ],
                                ),
                              );
                            })
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Official',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final idToCopy = searchId.isNotEmpty
                                  ? searchId
                                  : widget.userID;
                              await Clipboard.setData(
                                  ClipboardData(text: idToCopy));
                              if (!context.mounted) return;
                              final overlay = Overlay.of(context);
                              final entry = OverlayEntry(
                                builder: (ctx) => Positioned(
                                  top:
                                      MediaQuery.of(context).size.height * 0.42,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle,
                                                color: Colors.greenAccent,
                                                size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'ID $idToCopy copied!',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              overlay.insert(entry);
                              await Future.delayed(const Duration(seconds: 2));
                              entry.remove();
                            },
                            child: UserIdBadgeWidget(
                              searchId: searchId.isNotEmpty
                                  ? searchId
                                  : widget.userID,
                              showCopyIcon: true,
                              copyIconColor: Colors.white70,
                            ),
                          ),
                          Text(
                            ' | ${_viewedUser?.country.isNotEmpty == true ? _viewedUser!.country : "Unknown"}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          if (sendingLevelImageUrl != null &&
                              sendingLevelImageUrl!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Image.network(
                                sendingLevelImageUrl!,
                                height: 18,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(),
                              ),
                            ),
                          if (receivingLevelImageUrl != null &&
                              receivingLevelImageUrl!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Image.network(
                                receivingLevelImageUrl!,
                                height: 18,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(),
                              ),
                            ),
                        ],
                      ),
                      if (currentNameplateUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...() {
                          final List<List<String>> chunked = [];
                          for (int i = 0;
                              i < currentNameplateUrls.length;
                              i += 5) {
                            chunked.add(currentNameplateUrls.sublist(i,
                                (i + 5).clamp(0, currentNameplateUrls.length)));
                          }
                          return chunked.map((rowItems) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rowItems
                                      .map((url) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: Image.network(
                                              url,
                                              height: 22,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const SizedBox(),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ));
                        }(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFindMeButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('audio_rooms_v2')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        AudioRoomV2? activeRoom;
        for (var doc in snapshot.data!.docs) {
          try {
            final r = AudioRoomV2.fromFirestore(doc);
            if (r.isActive && r.isParticipant(widget.userID)) {
              activeRoom = r;
              break;
            }
          } catch (_) {}
        }

        if (activeRoom == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            AudioRoomsV2Integration.navigateToRoom(activeRoom!, context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2A85), Color(0xFFFF7A45)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2A85).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                _FindMeEqualizer(),
                SizedBox(width: 6),
                Text(
                  'Find Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhiteCardHeader() {
    return Container(
      transform: Matrix4.translationValues(0, -20, 0),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          if (_shortProfileThemeUrl != null &&
              _shortProfileThemeUrl!.isNotEmpty)
            Positioned.fill(
              child: UniversalAssetWidget(
                url: _shortProfileThemeUrl,
                fit: BoxFit.cover,
                looping: false,
                isAlphaVideo: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildModernStatItem(
                                  'Follow'.tr, followingCount.toString()),
                              const SizedBox(width: 18),
                              _buildModernStatItem(
                                  'Fans'.tr, followerCount.toString()),
                              const SizedBox(width: 18),
                              _buildModernStatItem(
                                  'Visitor'.tr, visitorCount.toString()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (bio.isEmpty || bio == 'default_bio_empty'.tr)
                                ? ((widget.userID == 'official_team' || widget.userID.startsWith('official_channel_'))
                                    ? UserApi.officialDefaultBio
                                    : 'default_bio_empty'.tr)
                                : bio,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!(widget.userID == 'official_team' || widget.userID.startsWith('official_channel_'))) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  memberSince != null
                                      ? '${'joined_app'.tr} : ${_formatDate(memberSince!)}'
                                      : '${'joined_app'.tr} : 0 ${'days'.tr}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildFindMeButton(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildModernBadge('ring_collection'.tr, '0', Colors.pinkAccent,
                        Icons.favorite_border),
                    const SizedBox(width: 12),
                    _buildModernBadge('game_level'.tr, '20', Colors.blueAccent,
                        Icons.emoji_events),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem(String label, String count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(count,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildModernBadge(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.6), color]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Family'.tr, trailing: '${'family_center'.tr} >'),
        _buildFamilyCardPlaceholder(),
        const SizedBox(height: 20),
        _buildSectionHeader('Intimacy'.tr,
            trailing: '${relationshipsList.length} >', onTapTrailing: () {
          Get.to(() => IntimacyListPage(
                userID: widget.userID,
                userName: widget.userName,
                userImage: widget.userImage,
                relationships: relationshipsList,
              ))?.then((_) => _loadRelationships());
        }),
        _buildRelationshipsList(),
        const SizedBox(height: 20),
        _buildSectionHeader('Supporter'.tr,
            count: '${allSupporters.length}', // total unique supporters
            trailing: '>', onTapTrailing: () {
          Get.to(() => SupportersPage(
                userID: widget.userID,
                userName: widget.userName,
                supporters: allSupporters,
              ));
        }),
        _buildSupporterPlaceholder(),
        const SizedBox(height: 20),
        _buildSectionHeader(
          'All Joined Room'.tr,
          count: '${userRooms.length}',
          trailing: '${userRooms.length} >',
          icon: Icons.shield,
        ),
        _buildVoiceClubRoomsList(),
        const SizedBox(height: 20),
        _buildSectionHeader('Medal'.tr,
            count: '${badgeItems.length}',
            trailing: '${'badge_wall'.tr} >', onTapTrailing: () {
          Get.to(() => BadgeWallPage(
              userID: widget.userID,
              userName: widget.userName,
              badgeItems: badgeItems));
        }),
        _buildBadgeList(),
        const SizedBox(height: 20),
        _buildSectionHeader('Decoration'.tr,
            count: '${decorationItems.length}',
            trailing: '${'decoration_wall'.tr} >', onTapTrailing: () {
          Get.to(() => DecorationWallPage(
              userID: widget.userID,
              userName: widget.userName,
              decorationItems: decorationItems));
        }),
        _buildDecorationList(),
        const SizedBox(height: 20),
        _buildSectionHeader('Gift'.tr,
            count: '${receivedGifts.length}',
            trailing: '${'gift_wall'.tr} >', onTapTrailing: () async {
          await Get.to(() => GiftWallPage(
              userId: widget.userID,
              userName: widget.userName,
              userImage: widget.userImage,
              gifts: receivedGifts));
          await _loadGiftSortPreference();
        }),
        _buildGiftList(),
        const SizedBox(height: 40), // Bottom padding
      ],
    );
  }

  Widget _buildMomentTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('news_feed_posts')
          .where('userId', isEqualTo: widget.userID)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading moments: ${snapshot.error}',
                  style: const TextStyle(color: Colors.grey)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text('No moments yet',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          );
        }

        var posts = snapshot.data!.docs
            .map((doc) => NewsFeedPost.fromFirestore(doc))
            .toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildSimplePostCard(post);
          },
        );
      },
    );
  }

  Widget _buildSimplePostCard(NewsFeedPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CachedCircleAvatar(
                imageUrl: post.userAvatar ?? '',
                userId: post.userId,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSvipName.fromUserId(
                      userId: post.userId,
                      defaultName: post.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black),
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (post.userId == AuthController.instance.currentUser.userId)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () => _showPostOptions(post),
                ),
            ],
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichTextViewer(
                text: post.content,
                style: const TextStyle(fontSize: 14.5, color: Colors.black87),
              ),
            ),
          if (post.media.isNotEmpty)
            Builder(builder: (context) {
              final String mediaUrl = post.media.first.type == 'video'
                  ? (post.media.first.thumbnailUrl ?? '')
                  : post.media.first.url;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () =>
                      Get.to(() => PostMediaViewer(mediaList: post.media)),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: mediaUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(mediaUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: post.media.first.type == 'video'
                        ? const Center(
                            child: Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 48),
                          )
                        : null,
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.thumb_up_alt_outlined,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${post.likeCount}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(width: 16),
              Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${post.commentCount}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final bool isOfficial = widget.userID == 'official_team' ||
        widget.userID.startsWith('official_channel_');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: isOfficial
            ? SizedBox(
                width: double.infinity,
                child: _buildBottomActionButton(
                  'Official Channel Messages',
                  Icons.campaign_rounded,
                  Colors.blueAccent,
                  () async {
                    var user = await _getUserData();
                    if (user != null) {
                      RoutesHelper.toMessages(user: user).then((_) {
                        Get.back();
                      });
                    }
                  },
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildBottomActionButton(
                        isFriend ? 'Message' : 'Add Friend',
                        isFriend ? Icons.message : Icons.person_add_alt_1,
                        Colors.greenAccent.shade700, () async {
                      var user = await _getUserData();
                      if (user != null) {
                        if (isFriend) {
                          RoutesHelper.toMessages(user: user).then((_) {
                            Get.back();
                          });
                        } else {
                          await ContactApi.sendFriendRequest(
                              targetUserId: user.userId, showMsg: true);
                        }
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBottomActionButton(
                        isFollowing ? 'Following' : 'Follow',
                        Icons.favorite,
                        Colors.greenAccent.shade700,
                        _toggleFollow),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBottomActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title,
      {String? count,
      String? trailing,
      VoidCallback? onTapTrailing,
      IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('($count)',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ],
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: Colors.grey.shade400),
          ],
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTapTrailing,
              child: Text(trailing,
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    );
  }

  Widget _buildFamilyCardPlaceholder() {
    if (_viewedUser?.familyName == null || _viewedUser!.familyName!.isEmpty) {
      return _buildEmptyPlaceholder('No family yet');
    }

    final currentUser = AuthController.instance.currentUser;
    final bool isMember = currentUser.familyId == _viewedUser!.familyId;

    // Fallback data if real-time not loaded yet
    final String logoUrl = _familyData?['logoUrl'] ?? '';
    final String familyName =
        _familyData?['familyName'] ?? _viewedUser!.familyName ?? '';
    final String familyIdStr =
        _familyData?['familyId'] ?? _viewedUser!.familyId ?? '';
    final List memberIds = _familyData?['memberIds'] ?? [];
    final int memberCount = memberIds.isNotEmpty ? memberIds.length : 1;
    final int maxLimit = 1400; // Hardcoded or from DB if available

    return GestureDetector(
      onTap: () {
        Get.to(() => FamilyScreen(currentUser: currentUser));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Gold frame avatar
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(logoUrl.isNotEmpty
                    ? logoUrl
                    : 'https://i.pravatar.cc/150?img=1'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          familyName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield,
                                color: Colors.orange, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _viewedUser!.fullname.length > 8
                                  ? '${_viewedUser!.fullname.substring(0, 8)}..'
                                  : _viewedUser!.fullname,
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // ID badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ID',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        familyIdStr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Text('|',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Icon(Icons.people, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text('$memberCount/$maxLimit',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
            if (!isMember)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                      color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupporterPlaceholder() {
    if (supporters.isEmpty) {
      return _buildEmptyPlaceholder('No supporters yet');
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ...List.generate(supporters.length, (index) {
          final supporter = supporters[index];
          final url = supporter['photoUrl'] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildTinyAvatar(url, index + 1),
          );
        }),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildTinyAvatar(String url, int rank) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(url),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: Text('$rank',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceClubRoomsList() {
    if (userRooms.isEmpty) {
      return const SizedBox();
    }

    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: userRooms.length,
        itemBuilder: (context, index) {
          final room = userRooms[index];
          final String imageUrl =
              room['imageUrl'] ?? room['creatorImageUrl'] ?? '';
          final String name = room['name'] ?? 'Room';
          // Count participants from array length if exists
          final List participants = room['participants'] ?? [];
          final int participantCount = participants.length;
          final int role = room['role'] ?? 2; // 0=owner, 1=admin, 2=member

          final AudioRoomV2? roomObj = room['room'] as AudioRoomV2?;

          return GestureDetector(
            onTap: () {
              if (roomObj != null) {
                AudioRoomsV2Integration.navigateToRoom(roomObj, context);
              }
            },
            child: Container(
              width: 85,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.blue.withValues(alpha: 0.1),
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // User icon bottom left
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              role == 0
                                  ? Icons.workspace_premium
                                  : (role == 1 ? Icons.shield : Icons.person),
                              size: 12,
                              color: role == 0
                                  ? Colors.orangeAccent
                                  : (role == 1 ? Colors.blueAccent : Colors.grey),
                            ),
                          ),
                        ),
                        // Count pill bottom right
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$participantCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyIntimacyCard(
      {required String title,
      required bool isPink,
      required VoidCallback onTap}) {
    final themeColor =
        isPink ? const Color(0xFFF48FB1) : const Color(0xFF90CAF9);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: themeColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveIntimacyCard({
    required String title,
    required String name,
    required String photoUrl,
    required int level,
    required bool showOrnament,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Get.to(() => IntimacyListPage(
                  userID: widget.userID,
                  userName: widget.userName,
                  userImage: widget.userImage,
                  relationships: relationshipsList,
                ))?.then((_) => _loadRelationships());
          },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: photoUrl.startsWith('http')
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.person,
                                    color: Colors.grey, size: 24),
                              ),
                            )
                          : Image.asset(
                              photoUrl.isNotEmpty
                                  ? photoUrl
                                  : 'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.person,
                                    color: Colors.grey, size: 24),
                              ),
                            ),
                    ),
                  ),
                ),
                if (showOrnament)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: RelationshipBadgeWidget(
                        level: level,
                        relationshipType: title,
                        size: 14,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF90CAF9), Color(0xFF42A5F5)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 0.75),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            size: 7,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 1),
                          Text(
                            'Lv.$level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipsList() {
    Map<String, dynamic>? coupleRel;
    for (var r in relationshipsList) {
      if (r['relationshipType']?.toString().toLowerCase() == 'couple') {
        coupleRel = r;
        break;
      }
    }

    final friendRels = relationshipsList
        .where(
            (r) => r['relationshipType']?.toString().toLowerCase() != 'couple')
        .toList();

    List<Widget> cards = [];

    // If no relationships exist at all, show exactly 1 empty Couple card and 1 empty Friend card
    if (relationshipsList.isEmpty) {
      cards.add(_buildEmptyIntimacyCard(
        title: 'Couple',
        isPink: true,
        onTap: () => _sendRelationshipInvitation('couple'),
      ));
      cards.add(_buildEmptyIntimacyCard(
        title: 'Friend',
        isPink: false,
        onTap: () => _sendRelationshipInvitation('friend'),
      ));
    } else {
      // 1. Couple slot (active or empty)
      if (coupleRel != null) {
        cards.add(_buildActiveIntimacyCard(
          title: 'Couple',
          name: coupleRel['otherUserFullname'] ?? 'Couple',
          photoUrl: coupleRel['otherUserPhotoUrl'] ?? '',
          level: coupleRel['currentLevel'] ?? 1,
          showOrnament: true,
        ));
      } else {
        cards.add(_buildEmptyIntimacyCard(
          title: 'Couple',
          isPink: true,
          onTap: () => _sendRelationshipInvitation('couple'),
        ));
      }

      // 2. Active Friend slots
      for (int i = 0; i < friendRels.length; i++) {
        final rel = friendRels[i];
        cards.add(_buildActiveIntimacyCard(
          title: 'Friend',
          name: rel['otherUserFullname'] ?? 'Friend',
          photoUrl: rel['otherUserPhotoUrl'] ?? '',
          level: rel['currentLevel'] ?? 1,
          showOrnament: i == 0,
        ));
      }

      // 3. Exactly 1 empty Friend slot at the end (if not at maximum capacity, e.g. max 5 friends)
      if (friendRels.length < 5) {
        cards.add(_buildEmptyIntimacyCard(
          title: 'Friend',
          isPink: false,
          onTap: () => _sendRelationshipInvitation('friend'),
        ));
      }
    }

    return Container(
      height: 110,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: cards[index],
          );
        },
      ),
    );
  }

  Future<void> _loadRelationships() async {
    if (!mounted) return;
    setState(() {
      isLoadingRelationships = true;
    });

    try {
      final userRef = _firestore.collection('Users').doc(widget.userID);

      final q1 = await _firestore
          .collection('relationships')
          .where('user1Ref', isEqualTo: userRef)
          .where('status', isEqualTo: 'accepted')
          .get();

      final q2 = await _firestore
          .collection('relationships')
          .where('user2Ref', isEqualTo: userRef)
          .where('status', isEqualTo: 'accepted')
          .get();

      final List<Map<String, dynamic>> loadedList = [];
      final Set<String> loadedIds = {};

      for (var doc in [...q1.docs, ...q2.docs]) {
        if (loadedIds.contains(doc.id)) continue;
        loadedIds.add(doc.id);

        final data = doc.data();
        data['id'] = doc.id;

        final u1Ref = data['user1Ref'];
        final u2Ref = data['user2Ref'];

        String? otherUserId;
        if (u1Ref is DocumentReference) {
          otherUserId = (u1Ref.id == widget.userID)
              ? (u2Ref is DocumentReference ? u2Ref.id : u2Ref?.toString())
              : u1Ref.id;
        } else if (u1Ref is String) {
          otherUserId = (u1Ref == widget.userID) ? u2Ref?.toString() : u1Ref;
        }

        if (otherUserId != null) {
          data['otherUserId'] = otherUserId;

          final otherUserDoc =
              await _firestore.collection('Users').doc(otherUserId).get();
          if (otherUserDoc.exists) {
            final otherUserData = otherUserDoc.data();
            data['otherUserFullname'] = otherUserData?['fullname'] ??
                otherUserData?['displayName'] ??
                'User';
            data['otherUserPhotoUrl'] = otherUserData?['photoUrl'] ?? '';
            data['otherUserSearchId'] = otherUserData?['searchId'] ?? '';
          } else {
            data['otherUserFullname'] = 'User';
            data['otherUserPhotoUrl'] = '';
            data['otherUserSearchId'] = '';
          }
        }

        loadedList.add(data);
      }

      if (mounted) {
        setState(() {
          relationshipsList = loadedList;
          isLoadingRelationships = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading relationships: $e');
      if (mounted) {
        setState(() {
          isLoadingRelationships = false;
        });
      }
    }
  }

  void _sendRelationshipInvitation(String type) async {
    final currentUser = AuthController.instance.currentUser;
    if (widget.userID == currentUser.userId ||
        (_viewedUser != null && _viewedUser!.userId == currentUser.userId)) {
      _showSnack('আপনি নিজেকে ফ্রেন্ডশিপ বা কাপল ইনভিটেশন পাঠাতে পারবেন না।');
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Invite ${widget.userName}'),
        content: Text(
            'Would you like to send a $type relationship invitation to ${widget.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'couple'
                  ? const Color(0xFFF48FB1)
                  : const Color(0xFF42A5F5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(context).pop();

              // Play sound feedback non-blockingly
              try {
                AudioPlayer()
                    .play(AssetSource('sounds/sent_msg.mp3'))
                    .catchError((_) {});
              } catch (_) {}

              _showSnack('Sending invitation to ${widget.userName}...');

              try {
                // Check if an invitation already exists to prevent duplicate
                final existing = await _firestore
                    .collection('relationshipInvitations')
                    .where('senderRef',
                        isEqualTo: _firestore
                            .collection('Users')
                            .doc(currentUser.userId))
                    .where('receiverRef',
                        isEqualTo:
                            _firestore.collection('Users').doc(widget.userID))
                    .where('relationshipType', isEqualTo: type)
                    .where('status', isEqualTo: 'pending')
                    .get();

                if (existing.docs.isNotEmpty) {
                  _showSnack('An invitation of this type is already pending.');
                  return;
                }

                // Create relationship invitation document
                final invitationDoc =
                    await _firestore.collection('relationshipInvitations').add({
                  'senderRef':
                      _firestore.collection('Users').doc(currentUser.userId),
                  'receiverRef':
                      _firestore.collection('Users').doc(widget.userID),
                  'relationshipType': type,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'expiresAt': Timestamp.fromDate(
                      DateTime.now().add(const Duration(hours: 48))),
                });

                final receiverUser = _viewedUser ??
                    User(
                      userId: widget.userID,
                      fullname: widget.userName,
                      photoUrl: widget.userImage,
                    );

                final msgId = AppHelper.generateID;
                final message = Message(
                  msgId: msgId,
                  senderId: currentUser.userId,
                  type: MessageType.relationshipInvitation,
                  textMsg: '❤️ $type request sent',
                  invitationId: invitationDoc.id,
                  invitationAgencyName: currentUser.fullname.isNotEmpty
                      ? currentUser.fullname
                      : 'User',
                  invitationAgencyId: type,
                  sentAt: DateTime.now(),
                );

                // Run message sending and official notification in background non-blockingly
                MessageApi.sendMessage(
                  message: message,
                  receiver: receiverUser,
                ).catchError((err) {
                  debugPrint('Error sending 1-on-1 invitation message: $err');
                });

                OfficialTeamApi.sendRelationshipInvitationMessage(
                  receiverId: widget.userID,
                  receiverDeviceToken: _viewedUser?.deviceToken ?? '',
                  senderName: currentUser.fullname.isNotEmpty
                      ? currentUser.fullname
                      : 'User',
                  invitationId: invitationDoc.id,
                  relationshipType: type,
                ).catchError((err) {
                  debugPrint(
                      'Error sending official invitation notification: $err');
                });

                _showSnack('Invitation sent successfully!');
              } catch (e) {
                debugPrint('Error sending invitation: $e');
                _showSnack('Failed to send invitation: $e');
              }
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _buildGiftList() {
    if (receivedGifts.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text('No gifts received yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ),
      );
    }

    // Take top 15 gifts
    final topGifts = receivedGifts.take(15).toList();

    return Column(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            childAspectRatio: 0.65, // Adjust to fit image and text properly
          ),
          itemCount: topGifts.length,
          itemBuilder: (context, index) {
            final gift = topGifts[index];
            final imageUrl = gift['giftImageUrl'] as String? ?? '';
            final count = gift['count'] as int? ?? 1;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.card_giftcard,
                                        color: Colors.grey, size: 24),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.card_giftcard,
                                    color: Colors.grey, size: 24),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '×$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        if (receivedGifts.length > 15)
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _navigateToGiftWall,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final isOwner = widget.userID == AuthController.instance.currentUser.userId;
    final isUnlocked = badge['isUnlocked'] == true;
    BadgeDetailDialog.show(
      context,
      badge: badge,
      isOwner: isOwner,
      isUnlocked: isUnlocked,
    );
  }

  Widget _buildBadgeList() {
    if (badgeItems.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('No medals yet',
              style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final topBadges = badgeItems.take(8).toList();

    return Column(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75, // Adjust to fit image and text
          ),
          itemCount: topBadges.length,
          itemBuilder: (context, index) {
            final badge = topBadges[index];
            final imageUrl = badge['imageUrl'] as String?;
            final name = badge['storeItemName'] as String? ?? 'Badge';

            return GestureDetector(
              onTap: () => _showBadgeDetails(badge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: UniversalAssetWidget(
                                    url: imageUrl,
                                    fit: BoxFit.contain,
                                    looping: true,
                                  ),
                                )
                              : const Icon(Icons.shield_outlined,
                                  color: Colors.purple, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(name,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          },
        ),
        if (badgeItems.length > 8)
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.to(() => BadgeWallPage(
                          userID: widget.userID,
                          userName: widget.userName,
                          badgeItems: badgeItems,
                        ));
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDecorationList() {
    if (decorationItems.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('No decorations yet',
              style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final int displayCount =
        decorationItems.length > 5 ? 5 : decorationItems.length;
    final bool hasMore = decorationItems.length > 5;
    final int itemCount = displayCount + (hasMore ? 1 : 0);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == displayCount && hasMore) {
            // Render the (>) Navigation Item Card
            return GestureDetector(
              onTap: () {
                Get.to(() => DecorationWallPage(
                      userID: widget.userID,
                      userName: widget.userName,
                      decorationItems: decorationItems,
                    ));
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.blue.shade300.withValues(alpha: 0.5)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'More',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }

          final decoration = decorationItems[index];
          final imageUrl = decoration['imageUrl'] as String?;
          final name = decoration['storeItemName'] as String? ?? 'Decoration';

          return GestureDetector(
            onTap: () {
              // Optionally show decoration details
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    height: 55,
                    width: 55,
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14)),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.diamond_outlined,
                                    color: Colors.blue,
                                    size: 28)),
                          )
                        : const Icon(Icons.diamond_outlined,
                            color: Colors.blue, size: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(name,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPostOptions(NewsFeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Caption'),
                onTap: () {
                  Navigator.pop(context);
                  _editPostCaption(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost(post.id);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text(
              'Are you sure you want to permanently delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await NewsFeedService.deletePost(postId);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _editPostCaption(NewsFeedPost post) {
    final textController = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Caption'),
          content: TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter new caption...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (textController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance
                      .collection('news_feed_posts')
                      .doc(post.id)
                      .update({
                    'content': textController.text.trim(),
                    'updatedAt': Timestamp.now(),
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _FindMeEqualizer extends StatefulWidget {
  const _FindMeEqualizer();

  @override
  State<_FindMeEqualizer> createState() => _FindMeEqualizerState();
}

class _FindMeEqualizerState extends State<_FindMeEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final h1 = 5.0 + 8.0 * val;
        final h2 = 13.0 - 8.0 * val;
        final h3 = 6.0 + 7.0 * ((val + 0.5) % 1.0);

        return SizedBox(
          height: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1),
              const SizedBox(width: 2.5),
              _buildBar(h2),
              const SizedBox(width: 2.5),
              _buildBar(h3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 3.2,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}