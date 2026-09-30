import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/screens/room/family_screen.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';

// ─── Number Formatter ────────────────────────────────────────────────────────
String formatRankingScore(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)}K';
  }
  return value.toString();
}

String getCountryFlagEmoji(String? countryCode) {
  if (countryCode == null || countryCode.length != 2) return '';
  final upper = countryCode.toUpperCase();
  final int first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final int second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  if (first < 0x1F1E6 || first > 0x1F1FF || second < 0x1F1E6 || second > 0x1F1FF) {
    return '';
  }
  return String.fromCharCode(first) + String.fromCharCode(second);
}

enum RankingCategory { wealth, charm, room, family }
enum RankingPeriod { daily, weekly, monthly }

// ─── Generic Leaderboard Entry ──────────────────────────────────────────────
class _LeaderboardEntry {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final int amount;
  final String? gender;
  final String? country;
  final int? sendingLevel;
  final int? receivingLevel;
  final String? customId;
  final dynamic rawData;

  _LeaderboardEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    required this.amount,
    this.gender,
    this.country,
    this.sendingLevel,
    this.receivingLevel,
    this.customId,
    this.rawData,
  });
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class RoomTopRankingsScreen extends StatefulWidget {
  final AudioRoomsBloc audioRoomsBloc;
  const RoomTopRankingsScreen({super.key, required this.audioRoomsBloc});

  @override
  State<RoomTopRankingsScreen> createState() => _RoomTopRankingsScreenState();
}

