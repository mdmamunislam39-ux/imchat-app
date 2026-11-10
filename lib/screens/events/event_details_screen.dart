import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import '../../models/event_model.dart';
import '../../models/audio_room_v2.dart';
import '../../theme/app_theme.dart';
import '../../services/event_service.dart';
import '../../services/store_service.dart';
import '../../services/wallet_service.dart';
import '../../components/universal_asset_widget.dart';
import '../../controllers/follow_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/follow_button.dart';
import '../audio_rooms_v2/audio_room_screen.dart';
import '../audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import '../audio_rooms_v2/repository/audio_rooms_repository.dart';
import '../room/roomprofile_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel? event;
  final String? eventId;

  const EventDetailsScreen({super.key, this.event, this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Timer? _timer;
  EventModel? _event;
  bool _isLoading = false;
  final FollowController _followController = FollowController();
  final Set<String> _loadedFollowUserIds = {};

  final Map<int, int> _selectedBlockTabIndices = {};

  // Metrics status tracking
  bool _isLiked = false;
  StreamSubscription<DocumentSnapshot>? _eventSubscription;
  StreamSubscription<DocumentSnapshot>? _likeSubscription;
  StreamSubscription<QuerySnapshot>? _registrationsSubscription;
  StreamSubscription<QuerySnapshot>? _claimsSubscription;
  StreamSubscription<DocumentSnapshot>? _scoreSubscription;
  Set<String> _registeredUserIds = {};
  Set<String> _userClaimedKeys = {};
  int _userCurrentPoints = 0;
  
  final Map<String, Future<DocumentSnapshot?>> _userFuturesCache = {};
  final ValueNotifier<Duration> _timeLeftNotifier = ValueNotifier<Duration>(const Duration());
  final Map<String, Stream<List<Map<String, dynamic>>>> _streamCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
      _initEventControllers();
      _incrementViewsCount();
      _listenToEventUpdates();
      _listenToLikeStatus();
      _listenToRegistrations();
      _listenToUserClaims();
      _listenToUserScore();
    } else if (widget.eventId != null) {
      _isLoading = true;
      _fetchEvent();
    }
  }

  void _initEventControllers() {
    if (_event == null) return;
    
    int tabLength = 4;
    if (_event!.eventType == 'weekly_star' || 
        _event!.eventType == 'game_star' || 
        _event!.eventType == 'gifter_receiver' || 
        _event!.eventType == 'top_active') {
      tabLength = 2;
    } else if (_event!.eventType == 'top_room') {
      tabLength = 1;
    }
    
    _tabController = TabController(length: tabLength, vsync: this);
    _initTimer();
  }

  Future<void> _fetchEvent() async {
    final event = await EventService.getEventByEventId(widget.eventId!);
    if (mounted) {
      setState(() {
        _event = event;
        _isLoading = false;
        if (_event != null) {
          _initEventControllers();
          _incrementViewsCount();
          _listenToEventUpdates();
          _listenToLikeStatus();
          _listenToRegistrations();
          _listenToUserClaims();
          _listenToUserScore();
        }
      });
    }
  }

  void _incrementViewsCount() {
    if (_event == null) return;
    FirebaseFirestore.instance.collection('events').doc(_event!.id).update({
      'viewsCount': FieldValue.increment(1),
    });
  }

  void _listenToEventUpdates() {
    if (_event == null) return;
    _eventSubscription?.cancel();
    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(_event!.id)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _event = EventModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);
        });
      }
    });
  }

  void _listenToLikeStatus() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty || _event == null) return;

    _likeSubscription?.cancel();
    _likeSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(_event!.id)
        .collection('likes')
        .doc(currentUserId)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _isLiked = snap.exists;
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty || _event == null) return;

    final likeDoc = FirebaseFirestore.instance
        .collection('events')
        .doc(_event!.id)
        .collection('likes')
        .doc(currentUserId);

    if (_isLiked) {
      await likeDoc.delete();
      await FirebaseFirestore.instance.collection('events').doc(_event!.id).update({
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await likeDoc.set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('events').doc(_event!.id).update({
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  void _listenToRegistrations() {
    if (_event == null) return;

    _registrationsSubscription?.cancel();
    _registrationsSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(_event!.id)
        .collection('registrations')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _registeredUserIds = snap.docs.map((doc) => doc.id).toSet();
        });
      }
    });
  }

  void _listenToUserClaims() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _event == null) return;

    _claimsSubscription?.cancel();
    _claimsSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(_event!.id)
        .collection('claims')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _userClaimedKeys = snap.docs.map((doc) => doc.id).toSet();
        });
      }
    });
  }

  void _listenToUserScore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _event == null) return;

    _scoreSubscription?.cancel();
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final fieldName = 'event_${eventPrefix}_points';

    _scoreSubscription = FirebaseFirestore.instance
        .collection('leaderboard_stats')
        .doc(uid)
        .snapshots()
        .listen((docSnap) {
      if (mounted && docSnap.exists) {
        final data = docSnap.data();
        final score = (data?[fieldName] as num?)?.toInt() ?? 
                      (data?['event_${eventPrefix}_sent'] as num?)?.toInt() ?? 
                      (data?['event_${eventPrefix}_recharge'] as num?)?.toInt() ?? 0;
        setState(() {
          _userCurrentPoints = score;
        });
      }
    });
  }

  Future<void> _registerUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _event == null) return;

    final uid = currentUser.uid;
    final userName = currentUser.displayName ?? 'User';
    final userAvatar = currentUser.photoURL ?? '';

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_event!.id)
          .collection('registrations')
          .doc(uid)
          .set({
            'userId': uid,
            'userName': userName,
            'userAvatar': userAvatar,
            'registeredAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _claimReward({
    required String claimKey,
    required String rewardTitle,
    int diamonds = 0,
    String? itemId,
    int itemDays = 7,
    String? badgeId,
    int badgeDays = 7,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to claim rewards'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_userClaimedKeys.contains(claimKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward already claimed!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // 1. Credit Diamonds to Wallet
      if (diamonds > 0) {
        await WalletService().updateUserBalance(
          userId: uid,
          diamonds: diamonds,
          transactionType: 'event_reward_claim',
          description: 'Event Reward: ${_event!.eventName} - $rewardTitle',
        );
      }

      // 2. Assign Store Item / Frame to user backpack
      if (itemId != null && itemId.isNotEmpty) {
        await StoreService().assignStoreItemToUser(
          userId: uid,
          storeItemId: itemId,
          assignedBy: 'event_claim_${_event!.id}',
          expirationDays: itemDays > 0 ? itemDays : 30,
        );
      }

      // 3. Assign Badge if provided
      if (badgeId != null && badgeId.isNotEmpty) {
        await StoreService().assignStoreItemToUser(
          userId: uid,
          storeItemId: badgeId,
          assignedBy: 'event_claim_${_event!.id}',
          expirationDays: badgeDays > 0 ? badgeDays : 30,
        );
      }

      // 4. Record Claim under Event
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_event!.id)
          .collection('claims')
          .doc(claimKey)
          .set({
            'userId': uid,
            'claimKey': claimKey,
            'rewardTitle': rewardTitle,
            'diamonds': diamonds,
            'itemId': itemId ?? '',
            'itemDays': itemDays,
            'badgeId': badgeId ?? '',
            'badgeDays': badgeDays,
            'claimedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _userClaimedKeys.add(claimKey);
      });

      if (mounted) {
        _showClaimSuccessDialog(rewardTitle: rewardTitle, diamonds: diamonds, itemId: itemId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showClaimSuccessDialog({required String rewardTitle, int diamonds = 0, String? itemId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'Reward Claimed!',
              style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Congratulations! You have successfully claimed "$rewardTitle".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (diamonds > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text('+$diamonds Diamonds added to Wallet', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            if (itemId != null && itemId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎒', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text('Item added to your Backpack!', style: TextStyle(color: Color(0xFFFF80AB), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              ),
              child: const Text('Awesome!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLiveItemPreviewDialog({
    required String itemId,
    required String title,
    String? category,
    int? durationDays,
    int? diamondReward,
    String? claimKey,
    bool isEligible = false,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentAvatar = currentUser?.photoURL ?? '';
    final currentName = currentUser?.displayName ?? 'My Profile';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: itemId.isNotEmpty
              ? FirebaseFirestore.instance.collection('market_items').doc(itemId).get().then((doc) async {
                  if (doc.exists) return doc;
                  return FirebaseFirestore.instance.collection('store_items').doc(itemId).get();
                })
              : null,
          builder: (context, snapshot) {
            Map<String, dynamic>? itemData;
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              itemData = snapshot.data!.data() as Map<String, dynamic>?;
            }

            final String itemThumbnail = itemData?['thumbnailUrl'] ?? itemData?['iconUrl'] ?? itemData?['image'] ?? itemData?['imageUrl'] ?? '';
            final String itemAnimation = itemData?['animationUrl'] ?? itemData?['svgUrl'] ?? itemData?['assetUrl'] ?? '';
            final String resolvedTitle = itemData?['name'] ?? itemData?['title'] ?? title;
            final String itemType = itemData?['type'] ?? itemData?['itemType'] ?? category ?? 'avatarFrame';
            final int starRating = (itemData?['starRating'] as num?)?.toInt() ?? 1;

            final bool isClaimed = claimKey != null && _userClaimedKeys.contains(claimKey);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF1B142F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Exclusive Event Prize Preview',
                    style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),

                  // LIVE AVATAR / ITEM PREVIEW
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // User's actual profile photo
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: currentAvatar.isNotEmpty ? CachedNetworkImageProvider(currentAvatar) : null,
                        child: currentAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 44) : null,
                      ),
                      // Frame / Badge / Effect Overlay
                      if (itemType == 'avatarFrame' || itemType == 'frame')
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: (itemAnimation.isNotEmpty || itemThumbnail.isNotEmpty)
                              ? UniversalAssetWidget(
                                  url: itemAnimation.isNotEmpty ? itemAnimation : itemThumbnail,
                                  fit: BoxFit.contain,
                                )
                              : const Icon(Icons.stars, color: Colors.amber, size: 80),
                        )
                      else if (itemThumbnail.isNotEmpty)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                            child: UniversalAssetWidget(url: itemThumbnail, width: 28, height: 28),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      resolvedTitle,
                      style: const TextStyle(color: Color(0xFFFF4081), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Details Grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (diamondReward != null && diamondReward > 0)
                          Column(
                            children: [
                              const Text('💎', style: TextStyle(fontSize: 22)),
                              const SizedBox(height: 2),
                              Text(
                                '+$diamondReward',
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text('Diamonds', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        if (durationDays != null && durationDays > 0)
                          Column(
                            children: [
                              const Icon(Icons.access_time_filled, color: Colors.amber, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                '$durationDays Days',
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text('Validity', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(starRating, (i) => const Icon(Icons.star, color: Colors.amber, size: 14)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              itemType.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const Text('Rarity', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Button
                  if (claimKey != null) ...[
                    if (isClaimed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text('Reward Claimed ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      )
                    else if (isEligible)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _claimReward(
                              claimKey: claimKey,
                              rewardTitle: resolvedTitle,
                              diamonds: diamondReward ?? 0,
                              itemId: itemId,
                              itemDays: durationDays ?? 7,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 8,
                          ),
                          child: const Text('Claim Reward Now 🎁', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Text(
                            'Target not yet reached. Send gifts to unlock!',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _initTimer() {
    if (_event == null) return;
    _calculateTimeLeft();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    if (_event == null) return;
    final now = DateTime.now();
    if (_event!.endTime.isAfter(now)) {
      _timeLeftNotifier.value = _event!.endTime.difference(now);
    } else {
      _timeLeftNotifier.value = const Duration();
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _timer?.cancel();
    _timeLeftNotifier.dispose();
    _eventSubscription?.cancel();
    _likeSubscription?.cancel();
    _registrationsSubscription?.cancel();
    _claimsSubscription?.cancel();
    _scoreSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return "Event Ended";
    String days = duration.inDays > 0 ? '${duration.inDays}d ' : '';
    String hours = (duration.inHours % 24).toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$days$hours:$minutes:$seconds';
  }

  Stream<List<Map<String, dynamic>>> _getLeaderboardStream({required bool isSender, required int limit}) {
    if (_event == null) return const Stream.empty();
    
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final orderByField = isSender ? 'event_${eventPrefix}_sent' : 'event_${eventPrefix}_received';
    final cacheKey = 'leaderboard_${eventPrefix}_${isSender}_$limit';

    return _streamCache.putIfAbsent(cacheKey, () {
      return FirebaseFirestore.instance
          .collection('leaderboard_stats')
          .where(orderByField, isGreaterThan: 0)
          .orderBy(orderByField, descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final List<Map<String, dynamic>> sortedList = [];
            
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final String userId = doc.id;
                final int score = data[orderByField] ?? 0;
                
                if (_event!.hasRegistrationForm && !_registeredUserIds.contains(userId)) {
                  continue;
                }
                
                sortedList.add({
                  'userId': userId,
                  'userName': 'User',
                  'userAvatar': '',
                  'score': score,
                });
              } catch (e) {
                debugPrint('Error parsing leaderboard stats: $e');
              }
            }
              
            return sortedList;
          });
    });
  }

  Stream<List<Map<String, dynamic>>> _getAgencyLeaderboardStream({required int limit}) {
    if (_event == null) return const Stream.empty();
    
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final orderByField = 'event_${eventPrefix}_received';
    final cacheKey = 'agency_${eventPrefix}_$limit';

    return _streamCache.putIfAbsent(cacheKey, () {
      return FirebaseFirestore.instance
          .collection('leaderboard_stats')
          .where('isAgency', isEqualTo: true)
          .where(orderByField, isGreaterThan: 0)
          .orderBy(orderByField, descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final List<Map<String, dynamic>> sortedList = [];
            
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final String agencyId = doc.id;
                final int score = data[orderByField] ?? 0;
                
                sortedList.add({
                  'userId': agencyId,
                  'userName': 'Agency',
                  'userAvatar': '',
                  'score': score,
                });
              } catch (e) {
                debugPrint('Error parsing agency stats: $e');
              }
            }
              
            return sortedList;
          });
    });
  }

  Stream<List<Map<String, dynamic>>> _getRechargeLeaderboardStream({required int limit}) {
    if (_event == null) return const Stream.empty();
    
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final orderByField = 'event_${eventPrefix}_recharge';
    final cacheKey = 'recharge_${eventPrefix}_$limit';

    return _streamCache.putIfAbsent(cacheKey, () {
      return FirebaseFirestore.instance
          .collection('leaderboard_stats')
          .where(orderByField, isGreaterThan: 0)
          .orderBy(orderByField, descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final List<Map<String, dynamic>> sortedList = [];
            
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final String userId = doc.id;
                final int score = data[orderByField] ?? 0;
                
                if (_event!.hasRegistrationForm && !_registeredUserIds.contains(userId)) {
                  continue;
                }
                
                sortedList.add({
                  'userId': userId,
                  'userName': 'User',
                  'userAvatar': '',
                  'score': score,
                });
              } catch (e) {
                debugPrint('Error parsing recharge stats: $e');
              }
            }
              
            return sortedList;
          });
    });
  }

  Stream<List<Map<String, dynamic>>> _getRoomLeaderboardStream({required int limit}) {
    if (_event == null) return const Stream.empty();
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final cacheKey = 'room_${eventPrefix}_$limit';

    return _streamCache.putIfAbsent(cacheKey, () {
      return FirebaseFirestore.instance
          .collection('user_received_gifts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_event!.startTime))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_event!.endTime))
          .snapshots()
          .map((snapshot) {
            final Map<String, Map<String, dynamic>> roomAggregated = {};

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final String roomId = data['roomId'] ?? '';
                final int credits = data['credits'] ?? data['coinValue'] ?? data['giftValue'] ?? 0;

                if (roomId.isEmpty) continue;

                if (_event!.hasRegistrationForm) {
                  final String hostId = data['receiverId'] ?? '';
                  if (hostId.isNotEmpty && !_registeredUserIds.contains(hostId)) {
                    continue;
                  }
                }

                if (roomAggregated.containsKey(roomId)) {
                  roomAggregated[roomId]!['score'] = (roomAggregated[roomId]!['score'] as int) + credits;
                } else {
                  roomAggregated[roomId] = {
                    'roomId': roomId,
                    'score': credits,
                  };
                }
              } catch (e) {
                debugPrint('Error parsing room gift: $e');
              }
            }

            final sortedRooms = roomAggregated.values.toList()
              ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

            return sortedRooms.take(limit).toList();
          });
    });
  }

  Future<void> _joinRoom(String roomId) async {
    try {
      final roomSnap = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(roomId)
          .get();
      
      if (roomSnap.exists) {
        final room = AudioRoomV2.fromFirestore(roomSnap);
        final currentUserId = AuthController.instance.currentUser.userId;
        if (room.isUserBlocked(currentUserId)) {
          Get.snackbar(
            'Access Denied',
            'You are blocked from entering this room.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
        if (room.isUserKickedRecently(currentUserId)) {
          Get.snackbar(
            'Access Denied',
            'You have been removed from this room and cannot join for 24 hours.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
        Get.to(() => AudioRoomScreen(
          room: room,
          audioRoomsBloc: AudioRoomsBloc(repository: AudioRoomsRepository()),
        ));
      } else {
        Get.snackbar(
          'Room Closed',
          'This voice room is no longer active.',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not join room: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _loadFollowStatuses(List<Map<String, dynamic>> users) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;
    
    for (var user in users) {
      final uid = user['userId'] as String? ?? '';
      if (uid.isNotEmpty && uid != currentUserId && !_loadedFollowUserIds.contains(uid)) {
        _loadedFollowUserIds.add(uid);
        _followController.loadFollowStatusFromServer(
          currentUserId: currentUserId,
          targetUserId: uid,
        );
      }
    }
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Event Rules', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            _event!.rules.isNotEmpty ? _event!.rules : 'No specific rules configured for this event.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _showLastWeekDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Last Week Winners', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildWinnerRow('1', 'Charming Star Queen 👑', '1,200,000 Diamonds', Colors.amber),
              _buildWinnerRow('2', 'Wealthy Prince 💎', '980,000 Diamonds', Colors.grey),
              _buildWinnerRow('3', 'Top Gifter VIP 🎖️', '750,000 Diamonds', Colors.brown[300]!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _showStarlightHallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Starlight Hall of Fame', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildHallRow('Week 24', 'Winner: Angel_Face', '2,400,000 pts'),
              _buildHallRow('Week 23', 'Winner: Golden_Heart', '1,950,000 pts'),
              _buildHallRow('Week 22', 'Winner: Mystic_Gifter', '3,100,000 pts'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerRow(String rank, String name, String prize, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        radius: 14,
        child: Text(rank, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(prize, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildHallRow(String period, String winner, String score) {
    return ListTile(
      leading: const Icon(Icons.star, color: Colors.amber, size: 20),
      title: Text(period, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text('$winner ($score)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  void _handleBlockAction(String action, String data) {
    switch (action) {
      case 'open_registration':
        _registerUser();
        break;
      case 'join_event':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined Event successfully!')));
        break;
      case 'open_url':
        if (data.isNotEmpty) {
          launchUrl(Uri.parse(data), mode: LaunchMode.externalApplication);
        }
        break;
      case 'open_rules':
        _showRulesDialog();
        break;
      case 'check_in':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily Check-in completed!')));
        break;
      case 'share':
        Clipboard.setData(ClipboardData(text: _event?.eventId ?? ''));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event ID copied to clipboard!')));
        break;
    }
  }

  // Universal layout block renderer
  Widget _buildDynamicBlock(Map<String, dynamic> block, int blockIdx) {
    final String type = block['type'] ?? '';
    switch (type) {
      case 'image':
        final String imageUrl = block['imageUrl'] ?? '';
        final clickableAreas = List<Map<String, dynamic>>.from(block['clickableAreas'] ?? []);
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                final double currentHeight = constraints.maxWidth * (9 / 16);
                final double clickX = (details.localPosition.dx / constraints.maxWidth) * 100;
                final double clickY = (details.localPosition.dy / currentHeight) * 100;
                for (var area in clickableAreas) {
                  final double ax = (area['x'] as num? ?? 0).toDouble();
                  final double ay = (area['y'] as num? ?? 0).toDouble();
                  final double aw = (area['w'] as num? ?? 50).toDouble();
                  final double ah = (area['h'] as num? ?? 20).toDouble();
                  if (clickX >= ax && clickX <= ax + aw && clickY >= ay && clickY <= ay + ah) {
                    _handleBlockAction(area['action'] ?? '', area['data'] ?? '');
                    break;
                  }
                }
              },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            );
          },
        );
      case 'spacer':
        final double height = (block['height'] as num? ?? 20).toDouble();
        final String hexColor = block['color'] ?? '';
        Color color = Colors.transparent;
        if (hexColor.isNotEmpty && hexColor != 'transparent') {
          try {
            color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
          } catch (_) {}
        }
        return SizedBox(height: height, child: Container(color: color));
      case 'text':
        final String content = block['content'] ?? '';
        final double fontSize = (block['fontSize'] as num? ?? 14).toDouble();
        final String hexColor = block['color'] ?? '#ffffff';
        Color color = Colors.white;
        try {
          color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
        } catch (_) {}
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            content,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: block['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: block['alignment'] == 'center' ? TextAlign.center : TextAlign.left,
          ),
        );
      case 'action_button':
        final String text = block['text'] ?? 'Button';
        final String action = block['action'] ?? '';
        final String hexColor = block['buttonColor'] ?? '#2196F3';
        final String textHex = block['textColor'] ?? '#ffffff';
        Color btnColor = Colors.blue;
        Color txtColor = Colors.white;
        try {
          btnColor = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
          txtColor = Color(int.parse(textHex.replaceAll('#', '0xFF')));
        } catch (_) {}
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _handleBlockAction(action, ''),
            child: Text(text, style: TextStyle(color: txtColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        );
      case 'join_room':
        final String roomId = block['roomId'] ?? '';
        final String buttonText = block['buttonText'] ?? 'Click here to enter room $roomId';
        final String hexColor = block['buttonColor'] ?? '#00C853';
        final String textHex = block['textColor'] ?? '#ffffff';
        Color btnColor = Colors.green;
        Color txtColor = Colors.white;
        try {
          btnColor = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
          txtColor = Color(int.parse(textHex.replaceAll('#', '0xFF')));
        } catch (_) {}
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _joinRoom(roomId),
              child: Text(
                buttonText,
                style: TextStyle(color: txtColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      case 'action_row':
        final items = List.from(block['items'] ?? []);
        final String alignment = block['alignment'] ?? 'spaceEvenly';
        MainAxisAlignment mainAxisAlignment = MainAxisAlignment.spaceEvenly;
        if (alignment == 'center') mainAxisAlignment = MainAxisAlignment.center;
        if (alignment == 'left') mainAxisAlignment = MainAxisAlignment.start;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16),
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            children: items.map<Widget>((item) {
              IconData icon = Icons.info;
              if (item['icon'] == 'history') icon = Icons.history;
              if (item['icon'] == 'description') icon = Icons.description;
              if (item['icon'] == 'emoji_events') icon = Icons.emoji_events;
              if (item['icon'] == 'star') icon = Icons.star;
              if (item['icon'] == 'favorite') icon = Icons.favorite;

              Color accentColor = Colors.amber;
              if (_event!.themeConfig.containsKey('accentColor')) {
                try {
                  accentColor = Color(int.parse(_event!.themeConfig['accentColor'].toString().replaceAll('#', '0xFF')));
                } catch (_) {}
              }

              return InkWell(
                onTap: () => _handleBlockAction(item['action'] ?? 'open_rules', item['data'] ?? ''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accentColor, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['label'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      case 'countdown':
        final String c1 = block['color1'] ?? '#8E2DE2';
        final String c2 = block['color2'] ?? '#4A00E0';
        Color col1 = Colors.purple;
        Color col2 = Colors.blue;
        try {
          col1 = Color(int.parse(c1.replaceAll('#', '0xFF')));
          col2 = Color(int.parse(c2.replaceAll('#', '0xFF')));
        } catch (_) {}
        return _buildCountdownWidget(col1, col2);
      case 'rewards_showcase':
        final String title = block['title'] ?? 'Event Rewards';
        final items = List.from(block['items'] ?? []);
        final rewardsList = items.isNotEmpty ? items : _event!.rewards;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: rewardsList.length,
                itemBuilder: (context, index) {
                  final reward = rewardsList[index];
                  final String imageUrl = reward['fileUrl'] ?? reward['itemUrl'] ?? '';
                  final String name = reward['itemName'] ?? reward['category'] ?? 'Reward';
                  final String label = reward['rank'] ?? reward['label'] ?? '';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorWidget: (c, e, s) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
                          )
                        else
                          const Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (label.isNotEmpty)
                          Text(
                            label,
                            style: const TextStyle(color: Colors.grey, fontSize: 8),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      case 'cp_ferris_wheel':
        return _buildCpFerrisWheelBlock(block);
      case 'cp_nav_tabs':
        return _buildCpNavTabsBlock(block, blockIdx);
      case 'cp_gifts_grid':
        return _buildCpGiftsGridBlock(block);
      case 'cp_duo_ranking':
        return _buildCpDuoRankingBlock(block);
      case 'cp_tiered_prizes':
        return _buildCpTieredPrizesBlock(block);
      case 'vip_user_card':
        return _buildVipUserCardBlock(block);
      case 'seller_list':
        return _buildSellerListBlock(block);
      case 'hero_banner':
        return _buildHeroBannerBlock(block);
      case 'marquee':
        return _buildMarqueeBlock(block);
      case 'podium':
        return _buildPodiumBlock(block);
      case 'target_milestones':
        return _buildTargetMilestonesBlock(block);
      case 'rank_prizes':
        return _buildRankPrizesBlock(block);
      case 'diamond_rewards':
        return _buildTargetMilestonesBlock(block);
      case 'tabbed_leaderboard':
        return _buildDynamicLeaderboardBlock(block, blockIdx);
      default:
        return const SizedBox.shrink();
    }
  }

  // 🎯 Target Milestones Block with Live Progress & Instant Claim
  Widget _buildTargetMilestonesBlock(Map<String, dynamic> block) {
    final rawList = block['milestones'] ?? _event?.targetMilestones;
    final List<Map<String, dynamic>> milestones = [];
    if (rawList is List) {
      for (var item in rawList) {
        if (item is Map) milestones.add(Map<String, dynamic>.from(item));
      }
    }
    if (milestones.isEmpty) return const SizedBox.shrink();

    milestones.sort((a, b) {
      final pa = (a['targetPoints'] as num?)?.toInt() ?? 0;
      final pb = (b['targetPoints'] as num?)?.toInt() ?? 0;
      return pa.compareTo(pb);
    });

    final String title = block['title'] ?? '🎯 Target Milestones & Bonus Diamonds';
    final int maxTarget = (milestones.last['targetPoints'] as num?)?.toInt() ?? 10000;
    final double overallProgress = (maxTarget > 0) ? (_userCurrentPoints / maxTarget).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1435), Color(0xFF120C24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '$_userCurrentPoints Pts',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          ...milestones.map((m) {
            final int target = (m['targetPoints'] as num?)?.toInt() ?? 0;
            final int dia = (m['diamondReward'] as num?)?.toInt() ?? 0;
            final String itemId = m['itemId'] ?? '';
            final int days = (m['itemDays'] as num?)?.toInt() ?? 7;
            final String mTitle = m['title'] ?? 'Milestone ${target >= 1000 ? "${target ~/ 1000}K" : "$target"} Pts';
            final String claimKey = '${_event?.id}_milestone_$target';

            final bool reached = _userCurrentPoints >= target;
            final bool isClaimed = _userClaimedKeys.contains(claimKey);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: reached ? const Color(0xFF2B1D47) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: reached ? Colors.amber.withValues(alpha: 0.6) : Colors.white10,
                  width: reached ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _showLiveItemPreviewDialog(
                        itemId: itemId,
                        title: mTitle,
                        diamondReward: dia,
                        durationDays: days,
                        claimKey: claimKey,
                        isEligible: reached && !isClaimed,
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (itemId.isNotEmpty)
                            const Icon(Icons.stars, color: Colors.amber, size: 28)
                          else
                            const Text('💎', style: TextStyle(fontSize: 24)),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              child: const Icon(Icons.touch_app, color: Colors.amber, size: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target: $target Pts',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (dia > 0) ...[
                              const Text('💎', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 3),
                              Text(
                                '+$dia Dia',
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (itemId.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$days Days Frame',
                                  style: const TextStyle(color: Color(0xFFFF80AB), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isClaimed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text('Claimed', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else if (reached)
                    ElevatedButton(
                      onPressed: () {
                        _claimReward(
                          claimKey: claimKey,
                          rewardTitle: mTitle,
                          diamonds: dia,
                          itemId: itemId,
                          itemDays: days,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: const Text('Claim 🎁', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Need ${(target - _userCurrentPoints)} Pts',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🏆 Leaderboard Rank Rewards Block
  Widget _buildRankPrizesBlock(Map<String, dynamic> block) {
    final rawList = block['tiers'] ?? _event?.rewardTiers;
    final List<Map<String, dynamic>> tiers = [];
    if (rawList is List) {
      for (var item in rawList) {
        if (item is Map) tiers.add(Map<String, dynamic>.from(item));
      }
    }
    if (tiers.isEmpty) return const SizedBox.shrink();

    final String title = block['title'] ?? '🏆 Leaderboard Rank Rewards';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF140E26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.pink.withValues(alpha: 0.08), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Color(0xFFFF4081), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tiers.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            final String rankRange = t['rankRange'] ?? 'Top ${idx + 1}';
            final int dia = (t['diamondReward'] as num?)?.toInt() ?? (t['diamondAmount'] as num?)?.toInt() ?? 0;
            final String frameId = t['frameId'] ?? t['itemId'] ?? '';
            final int frameDays = (t['frameDays'] as num?)?.toInt() ?? (t['itemDays'] as num?)?.toInt() ?? 7;
            final String badgeId = t['badgeId'] ?? '';
            final int badgeDays = (t['badgeDays'] as num?)?.toInt() ?? 7;

            final Color rankColor = idx == 0 ? Colors.amber : (idx == 1 ? const Color(0xFFE0E0E0) : const Color(0xFFCD7F32));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: rankColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: rankColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rankRange,
                          style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (dia > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('💎 +$dia Dia', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            if (frameId.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _showLiveItemPreviewDialog(
                                    itemId: frameId,
                                    title: '$rankRange Frame',
                                    diamondReward: dia,
                                    durationDays: frameDays,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.pinkAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('🖼️ $frameDays Days Frame ↗', style: const TextStyle(color: Color(0xFFFF80AB), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            if (badgeId.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('👑 $badgeDays Days Badge', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🎡 1. CP Ferris Wheel Block (Client App View)
  Widget _buildCpFerrisWheelBlock(Map<String, dynamic> block) {
    final couples = List<Map<String, dynamic>>.from(block['couples'] ?? []);
    final String title = block['title'] ?? 'Weekly CP Ferris Wheel';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD6E7), Color(0xFFFFF0F5)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF1493).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFF1493),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text('✨', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 300,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF69B4).withValues(alpha: 0.5), width: 3),
              gradient: RadialGradient(
                colors: [Colors.white.withValues(alpha: 0.85), const Color(0xFFFFE4E1).withValues(alpha: 0.3)],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1493),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.pinkAccent, blurRadius: 12, spreadRadius: 2),
                    ],
                  ),
                  child: const Center(
                    child: Text('💖', style: TextStyle(fontSize: 26)),
                  ),
                ),
                if (couples.isNotEmpty)
                  Positioned(top: 10, child: _buildFerrisCouplePodClient(couples[0])),
                if (couples.length > 1)
                  Positioned(left: 10, top: 75, child: _buildFerrisCouplePodClient(couples[1])),
                if (couples.length > 2)
                  Positioned(right: 10, top: 75, child: _buildFerrisCouplePodClient(couples[2])),
                if (couples.length > 3)
                  Positioned(bottom: 10, left: 32, child: _buildFerrisCouplePodClient(couples[3])),
                if (couples.length > 4)
                  Positioned(bottom: 10, right: 32, child: _buildFerrisCouplePodClient(couples[4])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFerrisCouplePodClient(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF69B4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.pink.withValues(alpha: 0.2), blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundImage: CachedNetworkImageProvider(c['avatar1'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
              ),
              const SizedBox(width: 3),
              const Text('💕', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 3),
              CircleAvatar(
                radius: 11,
                backgroundImage: CachedNetworkImageProvider(c['avatar2'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFFF1493), borderRadius: BorderRadius.circular(8)),
            child: Text(
              c['points'] ?? '5.2M',
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🎡 2. CP Sub-Nav Tabs
  Widget _buildCpNavTabsBlock(Map<String, dynamic> block, int blockIdx) {
    final tabs = List<String>.from(block['tabs'] ?? ['CP Wall', 'Ranking', 'Rewards']);
    final int selectedIdx = _selectedBlockTabIndices[blockIdx] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD1DC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final t = entry.value;
          final bool isAct = idx == selectedIdx;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBlockTabIndices[blockIdx] = idx;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isAct ? const Color(0xFFFF1493) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isAct ? [BoxShadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 4)] : null,
                ),
                child: Center(
                  child: Text(
                    t,
                    style: TextStyle(
                      color: isAct ? Colors.white : const Color(0xFFD81B60),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🎡 3. CP Gifts Grid Block
  Widget _buildCpGiftsGridBlock(Map<String, dynamic> block) {
    final gifts = List<Map<String, dynamic>>.from(block['gifts'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB6C1)),
        boxShadow: [
          BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            block['title'] ?? 'Give these gifts to increase CP points',
            style: const TextStyle(color: Color(0xFFFF1493), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final g = gifts[index];
              final String imgUrl = g['imageUrl'] ?? '';
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.08), blurRadius: 4)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (imgUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imgUrl,
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        errorWidget: (c, e, s) => Text(g['icon'] ?? '🎁', style: const TextStyle(fontSize: 26)),
                      )
                    else
                      Text(g['icon'] ?? '🎁', style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                      g['name'] ?? 'Gift',
                      style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      g['points'] ?? '37777pts',
                      style: const TextStyle(color: Color(0xFFFF1493), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🎡 4. CP Duo Ranking Block
  Widget _buildCpDuoRankingBlock(Map<String, dynamic> block) {
    final couples = List<Map<String, dynamic>>.from(block['couples'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB6C1)),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💞', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                block['title'] ?? 'This Week Ranking',
                style: const TextStyle(color: Color(0xFFFF1493), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...couples.map((c) {
            final int rank = c['rank'] ?? 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: rank == 1 ? Colors.amber : (rank == 2 ? const Color(0xFFB388FF) : const Color(0xFFFF80AB)),
                    child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: CachedNetworkImageProvider(c['avatar1'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
                  ),
                  const SizedBox(width: 3),
                  const Text('💕', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: CachedNetworkImageProvider(c['avatar2'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${c['name1']} & ${c['name2']}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${c['points']}',
                    style: const TextStyle(color: Color(0xFFFF1493), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🎡 5. CP Tiered Prizes Block
  Widget _buildCpTieredPrizesBlock(Map<String, dynamic> block) {
    final tiers = List<Map<String, dynamic>>.from(block['tiers'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB6C1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block['title'] ?? 'Winner Prizes',
            style: const TextStyle(color: Color(0xFFFF1493), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...tiers.map((t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.08), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.military_tech, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        t['rankTitle'] ?? 'Top.1',
                        style: const TextStyle(color: Color(0xFFFF1493), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPrizeMiniIconClient('👑', t['badgeName'] ?? 'Badge', t['badgeDays'] ?? '7d'),
                      _buildPrizeMiniIconClient('🖼️', t['frameName'] ?? 'Frame', t['frameDays'] ?? '7d'),
                      _buildPrizeMiniIconClient('💎', '${t['diamondAmount']} Dia', 'Diamonds'),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrizeMiniIconClient(String emoji, String title, String sub) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 8)),
      ],
    );
  }

  // 👤 6. Featured VIP User ID Card
  Widget _buildVipUserCardBlock(Map<String, dynamic> block) {
    final String uid = block['userId'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: uid.isNotEmpty ? FirebaseFirestore.instance.collection('Users').doc(uid).get() : null,
      builder: (context, snapshot) {
        String name = block['userName'] ?? 'VIP User';
        String avatar = block['userAvatar'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final d = snapshot.data!.data() as Map<String, dynamic>;
          name = d['fullname'] ?? d['name'] ?? d['username'] ?? name;
          avatar = d['photoUrl'] ?? d['avatar'] ?? d['profilePic'] ?? avatar;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A1C3E), Color(0xFF141026)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.amber,
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                      child: Text(block['tag'] ?? '👑 TOP HOST', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 3),
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('ID: $uid', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Text(block['points'] ?? '★ 500K Pts', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // 💎 7. Official Sellers List Block (with Profile, Follow Button, Clickable Seller ID)
  Widget _buildSellerListBlock(Map<String, dynamic> block) {
    final sellers = List<Map<String, dynamic>>.from(block['sellers'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block['title'] ?? 'Official Verified Coin Sellers',
                  style: const TextStyle(color: Color(0xFF00B074), fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.verified, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          ...sellers.map((s) {
            final String sellerId = s['userId'] ?? '';
            final String name = s['name'] ?? 'Official Seller';
            final String avatar = s['avatar'] ?? '';
            final String contact = s['contact'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.storefront, color: Colors.green) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle, color: Colors.green, size: 12),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            if (sellerId.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProfilePageForRoom(
                                    userID: sellerId,
                                    userName: name,
                                    userImage: avatar,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'ID: $sellerId (Tap to View) ↗',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (contact.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                      tooltip: 'WhatsApp / Chat',
                      onPressed: () {
                        final cleanPhone = contact.replaceAll(RegExp(r'[^0-9+]'), '');
                        launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
                      },
                    ),
                  if (sellerId.isNotEmpty && sellerId != currentUserId)
                    FollowButton(
                      currentUserId: currentUserId,
                      targetUserId: sellerId,
                      targetUserName: name,
                      followController: _followController,
                      textColor: const Color(0xFFFF1493),
                      borderColor: const Color(0xFFFF1493).withValues(alpha: 0.4),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🖼️ 8. Hero Banner Block
  Widget _buildHeroBannerBlock(Map<String, dynamic> block) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: (block['height'] as num?)?.toDouble() ?? 180.0,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: CachedNetworkImageProvider(block['imageUrl'] ?? _event!.banner),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(6)),
                  child: Text(block['badge'] ?? '⚡ LIVE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Text(block['title'] ?? _event!.eventName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(block['subtitle'] ?? _event!.description, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📢 9. Marquee Announcement Block
  Widget _buildMarqueeBlock(Map<String, dynamic> block) {
    Color bg = const Color(0xFF241442);
    Color txt = Colors.amber;
    try {
      if (block['bgColor'] != null) bg = Color(int.parse(block['bgColor'].toString().replaceAll('#', '0xFF')));
      if (block['textColor'] != null) txt = Color(int.parse(block['textColor'].toString().replaceAll('#', '0xFF')));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          const Text('📢', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block['text'] ?? 'Welcome to the Event!',
              style: TextStyle(color: txt, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 🏆 10. Winners Podium Block
  Widget _buildPodiumBlock(Map<String, dynamic> block) {
    return _buildLiveLeaderboardWidget(isSender: false, activeColor: Colors.amber, limit: 3, showPodium: true);
  }

  // 📱 Master Dynamic Layout Engine for Client App
  Widget _buildDynamicBlockLayout(BuildContext context) {
    Color bgColor = const Color(0xFFFFF0F5);
    Color accentColor = const Color(0xFFFF1493);
    String bgImg = '';

    if (_event!.themeConfig.isNotEmpty) {
      try {
        if (_event!.themeConfig['backgroundColor'] != null) {
          bgColor = Color(int.parse(_event!.themeConfig['backgroundColor'].toString().replaceAll('#', '0xFF')));
        }
        if (_event!.themeConfig['accentColor'] != null) {
          accentColor = Color(int.parse(_event!.themeConfig['accentColor'].toString().replaceAll('#', '0xFF')));
        }
        bgImg = _event!.themeConfig['backgroundImageUrl'] ?? '';
      } catch (_) {}
    }

    final bool hasExplicitMilestonesBlock = _event!.layoutBlocks.any((b) => b['type'] == 'target_milestones' || b['type'] == 'diamond_rewards');
    final bool hasExplicitRankPrizesBlock = _event!.layoutBlocks.any((b) => b['type'] == 'rank_prizes' || b['type'] == 'cp_tiered_prizes');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: accentColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _event!.eventName,
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.redAccent : accentColor),
            onPressed: _toggleLike,
          ),
          IconButton(
            icon: Icon(Icons.share, color: accentColor),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _event!.fullEventUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Event link copied: ${_event!.fullEventUrl}'), backgroundColor: accentColor),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: accentColor),
            onPressed: _showRulesDialog,
          ),
        ],
      ),
      body: Container(
        decoration: bgImg.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(image: CachedNetworkImageProvider(bgImg), fit: BoxFit.cover),
              )
            : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            children: [
              ..._event!.layoutBlocks.asMap().entries.map((entry) {
                final idx = entry.key;
                final b = entry.value;
                if (b['isPrivate'] == true) return const SizedBox.shrink();
                return _buildDynamicBlock(b, idx);
              }),
              if (!hasExplicitMilestonesBlock && _event!.targetMilestones.isNotEmpty)
                _buildTargetMilestonesBlock({}),
              if (!hasExplicitRankPrizesBlock && _event!.rewardTiers.isNotEmpty)
                _buildRankPrizesBlock({}),
              _buildStickyCurrentUserRankCard(),
              _buildFooterSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (_event!.hasRegistrationForm && !_registeredUserIds.contains(FirebaseAuth.instance.currentUser?.uid ?? ''))
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Register for Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStickyCurrentUserRankCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final eventPrefix = _event!.id.replaceAll('-', '_');
    final orderByField = 'event_${eventPrefix}_points';

    return FutureBuilder<int>(
      future: _calculateUserRank(uid, orderByField),
      builder: (context, snapshot) {
        final int rank = snapshot.data ?? 0;
        final String rankText = rank > 0 ? '#$rank' : 'Unranked';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E174D), Color(0xFF1B0F2E)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rankText,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                    ? CachedNetworkImageProvider(FirebaseAuth.instance.currentUser!.photoURL!)
                    : null,
                child: FirebaseAuth.instance.currentUser?.photoURL == null
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FirebaseAuth.instance.currentUser?.displayName ?? 'My Profile',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(
                          '$_userCurrentPoints Points',
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Text(
                'My Event Rank',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicLeaderboardBlock(Map<String, dynamic> block, int blockIdx) {
    final tabs = List.from(block['tabs'] ?? []);
    if (tabs.isEmpty) return const SizedBox.shrink();

    final int selectedIdx = _selectedBlockTabIndices[blockIdx] ?? 0;
    final activeTab = tabs[selectedIdx < tabs.length ? selectedIdx : 0];
    final String rankType = activeTab['rankType'] ?? 'receiver';
    final int limit = activeTab['limit'] ?? 100;

    final String hex = block['activeTabColor'] ?? '#FFC107';
    Color activeColor = Colors.amber;
    try {
      activeColor = Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {}
    final showPodium = block['showPodium'] ?? true;

    return Column(
      children: [
        if (tabs.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: tabs.asMap().entries.map<Widget>((entry) {
                final idx = entry.key;
                final t = entry.value;
                final isSelected = idx == selectedIdx;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBlockTabIndices[blockIdx] = idx;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? activeColor : Colors.transparent, width: 1.5),
                    ),
                    child: Text(
                      t['title'] ?? 'Tab',
                      style: TextStyle(
                        color: isSelected ? activeColor : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (rankType == 'receiver' || rankType == 'sender')
          _buildLiveLeaderboardWidget(isSender: rankType == 'sender', activeColor: activeColor, limit: limit, showPodium: showPodium)
        else if (rankType == 'room')
          _buildRoomLeaderboardWidget(activeColor: activeColor, limit: limit)
        else if (rankType == 'recharge')
          _buildRechargeLeaderboardWidget(activeColor: activeColor, limit: limit, showPodium: showPodium)
        else if (rankType == 'agency_battle')
          _buildAgencyLeaderboardWidget(activeColor: activeColor, limit: limit, showPodium: showPodium)
        else if (rankType == 'active_room')
          _buildActiveRoomsWidget(activeColor: activeColor, limit: limit)
        else if (rankType == 'active_user')
          _buildActiveUsersWidget(activeColor: activeColor, limit: limit)
        else if (rankType == 'greedy_game' || rankType == 'fruit_wheel')
          _buildMockLeaderboardWidget(gameName: rankType == 'greedy_game' ? 'Greedy Game' : 'Fruit Wheel', activeColor: activeColor, limit: limit, showPodium: showPodium),
      ],
    );
  }

  Widget _buildRechargeLeaderboardWidget({required Color activeColor, required int limit, required bool showPodium}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getRechargeLeaderboardStream(limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No recharge data yet.', style: TextStyle(color: Colors.grey))));
        }

        final list = snapshot.data!.take(limit).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(list));

        final top3 = showPodium ? list.take(3).toList() : <Map<String, dynamic>>[];
        final rest = showPodium ? list.skip(3).toList() : list;

        return Column(
          children: [
            if (showPodium && top3.isNotEmpty) _buildPodium(top3),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rest.length,
              itemBuilder: (context, index) {
                final rank = showPodium ? index + 4 : index + 1;
                final user = rest[index];
                return _buildRankRow(rank, user);
              },
            ),
            _buildCurrentUserRankBar(
              list: list, 
              activeColor: activeColor, 
              orderByField: 'event_${_event!.id.replaceAll('-', '_')}_recharge'
            ),
          ],
        );
      },
    );
  }

  Widget _buildAgencyLeaderboardWidget({required Color activeColor, required int limit, required bool showPodium}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAgencyLeaderboardStream(limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No agency data yet.', style: TextStyle(color: Colors.grey))));
        }

        final list = snapshot.data!.take(limit).toList();

        final top3 = showPodium ? list.take(3).toList() : <Map<String, dynamic>>[];
        final rest = showPodium ? list.skip(3).toList() : list;

        return Column(
          children: [
            if (showPodium && top3.isNotEmpty) _buildPodium(top3),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rest.length,
              itemBuilder: (context, index) {
                final rank = showPodium ? index + 4 : index + 1;
                final user = rest[index];
                return _buildAgencyRankRow(rank, user);
              },
            ),
            _buildCurrentUserRankBar(
              list: list, 
              activeColor: activeColor, 
              orderByField: 'event_${_event!.id.replaceAll('-', '_')}_received'
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveLeaderboardWidget({required bool isSender, required Color activeColor, required int limit, required bool showPodium}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getLeaderboardStream(isSender: isSender, limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No rank data yet.', style: TextStyle(color: Colors.grey))));
        }

        final list = snapshot.data!.take(limit).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(list));

        final top3 = showPodium ? list.take(3).toList() : <Map<String, dynamic>>[];
        final rest = showPodium ? list.skip(3).toList() : list;

        return Column(
          children: [
            if (showPodium && top3.isNotEmpty) _buildPodium(top3),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rest.length,
              itemBuilder: (context, index) {
                final rank = showPodium ? index + 4 : index + 1;
                final user = rest[index];
                return _buildRankRow(rank, user);
              },
            ),
            _buildCurrentUserRankBar(
              list: list, 
              activeColor: activeColor, 
              orderByField: isSender ? 'event_${_event!.id.replaceAll('-', '_')}_sent' : 'event_${_event!.id.replaceAll('-', '_')}_received'
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomLeaderboardWidget({required Color activeColor, required int limit}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getRoomLeaderboardStream(limit: limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No room scores yet.', style: TextStyle(color: Colors.grey))));
        }

        final rooms = snapshot.data!.take(limit).toList();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final rank = index + 1;
            final item = rooms[index];
            final String roomId = item['roomId'];
            final int score = item['score'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('audio_rooms_v2').doc(roomId).get(),
              builder: (context, roomSnap) {
                String roomName = 'Room $roomId';
                String roomAvatar = '';
                if (roomSnap.hasData && roomSnap.data != null && roomSnap.data!.exists) {
                  final data = roomSnap.data!.data() as Map<String, dynamic>;
                  roomName = data['title'] ?? data['name'] ?? roomName;
                  roomAvatar = data['imageUrl'] ?? data['thumbnailUrl'] ?? '';
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: activeColor.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : rank == 3 ? Colors.brown[300] : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.teal[900],
                        backgroundImage: roomAvatar.isNotEmpty ? CachedNetworkImageProvider(roomAvatar) : null,
                        child: roomAvatar.isEmpty ? Icon(Icons.home_filled, color: activeColor, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.diamond, color: activeColor, size: 12),
                                const SizedBox(width: 2),
                                Text('$score diamonds', style: TextStyle(color: activeColor, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor.withValues(alpha: 0.15),
                          foregroundColor: activeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: activeColor, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _joinRoom(roomId),
                        child: const Text('Join Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActiveRoomsWidget({required Color activeColor, required int limit}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('audio_rooms_v2').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No active rooms found.', style: TextStyle(color: Colors.grey))));
        }

        final List<AudioRoomV2> rooms = snapshot.data!.docs
            .map((doc) => AudioRoomV2.fromFirestore(doc))
            .toList();

        rooms.sort((a, b) => b.participants.length.compareTo(a.participants.length));
        final list = rooms.take(limit).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final rank = index + 1;
            final room = list[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? activeColor : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange[900],
                    backgroundImage: (room.imageUrl != null && room.imageUrl!.isNotEmpty) ? CachedNetworkImageProvider(room.imageUrl!) : null,
                    child: (room.imageUrl == null || room.imageUrl!.isEmpty) ? Icon(Icons.volume_up, color: activeColor) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${room.participants.length} users online',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor.withValues(alpha: 0.15),
                      foregroundColor: activeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _joinRoom(room.id),
                    child: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveUsersWidget({required Color activeColor, required int limit}) {
    final List<Map<String, dynamic>> mockActive = [
      {'userId': 'usr1', 'userName': 'Hyper_Speaker 🎙️', 'score': '124 Hours', 'userAvatar': ''},
      {'userId': 'usr2', 'userName': 'Chatty_Cat 😺', 'score': '98 Hours', 'userAvatar': ''},
      {'userId': 'usr3', 'userName': 'Music_Lover 🎵', 'score': '87 Hours', 'userAvatar': ''},
      {'userId': 'usr4', 'userName': 'Silent_Listener 🎧', 'score': '75 Hours', 'userAvatar': ''},
    ];

    final list = mockActive.take(limit).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(list));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final rank = index + 1;
        final user = list[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
               SizedBox(
                 width: 28,
                 child: Text('$rank', style: TextStyle(color: activeColor, fontWeight: FontWeight.bold)),
               ),
               const CircleAvatar(
                 radius: 20,
                 child: Icon(Icons.person, color: Colors.grey),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(user['userName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                     const SizedBox(height: 4),
                     Text('Active Speaker Time: ${user['score']}', style: TextStyle(color: activeColor, fontSize: 11)),
                   ],
                 ),
               ),
               if (user['userId'] != currentUserId)
                 SizedBox(
                   height: 32,
                   child: FittedBox(
                     child: FollowButton(
                       currentUserId: currentUserId,
                       targetUserId: user['userId'] ?? '',
                       targetUserName: user['userName'] ?? '',
                       followController: _followController,
                       textColor: activeColor,
                       borderColor: activeColor.withValues(alpha: 0.3),
                     ),
                   ),
                 ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMockLeaderboardWidget({required String gameName, required Color activeColor, required int limit, required bool showPodium}) {
    final List<Map<String, dynamic>> mockData = [
      {'userId': 'g1', 'userName': 'Greedy_King 🎲', 'score': 1500000, 'userAvatar': ''},
      {'userId': 'g2', 'userName': 'Fruit_Master 🍉', 'score': 1200000, 'userAvatar': ''},
      {'userId': 'g3', 'userName': 'Wheel_Spinner 🎡', 'score': 950000, 'userAvatar': ''},
      {'userId': 'g4', 'userName': 'Gold_Digger 🪙', 'score': 740000, 'userAvatar': ''},
    ];

    final list = mockData.take(limit).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(list));

    final top3 = showPodium ? list.take(3).toList() : <Map<String, dynamic>>[];
    final rest = showPodium ? list.skip(3).toList() : list;

    return Column(
      children: [
        if (showPodium && top3.isNotEmpty) _buildPodium(top3),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rest.length,
          itemBuilder: (context, index) {
            final rank = showPodium ? index + 4 : index + 1;
            final user = rest[index];
            return _buildRankRow(rank, user);
          },
        ),
      ],
    );
  }

  Widget _buildFooterSection() {
    if (_event == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_event!.viewsCount}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_event!.likesCount} likes',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleLike,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white10,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    if (top3.isEmpty) return const SizedBox.shrink();
    
    final Map<String, dynamic>? first = top3.isNotEmpty ? top3[0] : null;
    final Map<String, dynamic>? second = top3.length > 1 ? top3[1] : null;
    final Map<String, dynamic>? third = top3.length > 2 ? top3[2] : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            _buildPodiumColumn(second, 2, Colors.grey, 65)
          else
            const SizedBox(width: 80),
            
          if (first != null)
            _buildPodiumColumn(first, 1, Colors.amber, 85)
          else
            const SizedBox(width: 90),
            
          if (third != null)
            _buildPodiumColumn(third, 3, Colors.brown[300]!, 65)
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic> user, int rank, Color color, double size) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String userId = user['userId'] ?? '';

    final future = _userFuturesCache.putIfAbsent(
      userId,
      () => FirebaseFirestore.instance.collection('Users').doc(userId).get(),
    );

    return FutureBuilder<DocumentSnapshot?>(
      future: (user['userName'] == 'User' || user['userAvatar'] == null || user['userAvatar'].toString().isEmpty) && userId.isNotEmpty
          ? future
          : Future<DocumentSnapshot?>.value(null),
      builder: (context, snapshot) {
        String name = user['userName'] ?? '';
        String avatar = user['userAvatar'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['fullname'] ?? data['userName'] ?? data['name'] ?? name;
          avatar = data['photoUrl'] ?? data['imageUrl'] ?? data['profileImageUrl'] ?? data['avatar'] ?? avatar;
        }

        // Crown colors based on rank
        final crownColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.blueGrey[300]! : Colors.brown[400]!);
        final crownIcon = rank == 1 ? Icons.military_tech : (rank == 2 ? Icons.military_tech_outlined : Icons.military_tech_outlined);
        
        return GestureDetector(
          onTap: () {
            if (userId.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePageForRoom(
                    userID: userId,
                    userName: name,
                    userImage: avatar,
                  ),
                ),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Avatar with premium border and glow
                Container(
                  width: size + 12,
                  height: size + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.8), color, color.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: rank == 1 ? 20 : 12,
                        spreadRadius: rank == 1 ? 4 : 2,
                      )
                    ]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                      child: CircleAvatar(
                        radius: size / 2,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar.isEmpty ? Icon(Icons.person, color: Colors.grey[400], size: size * 0.5) : null,
                      ),
                    ),
                  ),
                ),
                // Crown
                Positioned(
                  top: -24,
                  child: Icon(crownIcon, color: crownColor, size: rank == 1 ? 42 : 32),
                ),
                // Rank Badge
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.8), color],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Text(
                      'TOP $rank',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size + 20,
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.cyanAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${user['score']}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (userId != currentUserId) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 80,
                height: 28,
                child: FittedBox(
                  child: FollowButton(
                    currentUserId: currentUserId,
                    targetUserId: userId,
                    targetUserName: name,
                    followController: _followController,
                    borderColor: color.withValues(alpha: 0.5),
                    textColor: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
      }
    );
  }

  Widget _buildRankRow(int rank, Map<String, dynamic> user) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String userId = user['userId'] ?? '';

    final future = _userFuturesCache.putIfAbsent(
      userId,
      () => FirebaseFirestore.instance.collection('Users').doc(userId).get(),
    );

    return FutureBuilder<DocumentSnapshot?>(
      future: (user['userName'] == 'User' || user['userAvatar'] == null || user['userAvatar'].toString().isEmpty) && userId.isNotEmpty
          ? future
          : Future<DocumentSnapshot?>.value(null),
      builder: (context, snapshot) {
        String name = user['userName'] ?? '';
        String avatar = user['userAvatar'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['fullname'] ?? data['userName'] ?? data['name'] ?? name;
          avatar = data['photoUrl'] ?? data['imageUrl'] ?? data['profileImageUrl'] ?? data['avatar'] ?? avatar;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.02)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (userId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfilePageForRoom(
                          userID: userId,
                          userName: name,
                          userImage: avatar,
                        ),
                      ),
                    );
                  }
                }, // Can be used for profile navigation
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rank',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Avatar with border
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                          child: avatar.isEmpty ? Icon(Icons.person, color: Colors.grey[400]) : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name and Score
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.diamond, color: Colors.cyanAccent, size: 10),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${user['score']}',
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Follow Button
                      if (userId != currentUserId)
                        SizedBox(
                          height: 30,
                          child: FittedBox(
                            child: FollowButton(
                              currentUserId: currentUserId,
                              targetUserId: userId,
                              targetUserName: name,
                              followController: _followController,
                              borderColor: Colors.amber.withValues(alpha: 0.7),
                              textColor: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgencyRankRow(int rank, Map<String, dynamic> user) {
    final String agencyId = user['userId'] ?? '';

    return FutureBuilder<DocumentSnapshot?>(
      future: agencyId.isNotEmpty
          ? FirebaseFirestore.instance.collection('agencies').doc(agencyId).get()
          : Future<DocumentSnapshot?>.value(null),
      builder: (context, snapshot) {
        String name = user['userName'] ?? 'Agency';
        String avatar = user['userAvatar'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['agencyName'] ?? name;
          avatar = data['logo'] ?? data['imageUrl'] ?? avatar;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepOrangeAccent.withValues(alpha: 0.2),
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.shield, color: Colors.deepOrangeAccent) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.diamond, color: Colors.cyan, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${user['score']}',
                          style: TextStyle(color: Colors.cyan[300], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountdownWidget(Color col1, Color col2) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [col1, col2]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: col1.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          ValueListenableBuilder<Duration>(
            valueListenable: _timeLeftNotifier,
            builder: (context, timeLeft, _) {
              return Text(
                'Ends in: ${_formatDuration(timeLeft)}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }

  // 1. WEEKLY STAR VIEW (Fallback Legacy layout)
  Widget _buildWeeklyStarView() {
    Color bgThemeColor = const Color(0xFF0F0B21);
    if (_event!.themeConfig.containsKey('backgroundColor')) {
      final String hex = _event!.themeConfig['backgroundColor'];
      try {
        bgThemeColor = Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgThemeColor, bgThemeColor.withValues(alpha: 0.8), const Color(0xFF0B071A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: bgThemeColor.withValues(alpha: 0.5),
              child: const Icon(Icons.star, color: Colors.amber, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton('Last Week', Icons.history, _showLastWeekDialog, Colors.amber),
                _buildQuickActionButton('Rules', Icons.description, _showRulesDialog, Colors.amber),
                _buildQuickActionButton('Hall of Fame', Icons.emoji_events, _showStarlightHallDialog, Colors.amber),
              ],
            ),
          ),
          _buildCountdownWidget(const Color(0xFF8E2DE2), const Color(0xFF4A00E0)),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.amber,
            tabs: const [
              Tab(text: 'Charming Star'),
              Tab(text: 'Wealthy Star'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardTab(isSender: false, activeColor: Colors.amber),
                _buildLeaderboardTab(isSender: true, activeColor: Colors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. GAME STAR VIEW (Fallback Legacy layout)
  Widget _buildGameStarView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1E29), Color(0xFF0B141D), Color(0xFF070B0E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: Colors.blueGrey[900],
              child: const Icon(Icons.videogame_asset, color: Colors.amberAccent, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton('Rules', Icons.description, _showRulesDialog, Colors.amberAccent),
              ],
            ),
          ),
          _buildCountdownWidget(const Color(0xFF1F4068), const Color(0xFF162447)),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.amberAccent,
            tabs: const [
              Tab(text: 'Greedy Game'),
              Tab(text: 'Fruit Wheel'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGameLeaderboardTab(gameName: 'Greedy Game', activeColor: Colors.amberAccent),
                _buildGameLeaderboardTab(gameName: 'Fruit Wheel', activeColor: Colors.amberAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. GIFTER & RECEIVER VIEW (Fallback Legacy layout)
  Widget _buildGifterReceiverView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF260D1E), Color(0xFF1C0A16), Color(0xFF11050D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: Colors.pink[900]!.withValues(alpha: 0.3),
              child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton('Rules', Icons.description, _showRulesDialog, Colors.pinkAccent),
              ],
            ),
          ),
          _buildCountdownWidget(const Color(0xFFD63447), const Color(0xFF7A0826)),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: Colors.pinkAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.pinkAccent,
            tabs: const [
              Tab(text: 'Top Receiver'),
              Tab(text: 'Top Gifter'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardTab(isSender: false, activeColor: Colors.pinkAccent),
                _buildLeaderboardTab(isSender: true, activeColor: Colors.pinkAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. TOP ROOM EVENT VIEW (Fallback Legacy layout)
  Widget _buildTopRoomView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF072124), Color(0xFF041416), Color(0xFF02090A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: Colors.teal[900]!.withValues(alpha: 0.3),
              child: const Icon(Icons.meeting_room, color: Colors.tealAccent, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton('Rules', Icons.description, _showRulesDialog, Colors.cyanAccent),
              ],
            ),
          ),
          _buildCountdownWidget(const Color(0xFF00ADB5), const Color(0xFF222831)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getRoomLeaderboardStream(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No room scores yet.', style: TextStyle(color: Colors.grey)));
                }

                final rooms = snapshot.data!;
                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final rank = index + 1;
                    final item = rooms[index];
                    final String roomId = item['roomId'];
                    final int score = item['score'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('audio_rooms_v2').doc(roomId).get(),
                      builder: (context, roomSnap) {
                        String roomName = 'Room $roomId';
                        String roomAvatar = '';
                        if (roomSnap.hasData && roomSnap.data != null && roomSnap.data!.exists) {
                          final data = roomSnap.data!.data() as Map<String, dynamic>;
                          roomName = data['title'] ?? data['name'] ?? roomName;
                          roomAvatar = data['imageUrl'] ?? data['thumbnailUrl'] ?? '';
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.1), width: 1),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : rank == 3 ? Colors.brown[300] : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.teal[900],
                                backgroundImage: roomAvatar.isNotEmpty ? CachedNetworkImageProvider(roomAvatar) : null,
                                child: roomAvatar.isEmpty ? const Icon(Icons.home_filled, color: Colors.cyanAccent, size: 20) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.diamond, color: Colors.cyanAccent, size: 12),
                                        const SizedBox(width: 2),
                                        Text('$score diamonds', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                                  foregroundColor: Colors.cyanAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: const BorderSide(color: Colors.cyanAccent, width: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _joinRoom(roomId),
                                child: const Text('Join Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. TOP ACTIVE VIEW (Fallback Legacy layout)
  Widget _buildTopActiveView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF241A07), Color(0xFF181105), Color(0xFF0C0902)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: Colors.orange[900]!.withValues(alpha: 0.2),
              child: const Icon(Icons.flash_on, color: Colors.orangeAccent, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton('Rules', Icons.description, _showRulesDialog, Colors.orangeAccent),
              ],
            ),
          ),
          _buildCountdownWidget(const Color(0xFFF08A5D), const Color(0xFFB83B5E)),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: Colors.orangeAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orangeAccent,
            tabs: const [
              Tab(text: 'Active Rooms'),
              Tab(text: 'Active Users'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveRoomsTab(),
                _buildActiveUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoomsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('audio_rooms_v2').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No active rooms found.', style: TextStyle(color: Colors.grey)));
        }

        final List<AudioRoomV2> rooms = snapshot.data!.docs
            .map((doc) => AudioRoomV2.fromFirestore(doc))
            .toList();

        rooms.sort((a, b) => b.participants.length.compareTo(a.participants.length));

        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final rank = index + 1;
            final room = rooms[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? Colors.orangeAccent : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange[900],
                    backgroundImage: (room.imageUrl != null && room.imageUrl!.isNotEmpty) ? CachedNetworkImageProvider(room.imageUrl!) : null,
                    child: (room.imageUrl == null || room.imageUrl!.isEmpty) ? const Icon(Icons.volume_up, color: Colors.orangeAccent) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${room.participants.length} users online',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _joinRoom(room.id),
                    child: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveUsersTab() {
    final List<Map<String, dynamic>> mockActive = [
      {'userId': 'usr1', 'userName': 'Hyper_Speaker 🎙️', 'score': '124 Hours', 'userAvatar': ''},
      {'userId': 'usr2', 'userName': 'Chatty_Cat 😺', 'score': '98 Hours', 'userAvatar': ''},
      {'userId': 'usr3', 'userName': 'Music_Lover 🎵', 'score': '87 Hours', 'userAvatar': ''},
      {'userId': 'usr4', 'userName': 'Silent_Listener 🎧', 'score': '75 Hours', 'userAvatar': ''},
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(mockActive));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView.builder(
      itemCount: mockActive.length,
      itemBuilder: (context, index) {
        final rank = index + 1;
        final user = mockActive[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$rank', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              ),
              const CircleAvatar(
                radius: 20,
                child: Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['userName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Active Speaker Time: ${user['score']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                  ],
                ),
              ),
              if (user['userId'] != currentUserId)
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    child: FollowButton(
                      currentUserId: currentUserId,
                      targetUserId: user['userId'],
                      targetUserName: user['userName'],
                      followController: _followController,
                      textColor: Colors.orangeAccent,
                      borderColor: Colors.orangeAccent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getGameLeaderboardStream({required String gameName, required int limit}) {
    if (_event == null) return const Stream.empty();
    
    final eventPrefix = _event!.id.replaceAll('-', '_');
    final gameType = gameName == 'Greedy Game' ? 'greedy_game' : 'fruit_wheel';
    final orderByField = 'event_${eventPrefix}_$gameType';

    return FirebaseFirestore.instance
        .collection('leaderboard_stats')
        .where(orderByField, isGreaterThan: 0)
        .orderBy(orderByField, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final List<Map<String, dynamic>> sortedList = [];
          
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final String userId = doc.id;
              final int score = data[orderByField] ?? 0;
              
              if (_event!.hasRegistrationForm && !_registeredUserIds.contains(userId)) {
                continue;
              }
              
              sortedList.add({
                'userId': userId,
                'userName': 'User',
                'userAvatar': '',
                'score': score,
              });
            } catch (e) {
              debugPrint('Error parsing game leaderboard stats: $e');
            }
          }
            
          return sortedList;
        });
  }

  Widget _buildGameLeaderboardTab({required String gameName, required Color activeColor}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getGameLeaderboardStream(gameName: gameName, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final dataList = snapshot.data ?? [];
        if (dataList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, color: Colors.grey.withValues(alpha: 0.5), size: 64),
                const SizedBox(height: 16),
                const Text('No players ranked yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(dataList));

        final top3 = dataList.take(3).toList();
        final rest = dataList.skip(3).toList();

        return Column(
          children: [
            _buildPodium(top3),
            Expanded(
              child: ListView.builder(
                itemCount: rest.length,
                itemBuilder: (context, index) {
                  final rank = index + 4;
                  final user = rest[index];
                  return _buildRankRow(rank, user);
                },
              ),
            ),
            _buildCurrentUserRankBar(
              list: dataList, 
              activeColor: activeColor, 
              orderByField: 'event_${_event!.id.replaceAll('-', '_')}_${gameName == 'Greedy Game' ? 'greedy_game' : 'fruit_wheel'}'
            ),
          ],
        );
      },
    );
  }



  Widget _buildQuickActionButton(String text, IconData icon, VoidCallback onTap, Color activeColor) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: activeColor, size: 20),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab({required bool isSender, required Color activeColor}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getLeaderboardStream(isSender: isSender, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: activeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No rank data yet.', style: TextStyle(color: Colors.grey)));
        }
        
        final list = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatuses(list));
        
        final top3 = list.take(3).toList();
        final rest = list.skip(3).toList();
        
        return Column(
          children: [
            _buildPodium(top3),
            Expanded(
              child: ListView.builder(
                itemCount: rest.length,
                itemBuilder: (context, index) {
                  final rank = index + 4;
                  final user = rest[index];
                  return _buildRankRow(rank, user);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color bgColor = isDarkMode ? Colors.black : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          iconTheme: IconThemeData(color: textColor),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          iconTheme: IconThemeData(color: textColor),
          elevation: 0,
        ),
        body: Center(
          child: Text('Event not found or expired', style: TextStyle(color: textColor, fontSize: 16)),
        ),
      );
    }

    // Dynamic Visual Blocks Layout Rendering
    if (_event!.layoutBlocks.isNotEmpty) {
      return _buildDynamicBlockLayout(context);
    }

    // Fallback standard templates (backward compatibility)
    if (_event!.eventType == 'weekly_star') {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0B21),
        appBar: AppBar(
          title: Text(_event!.eventName, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F0B21),
          iconTheme: const IconThemeData(color: Colors.amber),
          elevation: 0,
        ),
        body: _buildWeeklyStarView(),
      );
    } else if (_event!.eventType == 'game_star') {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1E29),
        appBar: AppBar(
          title: Text(_event!.eventName, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F1E29),
          iconTheme: const IconThemeData(color: Colors.amberAccent),
          elevation: 0,
        ),
        body: _buildGameStarView(),
      );
    } else if (_event!.eventType == 'gifter_receiver') {
      return Scaffold(
        backgroundColor: const Color(0xFF260D1E),
        appBar: AppBar(
          title: Text(_event!.eventName, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF260D1E),
          iconTheme: const IconThemeData(color: Colors.pinkAccent),
          elevation: 0,
        ),
        body: _buildGifterReceiverView(),
      );
    } else if (_event!.eventType == 'top_room') {
      return Scaffold(
        backgroundColor: const Color(0xFF072124),
        appBar: AppBar(
          title: Text(_event!.eventName, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF072124),
          iconTheme: const IconThemeData(color: Colors.cyanAccent),
          elevation: 0,
        ),
        body: _buildTopRoomView(),
      );
    } else if (_event!.eventType == 'top_active') {
      return Scaffold(
        backgroundColor: const Color(0xFF241A07),
        appBar: AppBar(
          title: Text(_event!.eventName, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF241A07),
          iconTheme: const IconThemeData(color: Colors.orangeAccent),
          elevation: 0,
        ),
        body: _buildTopActiveView(),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_event!.eventName, style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: Column(
        children: [
          CachedNetworkImage(
            imageUrl: _event!.banner,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorWidget: (context, url, error) => Container(padding: const EdgeInsets.symmetric(vertical: 40), color: Colors.grey[300], child: const Icon(Icons.event, size: 60)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple[700]!, Colors.blue[600]!]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.white),
                const SizedBox(width: 8),
                ValueListenableBuilder<Duration>(
                  valueListenable: _timeLeftNotifier,
                  builder: (context, timeLeft, _) {
                    return Text(
                      'Ends in: ${_formatDuration(timeLeft)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Rules'),
              Tab(text: 'Rewards'),
              Tab(text: 'Ranking'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(_event!.description, style: TextStyle(color: textColor, fontSize: 16)),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(_event!.rules, style: TextStyle(color: textColor, fontSize: 16)),
                ),
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _event!.rewards.length,
                  itemBuilder: (context, index) {
                    final reward = _event!.rewards[index];
                    return Card(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: reward['fileUrl'] != null 
                          ? CachedNetworkImage(imageUrl: reward['fileUrl'], width: 40, height: 40)
                          : const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white)),
                        title: Text('${reward['rank'] != null ? '[${reward['rank']}] ' : ''}${reward['itemName'] ?? reward['category'] ?? 'Reward'}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          reward['itemId'] != null ? 'Duration: ${reward['amount'] == 0 ? 'Permanent' : '${reward['amount']} Days'}' : 'Amount: ${reward['amount'] ?? 0}',
                          style: TextStyle(color: Colors.grey[600])
                        ),
                      ),
                    );
                  },
                ),
                const Center(child: Text('Leaderboard coming soon')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: (_event!.hasRegistrationForm && !_registeredUserIds.contains(FirebaseAuth.instance.currentUser?.uid ?? ''))
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Register for Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCurrentUserRankBar({required List<Map<String, dynamic>> list, required Color activeColor, required String orderByField}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Check if user is in the list
    int rank = -1;
    Map<String, dynamic>? userData;
    for (int i = 0; i < list.length; i++) {
      if (list[i]['userId'] == uid) {
        rank = i + 1;
        userData = list[i];
        break;
      }
    }

    if (rank != -1 && userData != null) {
      return _buildStickyRankBar(rank, userData, activeColor);
    }

    // User is not in the top N list. We must fetch their score and calculate rank.
    return FutureBuilder<int>(
      future: _calculateUserRank(uid, orderByField),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final calculatedRank = snapshot.data!;
        if (calculatedRank <= 0) return const SizedBox.shrink(); // No score yet
        
        return FutureBuilder<DocumentSnapshot>(
           future: FirebaseFirestore.instance.collection('leaderboard_stats').doc(uid).get(),
           builder: (ctx, docSnap) {
             if (!docSnap.hasData || !docSnap.data!.exists) return const SizedBox.shrink();
             final score = docSnap.data!.get(orderByField) ?? 0;
             final Map<String, dynamic> fakeUser = {
               'userId': uid,
               'userName': 'Me',
               'userAvatar': FirebaseAuth.instance.currentUser?.photoURL ?? '',
               'score': score,
             };
             return _buildStickyRankBar(calculatedRank, fakeUser, activeColor);
           }
        );
      }
    );
  }

  Future<int> _calculateUserRank(String uid, String orderByField) async {
     try {
       final doc = await FirebaseFirestore.instance.collection('leaderboard_stats').doc(uid).get();
       if (!doc.exists) return 0;
       final int score = doc.data()?[orderByField] ?? 0;
       if (score <= 0) return 0;
       
       final countQuery = await FirebaseFirestore.instance
           .collection('leaderboard_stats')
           .where(orderByField, isGreaterThan: score)
           .count()
           .get();
       return countQuery.count! + 1; // Rank is number of people with strictly greater score + 1
     } catch (e) {
       return 0;
     }
  }

  Widget _buildStickyRankBar(int rank, Map<String, dynamic> user, Color activeColor) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String userId = user['userId'] ?? currentUserId;

    final future = _userFuturesCache.putIfAbsent(
      userId,
      () => FirebaseFirestore.instance.collection('Users').doc(userId).get(),
    );

    return FutureBuilder<DocumentSnapshot?>(
      future: future,
      builder: (context, snapshot) {
        String name = user['userName'] ?? 'Me';
        String avatar = user['userAvatar'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['fullname'] ?? data['userName'] ?? data['name'] ?? name;
          avatar = data['photoUrl'] ?? data['imageUrl'] ?? data['profileImageUrl'] ?? data['avatar'] ?? data['image'] ?? data['profile_picture'] ?? avatar;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activeColor.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: InkWell(
            onTap: () {
              if (userId.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfilePageForRoom(
                      userID: userId,
                      userName: name,
                      userImage: avatar,
                    ),
                  ),
                );
              }
            },
            child: Row(
              children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.diamond, color: activeColor, size: 12),
                        const SizedBox(width: 4),
                        Text('${user['score'] ?? 0}', style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const Text(
                'My Rank',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
    );
  }
}

