import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/relationship_service.dart';
import 'package:chat_messenger/widgets/relationship_badge_widget.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';

class IntimacyListPage extends StatefulWidget {
  final String userID;
  final String userName;
  final String userImage;
  final List<Map<String, dynamic>> relationships;

  const IntimacyListPage({
    super.key,
    required this.userID,
    required this.userName,
    this.userImage = '',
    this.relationships = const [],
  });

  @override
  State<IntimacyListPage> createState() => _IntimacyListPageState();
}

class _IntimacyListPageState extends State<IntimacyListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _relationshipsList = [];
  bool _isLoading = true;

  // Level thresholds list for progress calculation
  final List<int> _levelThresholds = [
    0,
    100,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _relationshipsList = List.from(widget.relationships);
    _fetchFullRelationships();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFullRelationships() async {
    setState(() => _isLoading = true);

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
          _relationshipsList = loadedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching full relationships: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Calculate total cumulative intimacy points
  int get _totalIntimacyPoints {
    int total = 0;
    for (var r in _relationshipsList) {
      final int pts = (r['intimacyPoints'] as num?)?.toInt() ??
          (r['couplePoints'] as num?)?.toInt() ??
          (r['friendshipPoints'] as num?)?.toInt() ??
          0;
      total += pts;
    }
    return total;
  }

  List<Map<String, dynamic>> get _couplesList {
    return _relationshipsList
        .where((r) =>
            r['relationshipType']?.toString().toLowerCase() == 'couple')
        .toList();
  }

  List<Map<String, dynamic>> get _friendsList {
    return _relationshipsList
        .where((r) =>
            r['relationshipType']?.toString().toLowerCase() != 'couple')
        .toList();
  }

  // Calculate level progress
  Map<String, dynamic> _calculateProgress(int currentLevel, int currentPoints) {
    int currentLevelIndex = currentLevel - 1;
    if (currentLevelIndex < 0) currentLevelIndex = 0;

    int minPointsForCurrentLvl = 0;
    int maxPointsForNextLvl = 100;

    if (currentLevelIndex < _levelThresholds.length) {
      minPointsForCurrentLvl = _levelThresholds[currentLevelIndex];
    } else {
      minPointsForCurrentLvl = _levelThresholds.last;
    }

    if (currentLevelIndex + 1 < _levelThresholds.length) {
      maxPointsForNextLvl = _levelThresholds[currentLevelIndex + 1];
    } else {
      maxPointsForNextLvl = minPointsForCurrentLvl + 50000;
    }

    int range = maxPointsForNextLvl - minPointsForCurrentLvl;
    if (range <= 0) range = 1;

    int progressInLevel = currentPoints - minPointsForCurrentLvl;
    if (progressInLevel < 0) progressInLevel = 0;
    if (progressInLevel > range) progressInLevel = range;

    double percent = progressInLevel / range;

    return {
      'currentLevel': currentLevel,
      'nextLevel': currentLevel + 1,
      'minPoints': minPointsForCurrentLvl,
      'nextTargetPoints': maxPointsForNextLvl,
      'percent': percent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Intimacy Wall',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEC407A),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'All (${_relationshipsList.length})'),
            Tab(text: 'Couple (${_couplesList.length})'),
            Tab(text: 'Friend (${_friendsList.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEC407A)),
            )
          : Column(
              children: [
                // Header Summary Card
                _buildHeaderSummaryCard(),
                
                // Tab View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRelationshipListView(_relationshipsList, 'all'),
                      _buildRelationshipListView(_couplesList, 'couple'),
                      _buildRelationshipListView(_friendsList, 'friend'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.white24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: widget.userImage.isNotEmpty && widget.userImage.startsWith('http')
                  ? Image.network(widget.userImage, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Total Gift Points: $_totalIntimacyPoints',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_relationshipsList.length} Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipListView(
      List<Map<String, dynamic>> list, String typeFilter) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              typeFilter == 'couple' ? Icons.favorite_border : Icons.people_outline,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              typeFilter == 'couple'
                  ? 'No Couple relationship active yet.'
                  : typeFilter == 'friend'
                      ? 'No Friend intimacy relationship active yet.'
                      : 'No intimacy relationships found.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildRelationshipCard(list[index]);
      },
    );
  }

  Widget _buildRelationshipCard(Map<String, dynamic> rel) {
    final String otherName = rel['otherUserFullname'] ?? 'User';
    final String otherPhoto = rel['otherUserPhotoUrl'] ?? '';
    final String otherSearchId = rel['otherUserSearchId'] ?? '';
    final String otherId = rel['otherUserId'] ?? '';
    final String type = rel['relationshipType']?.toString().toLowerCase() ?? 'friend';
    final bool isCouple = type == 'couple';

    final int currentLevel = (rel['currentLevel'] as num?)?.toInt() ?? 1;
    final int points = (rel['intimacyPoints'] as num?)?.toInt() ??
        (rel['couplePoints'] as num?)?.toInt() ??
        (rel['friendshipPoints'] as num?)?.toInt() ??
        0;

    final progressData = _calculateProgress(currentLevel, points);
    final double percent = progressData['percent'];
    final int nextTarget = progressData['nextTargetPoints'];

    String formattedDate = '';
    final createdAt = rel['createdAt'];
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('dd MMM yyyy').format(createdAt.toDate());
    }

    final cardBgColor = const Color(0xFF1E293B);
    final badgeColor = isCouple ? const Color(0xFFEC407A) : const Color(0xFF42A5F5);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Level Badge / Ornament
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (otherId.isNotEmpty) {
                        Get.to(() => ProfilePageForRoom(
                              userID: otherId,
                              userName: otherName,
                              userImage: otherPhoto,
                            ));
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: badgeColor, width: 2),
                        color: Colors.white10,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: otherPhoto.startsWith('http')
                            ? Image.network(otherPhoto, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.person, color: Colors.grey))
                            : const Icon(Icons.person, color: Colors.grey, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: RelationshipBadgeWidget(
                      level: currentLevel,
                      relationshipType: type,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // User Info & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Relationship Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: badgeColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCouple ? Icons.favorite : Icons.handshake,
                                color: badgeColor,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCouple ? 'Couple' : 'Friend',
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 3-dots Menu for Remove option
                        if (_canRemoveRelationship(otherId, rel)) ...[
                          const SizedBox(width: 4),
                          Theme(
                            data: Theme.of(context).copyWith(
                              cardColor: const Color(0xFF1E293B),
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white70,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              onSelected: (value) {
                                if (value == 'remove') {
                                  _confirmRemoveRelationship(rel);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  height: 40,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Remove Intimacy',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (otherSearchId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: $otherSearchId',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade900.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Lv.$currentLevel',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🎁 $points Gift Pts',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (formattedDate.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar to Next Level
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level Progress',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                  Text(
                    '$points / $nextTarget Pts (${(percent * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (otherId.isNotEmpty) {
                      Get.to(() => ProfilePageForRoom(
                            userID: otherId,
                            userName: otherName,
                            userImage: otherPhoto,
                          ));
                    }
                  },
                  icon: const Icon(Icons.person, size: 14, color: Colors.white70),
                  label: const Text('View Profile',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  bool _canRemoveRelationship(String otherId, Map<String, dynamic> rel) {
    try {
      final currentUserId = AuthController.instance.currentUser.userId;
      if (currentUserId == widget.userID || currentUserId == otherId) {
        return true;
      }
      final u1 = rel['user1Ref'];
      final u2 = rel['user2Ref'];
      final u1Id = u1 is DocumentReference ? u1.id : u1?.toString();
      final u2Id = u2 is DocumentReference ? u2.id : u2?.toString();
      return currentUserId == u1Id || currentUserId == u2Id;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmRemoveRelationship(Map<String, dynamic> rel) async {
    final String relId = rel['id'] ?? '';
    final String otherName = rel['otherUserFullname'] ?? 'User';
    final String type =
        rel['relationshipType']?.toString().toLowerCase() == 'couple'
            ? 'Couple'
            : 'Friend';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove $type Intimacy',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove the $type intimacy relationship with $otherName? All accumulated intimacy points and level progress for this relationship will be removed.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && relId.isNotEmpty) {
      try {
        await RelationshipService().removeRelationship(relId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$type intimacy relationship with $otherName removed'),
              backgroundColor: Colors.redAccent,
            ),
          );
          _fetchFullRelationships();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove relationship: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