class _RoomTopRankingsScreenState extends State<RoomTopRankingsScreen>
    with SingleTickerProviderStateMixin {
  RankingCategory _category = RankingCategory.charm; // Default to Charm as in screenshot
  RankingPeriod _period = RankingPeriod.daily;

  final AppThemeService _themeService = Get.find<AppThemeService>();
  final ValueNotifier<int?> _currentUserRank = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _currentUserScore = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _currentUserRank.dispose();
    _currentUserScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1C),
      body: Stack(
        children: [
          // Background Palace / Stage Image or Vector Royal Hall
          Positioned.fill(
            child: _buildScreenBackground(),
          ),

          // Main Scrollable Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top App Bar & Category Tabs
                _buildTopBar(),

                // Time Period Selector (Day, Week, Month)
                _buildPeriodPills(),

                // Dynamic Leaderboard Body
                Expanded(
                  child: _buildLeaderboardContent(),
                ),

                // Bottom Fixed User Status Bar
                _buildCurrentUserBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Background ────────────────────────────────────────────────────────────
  Widget _buildScreenBackground() {
    return Obx(() {
      final customBg = _themeService.leaderboardBgUrl.value;
      if (customBg.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: customBg,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildDefaultPalaceBackground(),
          errorWidget: (_, __, ___) => _buildDefaultPalaceBackground(),
        );
      }
      return _buildDefaultPalaceBackground();
    });
  }

  Widget _buildDefaultPalaceBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF241038),
            Color(0xFF190B2A),
            Color(0xFF0F071A),
            Color(0xFF0A0413),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Royal Spotlight glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.4),
                  radius: 0.9,
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.12),
                    const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Arch & drape accents
          Positioned(
            top: 0,
            left: -30,
            child: Opacity(
              opacity: 0.25,
              child: Container(
                width: 120,
                height: 320,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6A1B9A), Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(100),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: -30,
            child: Opacity(
              opacity: 0.25,
              child: Container(
                width: 120,
                height: 320,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6A1B9A), Colors.transparent],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top App Bar & Category Tabs ───────────────────────────────────────────
  Widget _buildTopBar() {
    final categories = [
      {'cat': RankingCategory.wealth, 'label': 'Wealth'},
      {'cat': RankingCategory.charm, 'label': 'Charm'},
      {'cat': RankingCategory.room, 'label': 'Room'},
      {'cat': RankingCategory.family, 'label': 'Family'},
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 4, bottom: 6),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Categories Tabs
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: categories.map((c) {
                final cat = c['cat'] as RankingCategory;
                final label = c['label'] as String;
                final isSelected = _category == cat;

                return GestureDetector(
                  onTap: () {
                    if (_category != cat) {
                      setState(() => _category = cat);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: isSelected ? 17 : 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Indicator dot or line
                        Container(
                          width: isSelected ? 16 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                                      blurRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Time Period Pills (Day, Week, Month) ───────────────────────────────────
  Widget _buildPeriodPills() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF201335).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillItem('Day', RankingPeriod.daily),
          _buildPillItem('Week', RankingPeriod.weekly),
          _buildPillItem('Month', RankingPeriod.monthly),
        ],
      ),
    );
  }

  Widget _buildPillItem(String label, RankingPeriod period) {
    final isSelected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_period != period) {
            setState(() => _period = period);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF160B24) : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Leaderboard Data Stream ───────────────────────────────────────────────
  Widget _buildLeaderboardContent() {
    switch (_category) {
      case RankingCategory.wealth:
        return _buildUsersLeaderboard(useReceiving: false);
      case RankingCategory.charm:
        return _buildUsersLeaderboard(useReceiving: true);
      case RankingCategory.room:
        return _buildRoomsLeaderboard();
      case RankingCategory.family:
        return _buildFamiliesLeaderboard();
    }
  }

  // ─── Users Stream (Wealth / Charm) ─────────────────────────────────────────
  Widget _buildUsersLeaderboard({required bool useReceiving}) {
    String queryField = '';
    String fallbackField = '';

    if (useReceiving) {
      fallbackField = 'receivingLevel.totalExp';
      switch (_period) {
        case RankingPeriod.daily:
          queryField = 'dailyDiamondsReceived_${RankingHelper.dailySuffix}';
          break;
        case RankingPeriod.weekly:
          queryField = 'weeklyDiamondsReceived_${RankingHelper.weeklySuffix}';
          break;
        case RankingPeriod.monthly:
          queryField = 'monthlyDiamondsReceived_${RankingHelper.monthlySuffix}';
          break;
      }
    } else {
      fallbackField = 'sendingLevel.totalExp';
      switch (_period) {
        case RankingPeriod.daily:
          queryField = 'dailyDiamondsSent_${RankingHelper.dailySuffix}';
          break;
        case RankingPeriod.weekly:
          queryField = 'weeklyDiamondsSent_${RankingHelper.weeklySuffix}';
          break;
        case RankingPeriod.monthly:
          queryField = 'monthlyDiamondsSent_${RankingHelper.monthlySuffix}';
          break;
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .orderBy(queryField, descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        if (snapshot.hasError) {
          // Fallback to totalExp/totalDiamonds if current period fields are empty or not indexed
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .orderBy(fallbackField, descending: true)
                .limit(30)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }
              final docs = snap.data?.docs ?? [];
              final entries = _parseUserDocs(docs, fallbackField, isFallback: true);
              return _buildRankingsList(entries);
            },
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final entries = _parseUserDocs(docs, queryField, isFallback: false);
        return _buildRankingsList(entries);
      },
    );
  }

  List<_LeaderboardEntry> _parseUserDocs(
      List<QueryDocumentSnapshot> docs, String field, {bool isFallback = false}) {
    final list = <_LeaderboardEntry>[];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      int amount = 0;

      if (isFallback) {
        if (_category == RankingCategory.charm) {
          amount = ((data['receivingLevel'] as Map<String, dynamic>?)?['totalExp'] as num?)?.toInt() ??
              (data['beans'] as num?)?.toInt() ??
              0;
        } else {
          amount = ((data['sendingLevel'] as Map<String, dynamic>?)?['totalExp'] as num?)?.toInt() ??
              (data['totalDiamonds'] as num?)?.toInt() ??
              0;
        }
      } else {
        amount = (data[field] as num?)?.toInt() ?? 0;
      }

      if (amount <= 0 && docs.length > 5) {
        // Skip zero values if list has enough entries
        continue;
      }

      final sendingLvl = ((data['sendingLevel'] as Map<String, dynamic>?)?['level'] as num?)?.toInt();
      final receivingLvl = ((data['receivingLevel'] as Map<String, dynamic>?)?['level'] as num?)?.toInt();

      list.add(_LeaderboardEntry(
        id: doc.id,
        title: data['fullname'] as String? ?? 'User',
        avatarUrl: data['photoUrl'] as String?,
        amount: amount,
        gender: data['gender'] as String?,
        country: data['country'] as String?,
        sendingLevel: sendingLvl,
        receivingLevel: receivingLvl,
        customId: data['searchId'] as String?,
        rawData: data,
      ));
    }
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // ─── Rooms Stream ──────────────────────────────────────────────────────────
  Widget _buildRoomsLeaderboard() {
    String queryField = '';
    const String fallbackField = 'totalRevenue';

    switch (_period) {
      case RankingPeriod.daily:
        queryField = 'dailyRevenue_${RankingHelper.dailySuffix}';
        break;
      case RankingPeriod.weekly:
        queryField = 'weeklyRevenue_${RankingHelper.weeklySuffix}';
        break;
      case RankingPeriod.monthly:
        queryField = 'monthlyRevenue_${RankingHelper.monthlySuffix}';
        break;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .orderBy(queryField, descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        if (snapshot.hasError) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('audio_rooms_v2')
                .orderBy(fallbackField, descending: true)
                .limit(30)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }
              final docs = snap.data?.docs ?? [];
              return _buildRankingsList(_parseRoomDocs(docs, fallbackField));
            },
          );
        }

        final docs = snapshot.data?.docs ?? [];
        return _buildRankingsList(_parseRoomDocs(docs, queryField));
      },
    );
  }

  List<_LeaderboardEntry> _parseRoomDocs(List<QueryDocumentSnapshot> docs, String field) {
    final list = <_LeaderboardEntry>[];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final room = AudioRoomV2.fromFirestore(doc);
      if (room.isGroupRoom || room.excludeFromRanking || room.isPrivate) continue;

      final amount = (data[field] as num?)?.toInt() ?? 0;
      list.add(_LeaderboardEntry(
        id: room.id,
        title: room.name,
        subtitle: 'Host: ${room.creatorName}',
        avatarUrl: room.imageUrl,
        amount: amount,
        rawData: room,
      ));
    }
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // ─── Families Stream ───────────────────────────────────────────────────────
  Widget _buildFamiliesLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .orderBy('flame_points', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        final docs = snapshot.data?.docs ?? [];
        final list = <_LeaderboardEntry>[];
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final int flame = (data['flame_points'] as num?)?.toInt() ?? 
                            (data['totalDiamonds'] as num?)?.toInt() ?? 
                            ((data['member_count'] as num?)?.toInt() ?? 0) * 100;
          list.add(_LeaderboardEntry(
            id: doc.id,
            title: data['family_name'] as String? ?? 'Family',
            subtitle: 'Members: ${data['member_count'] ?? 1}',
            avatarUrl: data['cover_image'] as String?,
            amount: flame,
            rawData: data,
          ));
        }
        list.sort((a, b) => b.amount.compareTo(a.amount));
        return _buildRankingsList(list);
      },
    );
  }

  // ─── Unified Rankings View (Podium + Scrollable List) ──────────────────────
  Widget _buildRankingsList(List<_LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No rankings data available',
          style: TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    // Determine current user rank and score in this leaderboard view
    final currentUid = AuthController.instance.currentUser.userId;
    final index = entries.indexWhere((e) => e.id == currentUid);
    final userRank = index >= 0 ? index + 1 : null;
    final userScore = index >= 0 ? entries[index].amount : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_currentUserRank.value != userRank) {
          _currentUserRank.value = userRank;
        }
        if (_currentUserScore.value != userScore) {
          _currentUserScore.value = userScore;
        }
      }
    });

    final top1 = entries.isNotEmpty ? entries[0] : null;
    final top2 = entries.length > 1 ? entries[1] : null;
    final top3 = entries.length > 2 ? entries[2] : null;

    final remaining = entries.length > 3 ? entries.sublist(3) : <_LeaderboardEntry>[];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      children: [
        // Top 3 Podium Presentation
        _buildPodiumSection(top1: top1, top2: top2, top3: top3),

        const SizedBox(height: 0),

        // Remaining ranks 4+ list
        if (remaining.isNotEmpty)
          ...remaining.asMap().entries.map((mapEntry) {
            final rank = mapEntry.key + 4;
            final entry = mapEntry.value;
            return _buildRankListItem(rank: rank, entry: entry);
          }),
      ],
    );
  }

  // ─── Top 3 Podium Section ──────────────────────────────────────────────────
  Widget _buildPodiumSection({
    required _LeaderboardEntry? top1,
    required _LeaderboardEntry? top2,
    required _LeaderboardEntry? top3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Transform.translate(
        offset: const Offset(0, 12),
        child: Column(
          children: [
            // Podium Items: Left = Top 2, Center = Top 1 (Elevated to top), Right = Top 3
            LayoutBuilder(
              builder: (context, constraints) {
                final double screenW = constraints.maxWidth;
                final double sideInset = (screenW > 380) ? 6.0 : 1.0;

                return SizedBox(
                  height: 360,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Top 2 (Left)
                      Positioned(
                        left: sideInset,
                        bottom: 0,
                        child: _buildPodiumItem(
                          rank: 2,
                          entry: top2,
                          bannerPrimaryColor: const Color(0xFF1E40AF),
                          bannerDarkColor: const Color(0xFF1E3A8A),
                          isTop1: false,
                        ),
                      ),

                      // Top 3 (Right)
                      Positioned(
                        right: sideInset,
                        bottom: 0,
                        child: _buildPodiumItem(
                          rank: 3,
                          entry: top3,
                          bannerPrimaryColor: const Color(0xFF047857),
                          bannerDarkColor: const Color(0xFF064E3B),
                          isTop1: false,
                        ),
                      ),

                      // Top 1 (Center, Elevated Highest right under the pills)
                      Positioned(
                        bottom: 90,
                        child: _buildPodiumItem(
                          rank: 1,
                          entry: top1,
                          bannerPrimaryColor: const Color(0xFF6B46C1),
                          bannerDarkColor: const Color(0xFF44337A),
                          isTop1: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Individual Podium Item (Large Frame containing Avatar in upper center, Name, Badges, & Diamonds) ───

  Widget _buildPodiumItem({
    required int rank,
    required _LeaderboardEntry? entry,
    Color bannerPrimaryColor = const Color(0xFF6B46C1),
    Color bannerDarkColor = const Color(0xFF44337A),
    bool isTop1 = false,
  }) {
    if (entry == null) {
      return const SizedBox.shrink();
    }

    final double itemWidth = isTop1 ? 192 : 146;
    final double itemHeight = isTop1 ? 342 : 275;

    // Avatar dimensions and top offsets calibrated so avatar fits snugly inside frame cut-out window
    final double avatarWidth = isTop1 ? 60 : 60;
    final double avatarHeight = isTop1 ? 67 : 60;
    final double avatarTop = isTop1 ? 93 : 78;

    return GestureDetector(
      onTap: () => _handleItemTap(entry),
      child: SizedBox(
        width: itemWidth,
        height: itemHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. User Profile Picture: Snugly centered inside the frame's empty cut-out window
            Positioned(
              top: avatarTop,
              child: Container(
                width: avatarWidth,
                height: avatarHeight,
                decoration: BoxDecoration(
                  shape: isTop1 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isTop1 ? BorderRadius.circular(6) : null,
                ),
                child: isTop1
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: entry.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _buildInitialsAvatar(entry.title),
                                errorWidget: (_, __, ___) => _buildInitialsAvatar(entry.title),
                              )
                            : _buildInitialsAvatar(entry.title),
                      )
                    : ClipOval(
                        child: (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: entry.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _buildInitialsAvatar(entry.title),
                                errorWidget: (_, __, ___) => _buildInitialsAvatar(entry.title),
                              )
                            : _buildInitialsAvatar(entry.title),
                      ),
              ),
            ),

            // 2. The Frame Graphic itself (Admin uploaded from Admin Panel or built-in fallback)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildRankFrame(rank),
              ),
            ),

            // 3. User Details: Name, Badges, and Real Wallet Diamonds
            Positioned(
              left: isTop1 ? 15 : 10,
              right: isTop1 ? 15 : 10,
              bottom: isTop1 ? 91 : 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Title + Gender + Country Flag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: (_category == RankingCategory.room || _category == RankingCategory.family)
                            ? Text(
                                entry.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              )
                            : AnimatedSvipName.fromUserId(
                                userId: entry.id,
                                defaultName: entry.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                      ),
                      if (entry.gender != null && entry.gender!.trim().isNotEmpty) ...[
                        const SizedBox(width: 2),
                        _buildGenderIcon(entry.gender!),
                      ],
                      if (entry.country != null && entry.country!.isNotEmpty) ...[
                        const SizedBox(width: 2),
                        Text(
                          getCountryFlagEmoji(entry.country),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Level Badges Row
                  if (entry.sendingLevel != null || entry.receivingLevel != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.sendingLevel != null)
                          _buildLevelShield('sending_config', entry.sendingLevel!, const Color(0xFF00E5FF)),
                        if (entry.sendingLevel != null && entry.receivingLevel != null)
                          const SizedBox(width: 3),
                        if (entry.receivingLevel != null)
                          _buildLevelShield('receiving_config', entry.receivingLevel!, const Color(0xFFFFB300)),
                      ],
                    )
                  else if (entry.rawData is AudioRoomV2)
                    StreamBuilder<DocumentSnapshot>(
                      stream: (entry.rawData as AudioRoomV2).creatorId.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('Users')
                              .doc((entry.rawData as AudioRoomV2).creatorId)
                              .snapshots()
                          : null,
                      builder: (context, userSnap) {
                        String hostName = (entry.rawData as AudioRoomV2).creatorName;
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData = userSnap.data!.data() as Map<String, dynamic>?;
                          if (uData != null &&
                              uData['fullname'] != null &&
                              uData['fullname'].toString().trim().isNotEmpty) {
                            hostName = uData['fullname'].toString().trim();
                          }
                        }
                        return Text(
                          'Host: $hostName',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    )
                  else if (entry.subtitle != null)
                    Text(
                      entry.subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 4),

                  // Diamond Count with Real Wallet Diamond Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DynamicDiamondIcon(
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatRankingScore(entry.amount),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Live Room Equalizer Indicator if currently live
            if (_category != RankingCategory.room && _category != RankingCategory.family)
              Positioned(
                top: isTop1 ? 76 : 52,
                right: isTop1 ? 20 : 14,
                child: ActiveRoomIndicator(
                  userId: entry.id,
                  audioRoomsBloc: widget.audioRoomsBloc,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Ornate Rank Frame (Admin Uploaded or Fallback Wings/Crown) ─────────────
  Widget _buildRankFrame(int rank) {
    return Obx(() {
      final categoryKey = _category == RankingCategory.charm ? 'receiver' : 'sender';
      final frameUrl = _themeService.getLeaderboardFrameUrl(categoryKey, rank);

      if (frameUrl != null && frameUrl.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: frameUrl,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _buildBuiltInOrnateFrame(rank),
        );
      }

      return _buildBuiltInOrnateFrame(rank);
    });
  }

  Widget _buildBuiltInOrnateFrame(int rank) {
    if (rank == 1) {
      return CustomPaint(
        painter: _BuiltInRankFramePainter(
          rank: 1,
          primaryColor: const Color(0xFFFFD54F),
          bannerColor: const Color(0xFF6B46C1),
          bannerDarkColor: const Color(0xFF44337A),
        ),
      );
    } else if (rank == 2) {
      return CustomPaint(
        painter: _BuiltInRankFramePainter(
          rank: 2,
          primaryColor: const Color(0xFFFFD54F),
          bannerColor: const Color(0xFF1E40AF),
          bannerDarkColor: const Color(0xFF1E3A8A),
        ),
      );
    } else {
      return CustomPaint(
        painter: _BuiltInRankFramePainter(
          rank: 3,
          primaryColor: const Color(0xFFFFD54F),
          bannerColor: const Color(0xFF047857),
          bannerDarkColor: const Color(0xFF064E3B),
        ),
      );
    }
  }

  // ─── Rank 4+ List Row ─────────────────────────────────────────────────────
  Widget _buildRankListItem({required int rank, required _LeaderboardEntry entry}) {
    return GestureDetector(
      onTap: () => _handleItemTap(entry),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF171026).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2C1E4A),
                  backgroundImage: (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(entry.avatarUrl!)
                      : null,
                  child: (entry.avatarUrl == null || entry.avatarUrl!.isEmpty)
                      ? _buildInitialsAvatar(entry.title)
                      : null,
                ),
                if (_category != RankingCategory.room && _category != RankingCategory.family)
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: ActiveRoomIndicator(
                      userId: entry.id,
                      audioRoomsBloc: widget.audioRoomsBloc,
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Title, Badges & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: (_category == RankingCategory.room || _category == RankingCategory.family)
                            ? Text(
                                entry.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : AnimatedSvipName.fromUserId(
                                userId: entry.id,
                                defaultName: entry.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (entry.gender != null && entry.gender!.trim().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _buildGenderIcon(entry.gender!),
                      ],
                      if (entry.country != null && entry.country!.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Text(
                          getCountryFlagEmoji(entry.country),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (entry.rawData is AudioRoomV2)
                    StreamBuilder<DocumentSnapshot>(
                      stream: (entry.rawData as AudioRoomV2).creatorId.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('Users')
                              .doc((entry.rawData as AudioRoomV2).creatorId)
                              .snapshots()
                          : null,
                      builder: (context, userSnap) {
                        String hostName = (entry.rawData as AudioRoomV2).creatorName;
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData = userSnap.data!.data() as Map<String, dynamic>?;
                          if (uData != null &&
                              uData['fullname'] != null &&
                              uData['fullname'].toString().trim().isNotEmpty) {
                            hostName = uData['fullname'].toString().trim();
                          }
                        }
                        return Text(
                          'Host: $hostName',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    )
                  else if (entry.subtitle != null)
                    Text(
                      entry.subtitle!,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (entry.sendingLevel != null || entry.receivingLevel != null)
                    Row(
                      children: [
                        if (entry.sendingLevel != null)
                          _buildLevelShield('sending_config', entry.sendingLevel!, const Color(0xFF00E5FF)),
                        if (entry.sendingLevel != null && entry.receivingLevel != null)
                          const SizedBox(width: 4),
                        if (entry.receivingLevel != null)
                          _buildLevelShield('receiving_config', entry.receivingLevel!, const Color(0xFFFFB300)),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Score with Real Wallet Diamond Icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DynamicDiamondIcon(
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  formatRankingScore(entry.amount),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Current User Sticky Bottom Bar ────────────────────────────────────────
  Widget _buildCurrentUserBar() {
    final currentUser = AuthController.instance.currentUser;
    final displayId = currentUser.searchId.isNotEmpty ? currentUser.searchId : currentUser.userId;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<int?>(
      valueListenable: _currentUserRank,
      builder: (context, userRank, _) {
        final hasRank = userRank != null;
        final rankText = hasRank ? '$userRank' : '99+';

        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: bottomInset > 0 ? bottomInset + 8 : 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1B112C),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Current User Rank (Shows actual current ranking: 1, 2, 3... or 99+)
              Container(
                constraints: const BoxConstraints(minWidth: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: hasRank && userRank <= 3
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          colors: userRank == 1
                              ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                              : userRank == 2
                                  ? [const Color(0xFF90CAF9), const Color(0xFF1E88E5)]
                                  : [const Color(0xFFA5D6A7), const Color(0xFF388E3C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (userRank == 1 ? const Color(0xFFFFD700) : Colors.white).withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  rankText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (hasRank && userRank <= 3) ? Colors.black : const Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // User Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF331D56),
                backgroundImage: (currentUser.photoUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(currentUser.photoUrl)
                    : null,
                child: (currentUser.photoUrl.isEmpty)
                    ? Text(
                        currentUser.fullname.isNotEmpty ? currentUser.fullname[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // User Name & ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentUser.fullname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    UserIdBadgeWidget(
                      searchId: displayId,
                      badgeHeight: 14,
                      textStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Current User Diamonds / Score
              ValueListenableBuilder<int?>(
                valueListenable: _currentUserScore,
                builder: (context, userScore, _) {
                  if (userScore == null || userScore <= 0) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DynamicDiamondIcon(
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatRankingScore(userScore),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildInitialsAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildGenderIcon(String gender) {
    final g = gender.trim().toLowerCase();
    final isMale = g == 'male' || g == 'boy' || g == 'man';
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isMale ? const Color(0xFF1E88E5) : const Color(0xFFE91E63),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMale ? Icons.male : Icons.female,
        color: Colors.white,
        size: 10,
      ),
    );
  }

  Widget _buildLevelShield(String configDoc, int levelNumber, Color fallbackColor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('level_configurations')
          .doc(configDoc)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['levels'] != null) {
            final levels = List<Map<String, dynamic>>.from(data['levels']);
            String? imageUrl;
            for (final lvl in levels) {
              if (lvl['levelNumber']?.toString() == levelNumber.toString()) {
                imageUrl = lvl['imageUrl'] as String?;
                break;
              }
            }
            if (imageUrl != null && imageUrl.isNotEmpty) {
              return CachedNetworkImage(
                imageUrl: imageUrl,
                height: 13,
                fit: BoxFit.contain,
              );
            }
          }
        }

        // Fallback Shield Badge with level number
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: fallbackColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fallbackColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield, color: fallbackColor, size: 9),
              const SizedBox(width: 2),
              Text(
                '$levelNumber',
                style: TextStyle(
                  color: fallbackColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleItemTap(_LeaderboardEntry entry) {
    if (_category == RankingCategory.room) {
      if (entry.rawData is AudioRoomV2) {
        _enterRoom(entry.rawData as AudioRoomV2);
      }
    } else if (_category == RankingCategory.family) {
      final currentUser = AuthController.instance.currentUser;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FamilyScreen(currentUser: currentUser),
        ),
      );
    } else {
      // User Profile
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfilePageForRoom(
            userID: entry.id,
            userName: entry.title,
            userImage: entry.avatarUrl ?? '',
          ),
        ),
      );
    }
  }

  void _enterRoom(AudioRoomV2 room) {
    final currentUser = AuthController.instance.currentUser;
    if (room.isUserBlocked(currentUser.userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are blocked from entering this room.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (room.isUserKickedRecently(currentUser.userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You have been removed from this room and cannot join for 24 hours.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    MinimizedRoomController.checkAndProceed(
      context: context,
      targetRoom: room,
      onProceed: () {
        if (!room.isParticipant(currentUser.userId)) {
          widget.audioRoomsBloc.add(JoinAudioRoom(
            roomId: room.id,
            userId: currentUser.userId,
            userName: currentUser.fullname,
            userImageUrl: currentUser.photoUrl,
            userFrameId: currentUser.customization?.selectedFrameId,
          ));
        }

        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AudioRoomScreen(room: room, audioRoomsBloc: widget.audioRoomsBloc),
        ));
      },
    );
  }
}

// ─── Custom Frame Painter Fallback ──────────────────────────────────────────

/// Complete ornate frame fallback painter with wings/crest at top, circular avatar window, and lower banner body
class _BuiltInRankFramePainter extends CustomPainter {
  final int rank;
  final Color primaryColor;
  final Color bannerColor;
  final Color bannerDarkColor;

  _BuiltInRankFramePainter({
    required this.rank,
    required this.primaryColor,
    required this.bannerColor,
    required this.bannerDarkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isTop1 = rank == 1;
    final centerX = size.width / 2;
    final double avatarTop = isTop1 ? 93.0 : 78.0;
    final double avatarRadius = isTop1 ? 32.0 : 30.0;
    final double avatarCenterY = avatarTop + avatarRadius;

    // 1. Lower Banner Body (Shield with pointed tip at bottom)
    final bannerTop = avatarCenterY + avatarRadius - 4;
    final bannerPath = Path();
    const r = 8.0;
    final w = size.width;
    final h = size.height;

    bannerPath.moveTo(r, bannerTop);
    bannerPath.lineTo(w - r, bannerTop);
    bannerPath.quadraticBezierTo(w, bannerTop, w, bannerTop + r);
    bannerPath.lineTo(w, h - 14);
    bannerPath.lineTo(centerX, h);
    bannerPath.lineTo(0, h - 14);
    bannerPath.lineTo(0, bannerTop + r);
    bannerPath.quadraticBezierTo(0, bannerTop, r, bannerTop);
    bannerPath.close();

    final bannerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [bannerColor, bannerDarkColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, bannerTop, w, h - bannerTop));
    canvas.drawPath(bannerPath, bannerPaint);

    // Gold outline for banner
    final goldBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFEA79), Color(0xFFFFC107), Color(0xFFFFA000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, bannerTop, w, h - bannerTop));
    canvas.drawPath(bannerPath, goldBorderPaint);

    // 2. Avatar Gold Ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFEA79), Color(0xFFFFC107), Color(0xFFFFD54F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(centerX, avatarCenterY), radius: avatarRadius + 3));
    canvas.drawCircle(Offset(centerX, avatarCenterY), avatarRadius + 1.5, ringPaint);

    // 3. Ornate Wings & Crown / Crest
    final goldFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFEA79), Color(0xFFFFC107), Color(0xFFFFA000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, avatarTop + 10));

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFF9C4);

    if (isTop1) {
      // Crown at top
      final crownPath = Path();
      const topY = 4.0;
      crownPath.moveTo(centerX - 16, topY + 16);
      crownPath.lineTo(centerX - 18, topY + 2);
      crownPath.lineTo(centerX - 8, topY + 10);
      crownPath.lineTo(centerX, topY);
      crownPath.lineTo(centerX + 8, topY + 10);
      crownPath.lineTo(centerX + 18, topY + 2);
      crownPath.lineTo(centerX + 16, topY + 16);
      crownPath.close();
      canvas.drawPath(crownPath, goldFill);
      canvas.drawPath(crownPath, outlinePaint);

      // Red Gem in Crown
      canvas.drawCircle(Offset(centerX, topY + 8), 2.5, Paint()..color = const Color(0xFFE53935));

      // Left Spread Wing
      final leftWing = Path();
      leftWing.moveTo(centerX - 24, topY + 18);
      leftWing.quadraticBezierTo(centerX - 52, topY + 8, centerX - 62, topY + 32);
      leftWing.quadraticBezierTo(centerX - 48, topY + 38, centerX - 56, topY + 52);
      leftWing.quadraticBezierTo(centerX - 40, topY + 50, centerX - 26, topY + 52);
      leftWing.close();
      canvas.drawPath(leftWing, goldFill);
      canvas.drawPath(leftWing, outlinePaint);

      // Right Spread Wing
      final rightWing = Path();
      rightWing.moveTo(centerX + 24, topY + 18);
      rightWing.quadraticBezierTo(centerX + 52, topY + 8, centerX + 62, topY + 32);
      rightWing.quadraticBezierTo(centerX + 48, topY + 38, centerX + 56, topY + 52);
      rightWing.quadraticBezierTo(centerX + 40, topY + 50, centerX + 26, topY + 52);
      rightWing.close();
      canvas.drawPath(rightWing, goldFill);
      canvas.drawPath(rightWing, outlinePaint);

      // Rank 1 Medal Badge below avatar
      final badgeCenter = Offset(centerX, avatarCenterY + avatarRadius + 8);
      canvas.drawCircle(badgeCenter, 11, Paint()..color = const Color(0xFFB71C1C));
      canvas.drawCircle(badgeCenter, 11, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFFFD700));
      final textPainter = TextPainter(
        text: const TextSpan(text: '1', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2));
    } else {
      // Wreath Leaves for Top 2 & Top 3
      const topY = 6.0;
      final crestPath = Path();
      crestPath.moveTo(centerX - 8, topY + 8);
      crestPath.lineTo(centerX, topY);
      crestPath.lineTo(centerX + 8, topY + 8);
      crestPath.lineTo(centerX, topY + 14);
      crestPath.close();
      canvas.drawPath(crestPath, goldFill);
      canvas.drawCircle(Offset(centerX, topY + 8), 2.5, Paint()..color = (rank == 2 ? const Color(0xFF1E88E5) : const Color(0xFF43A047)));

      // Left Wreath Leaves
      final leftWing = Path();
      leftWing.moveTo(centerX - 20, topY + 12);
      leftWing.quadraticBezierTo(centerX - 44, topY + 8, centerX - 50, topY + 28);
      leftWing.quadraticBezierTo(centerX - 36, topY + 34, centerX - 46, topY + 46);
      leftWing.quadraticBezierTo(centerX - 32, topY + 42, centerX - 20, topY + 44);
      leftWing.close();
      canvas.drawPath(leftWing, goldFill);
      canvas.drawPath(leftWing, outlinePaint);

      // Right Wreath Leaves
      final rightWing = Path();
      rightWing.moveTo(centerX + 20, topY + 12);
      rightWing.quadraticBezierTo(centerX + 44, topY + 8, centerX + 50, topY + 28);
      rightWing.quadraticBezierTo(centerX + 36, topY + 34, centerX + 46, topY + 46);
      rightWing.quadraticBezierTo(centerX + 32, topY + 42, centerX + 20, topY + 44);
      rightWing.close();
      canvas.drawPath(rightWing, goldFill);
      canvas.drawPath(rightWing, outlinePaint);

      // Ribbon Badge below avatar
      final ribbonCenter = Offset(centerX, avatarCenterY + avatarRadius + 8);
      final ribbonRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: ribbonCenter, width: 44, height: 16),
        const Radius.circular(4),
      );
      canvas.drawRRect(ribbonRect, Paint()..color = (rank == 2 ? const Color(0xFF1565C0) : const Color(0xFF2E7D32)));
      canvas.drawRRect(ribbonRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0xFFFFD700));
      final textPainter = TextPainter(
        text: TextSpan(text: 'Top$rank', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(ribbonCenter.dx - textPainter.width / 2, ribbonCenter.dy - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Active Room Equalizer Indicator ─────────────────────────────────────────
class ActiveRoomIndicator extends StatelessWidget {
  final String userId;
  final AudioRoomsBloc audioRoomsBloc;
  const ActiveRoomIndicator({super.key, required this.userId, required this.audioRoomsBloc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .where('isActive', isEqualTo: true)
          .where('joinedUserIds', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        AudioRoomV2? activeRoom;
        for (var doc in snapshot.data!.docs) {
          final room = AudioRoomV2.fromFirestore(doc);
          if (room.isParticipant(userId)) {
            activeRoom = room;
            break;
          }
        }

        if (activeRoom == null) {
          return const SizedBox.shrink();
        }

        final room = activeRoom;

        return GestureDetector(
          onTap: () {
            final currentUser = AuthController.instance.currentUser;
            if (room.isUserBlocked(currentUser.userId)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are blocked from entering this room.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (room.isUserKickedRecently(currentUser.userId)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'You have been removed from this room and cannot join for 24 hours.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            MinimizedRoomController.checkAndProceed(
              context: context,
              targetRoom: room,
              onProceed: () {
                if (!room.isParticipant(currentUser.userId)) {
                  audioRoomsBloc.add(JoinAudioRoom(
                    roomId: room.id,
                    userId: currentUser.userId,
                    userName: currentUser.fullname,
                    userImageUrl: currentUser.photoUrl,
                    userFrameId: currentUser.customization?.selectedFrameId,
                  ));
                }
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AudioRoomScreen(room: room, audioRoomsBloc: audioRoomsBloc),
                ));
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF64DD17)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 9,
                  height: 9,
                  child: _MiniEqualizer(),
                ),
                SizedBox(width: 2),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniEqualizer extends StatefulWidget {
  const _MiniEqualizer();

  @override
  __MiniEqualizerState createState() => __MiniEqualizerState();
}

class __MiniEqualizerState extends State<_MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(0.4 + 0.6 * _controller.value),
            _buildBar(0.2 + 0.8 * (1 - _controller.value)),
            _buildBar(0.6 + 0.4 * _controller.value),
          ],
        );
      },
    );
  }

  Widget _buildBar(double heightFactor) {
    return Container(
      width: 1.8,
      height: 9 * heightFactor,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}



