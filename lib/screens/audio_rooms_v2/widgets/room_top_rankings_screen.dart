import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/controllers/follow_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


// ─── Utility ────────────────────────────────────────────────────────────────
String formatDiamonds(int value) {
  if (value >= 1000000000000) {
    return '${(value / 1000000000000).toStringAsFixed(1).replaceAll('.0', '')}T';
  }
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return value.toString();
}

enum RankingPeriod { daily, weekly, monthly, total }

// ─── Model for user leaderboard entries ─────────────────────────────────────
class _UserEntry {
  final String userId;
  final String userName;
  final String? photoUrl;
  final int amount;
  _UserEntry(
      {required this.userId,
      required this.userName,
      this.photoUrl,
      required this.amount});
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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeService = Get.find<AppThemeService>();
      final bgColor = themeService.leaderboardBgColor.value ?? const Color(0xFF0D0917);
      
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        centerTitle: true,
        title: const Text(
          '🏆 Top Rankings',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '🏠 Top Rooms'),
            Tab(text: '💎 Donators'),
            Tab(text: '🎁 Receivers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TopRoomsTab(audioRoomsBloc: widget.audioRoomsBloc),
          _TopUsersTab(
              label: 'Top Donators',
              useReceiving: false,
              audioRoomsBloc: widget.audioRoomsBloc),
          _TopUsersTab(
              label: 'Top Receivers',
              useReceiving: true,
              audioRoomsBloc: widget.audioRoomsBloc),
        ],
      ),
    );
    });
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────
Widget _buildPeriodSelector(
    RankingPeriod selected, ValueChanged<RankingPeriod> onChanged) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1230),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      children: [
        _buildPeriodButton('Daily', RankingPeriod.daily, selected, onChanged),
        _buildPeriodButton('Weekly', RankingPeriod.weekly, selected, onChanged),
        _buildPeriodButton('Monthly', RankingPeriod.monthly, selected, onChanged),
        _buildPeriodButton('Total', RankingPeriod.total, selected, onChanged),
      ],
    ),
  );
}

Widget _buildPeriodButton(String text, RankingPeriod period,
    RankingPeriod selected, ValueChanged<RankingPeriod> onChanged) {
  final isSelected = selected == period;
  return Expanded(
    child: GestureDetector(
      onTap: () => onChanged(period),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

// ─── Top Rooms Tab ────────────────────────────────────────────────────────────
class _TopRoomsTab extends StatefulWidget {
  final AudioRoomsBloc audioRoomsBloc;
  const _TopRoomsTab({required this.audioRoomsBloc});

  @override
  State<_TopRoomsTab> createState() => _TopRoomsTabState();
}

class _TopRoomsTabState extends State<_TopRoomsTab> {
  RankingPeriod _period = RankingPeriod.daily;

  String get _queryField {
    switch (_period) {
      case RankingPeriod.daily:
        return 'dailyRevenue_${RankingHelper.dailySuffix}';
      case RankingPeriod.weekly:
        return 'weeklyRevenue_${RankingHelper.weeklySuffix}';
      case RankingPeriod.monthly:
        return 'monthlyRevenue_${RankingHelper.monthlySuffix}';
      case RankingPeriod.total:
        return 'totalRevenue';
    }
  }

  String get _fallbackField => 'totalRevenue';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPeriodSelector(_period, (p) => setState(() => _period = p)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('audio_rooms_v2')
                .orderBy(_queryField, descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }
              if (snapshot.hasError) {
                // Fallback to totalRevenue if period fields are missing or not indexed
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('audio_rooms_v2')
                      .orderBy(_fallbackField, descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFFD700)));
                    }
                    return _buildList(snap.data?.docs ?? [], isFallback: true);
                  },
                );
              }
              return _buildList(snapshot.data?.docs ?? [], isFallback: false);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, {bool isFallback = false}) {
    if (docs.isEmpty) {
      return const Center(
        child: Text('No rooms ranked yet',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    final queryFieldToUse = isFallback ? _fallbackField : _queryField;

    final roomsData = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final amount = (data[queryFieldToUse] as num?)?.toInt() ?? 0;
      return {'room': AudioRoomV2.fromFirestore(d), 'amount': amount};
    }).toList();

    roomsData
        .sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: roomsData.length,
      itemBuilder: (context, index) {
        final room = roomsData[index]['room'] as AudioRoomV2;
        final amount = roomsData[index]['amount'] as int;
        return _RoomRankCard(
          rank: index + 1,
          room: room,
          amount: amount,
          onTap: () => _enterRoom(context, room),
        );
      },
    );
  }

  void _enterRoom(BuildContext context, AudioRoomV2 room) {
    final currentUser = AuthController.instance.currentUser;
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
          builder: (_) =>
              AudioRoomScreen(room: room, audioRoomsBloc: widget.audioRoomsBloc),
        ));
      },
    );
  }
}

// ─── Room Rank Card ───────────────────────────────────────────────────────────
class _RoomRankCard extends StatelessWidget {
  final int rank;
  final AudioRoomV2 room;
  final int amount;
  final VoidCallback onTap;
  const _RoomRankCard(
      {required this.rank,
      required this.room,
      required this.amount,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    final rankColor = isTop3 ? rankColors[rank - 1] : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isTop3
                ? [
                    rankColor.withValues(alpha: 0.18),
                    const Color(0xFF1A1230),
                  ]
                : [const Color(0xFF1A1230), const Color(0xFF120C1C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: isTop3 ? rankColor.withValues(alpha: 0.5) : Colors.white12,
            width: isTop3 ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: isTop3
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rank == 1
                                ? '🥇'
                                : rank == 2
                                    ? '🥈'
                                    : '🥉',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: room.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: room.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _roomPlaceholder(),
                      )
                    : _roomPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Host: ${room.creatorName}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DynamicDiamondIcon(width: 14,
                          height: 14,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.diamond,
                              color: Color(0xFF00E5FF),
                              size: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDiamonds(amount),
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.people,
                            color: Colors.white38, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${room.participantCount}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B3D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.meeting_room, color: Color(0xFFD4AF37), size: 24),
    );
  }
}

// ─── Top Users Tab (Donator / Receiver) ──────────────────────────────────────
class _TopUsersTab extends StatefulWidget {
  final String label;
  final bool useReceiving;
  final AudioRoomsBloc audioRoomsBloc;
  const _TopUsersTab({
    required this.label,
    required this.audioRoomsBloc,
    this.useReceiving = false,
  });

  @override
  State<_TopUsersTab> createState() => _TopUsersTabState();
}

class _TopUsersTabState extends State<_TopUsersTab> {
  RankingPeriod _period = RankingPeriod.daily;

  String get _queryField {
    if (widget.useReceiving) {
      switch (_period) {
        case RankingPeriod.daily:
          return 'dailyDiamondsReceived_${RankingHelper.dailySuffix}';
        case RankingPeriod.weekly:
          return 'weeklyDiamondsReceived_${RankingHelper.weeklySuffix}';
        case RankingPeriod.monthly:
          return 'monthlyDiamondsReceived_${RankingHelper.monthlySuffix}';
        case RankingPeriod.total:
          return 'receivingLevel.totalExp';
      }
    } else {
      switch (_period) {
        case RankingPeriod.daily:
          return 'dailyDiamondsSent_${RankingHelper.dailySuffix}';
        case RankingPeriod.weekly:
          return 'weeklyDiamondsSent_${RankingHelper.weeklySuffix}';
        case RankingPeriod.monthly:
          return 'monthlyDiamondsSent_${RankingHelper.monthlySuffix}';
        case RankingPeriod.total:
          return 'sendingLevel.totalExp';
      }
    }
  }

  String get _fallbackField {
    return widget.useReceiving
        ? 'receivingLevel.totalExp'
        : 'sendingLevel.totalExp';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPeriodSelector(_period, (p) => setState(() => _period = p)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .orderBy(_queryField, descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }
              if (snapshot.hasError) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Users')
                      .orderBy(_fallbackField, descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFFD700)));
                    }
                    return _buildList(snap.data?.docs ?? [], isFallback: true);
                  },
                );
              }
              return _buildList(snapshot.data?.docs ?? []);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs,
      {bool isFallback = false}) {
    if (docs.isEmpty) {
      return Center(
        child: Text('No ${widget.label} data yet',
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    final entries = docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          int amount = 0;

          if (isFallback) {
            amount = widget.useReceiving
                ? ((data['receivingLevel']
                            as Map<String, dynamic>?)?['totalExp'] as num?)
                        ?.toInt() ??
                    (data['beans'] as num?)?.toInt() ??
                    0
                : ((data['sendingLevel'] as Map<String, dynamic>?)?['totalExp']
                            as num?)
                        ?.toInt() ??
                    (data['totalDiamonds'] as num?)?.toInt() ??
                    0;
          } else {
            amount = (data[_queryField] as num?)?.toInt() ?? 0;
          }

          return _UserEntry(
            userId: doc.id,
            userName: data['fullname'] as String? ?? 'Unknown',
            photoUrl: data['photoUrl'] as String?,
            amount: amount,
          );
        })
        .where((e) => e.amount > 0)
        .toList();

    entries.sort((a, b) => b.amount.compareTo(a.amount));

    if (entries.isEmpty) {
      return Center(
        child: Text('No ${widget.label} data yet',
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _UserRankCard(
          rank: index + 1,
          entry: entries[index],
          audioRoomsBloc: widget.audioRoomsBloc,
          useReceiving: widget.useReceiving,
        );
      },
    );
  }
}

// ─── User Rank Card ───────────────────────────────────────────────────────────
class _UserRankCard extends StatefulWidget {
  final int rank;
  final _UserEntry entry;
  final bool useReceiving;
  final AudioRoomsBloc audioRoomsBloc;
  const _UserRankCard(
      {required this.rank, required this.entry, required this.audioRoomsBloc, this.useReceiving = false});

  @override
  State<_UserRankCard> createState() => _UserRankCardState();
}

class _UserRankCardState extends State<_UserRankCard> {
  late final FollowController _followController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _followController = FollowController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final currentUser = AuthController.instance.currentUser;
      _followController.loadFollowStatus(
        currentUserId: currentUser.userId,
        targetUserId: widget.entry.userId,
      );
    }
  }

  @override
  void dispose() {
    _followController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final rankColor = isTop3 ? rankColors[widget.rank - 1] : Colors.white38;
    
    // Check if it's the current user (don't show follow for self)
    final currentUser = AuthController.instance.currentUser;
    final isSelf = currentUser.userId == widget.entry.userId;
    final themeService = Get.find<AppThemeService>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isTop3
              ? [rankColor.withValues(alpha: 0.18), const Color(0xFF1A1230)]
              : [const Color(0xFF1A1230), const Color(0xFF120C1C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: isTop3 ? rankColor.withValues(alpha: 0.5) : Colors.white12,
          width: isTop3 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: isTop3
                  ? Center(
                      child: Text(
                        widget.rank == 1
                            ? '🥇'
                            : widget.rank == 2
                                ? '🥈'
                                : '🥉',
                        style: const TextStyle(fontSize: 24),
                      ),
                    )
                  : Center(
                      child: Text(
                        '#${widget.rank}',
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF2A1B3D),
                  backgroundImage:
                      (widget.entry.photoUrl != null && widget.entry.photoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(widget.entry.photoUrl!)
                          : null,
                  child: (widget.entry.photoUrl == null || widget.entry.photoUrl!.isEmpty)
                      ? Text(
                          widget.entry.userName.isNotEmpty
                              ? widget.entry.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                if (isTop3)
                  Positioned.fill(
                    child: Obx(() {
                      // Force GetX to register the map dependency so it triggers on any key change
                      // ignore: unused_local_variable
                      final trigger = themeService.leaderboardFrames.keys.toList();
                      final category = widget.useReceiving ? 'receiver' : 'sender';
                      final url = themeService.leaderboardFrames[widget.rank.toString()] ?? 
                                  themeService.getLeaderboardFrameUrl(category, widget.rank);
                      if (url != null && url.isNotEmpty) {
                        return CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ),
                Positioned(
                  bottom: -4,
                  right: -8,
                  child: ActiveRoomIndicator(userId: widget.entry.userId, audioRoomsBloc: widget.audioRoomsBloc),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      DynamicDiamondIcon(width: 14,
                        height: 14,
                        errorBuilder: (_, __, ___) => Icon(
                          widget.useReceiving ? Icons.card_giftcard : Icons.diamond,
                          color: const Color(0xFF00E5FF),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDiamonds(widget.entry.amount),
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelf) ...[
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: _followController,
                builder: (context, child) {
                  final isFollowing = _followController.isFollowing(widget.entry.userId);
                  final isLoading = _followController.isLoading(widget.entry.userId);

                  if (isFollowing) {
                    return SizedBox(
                      height: 32,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check, size: 14, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text(
                              'Following',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final currentUser = AuthController.instance.currentUser;
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await _followController.toggleFollow(
                                currentUserId: currentUser.userId,
                                targetUserId: widget.entry.userId,
                              );

                              if (result.isSuccess) {
                                messenger.showSnackBar(SnackBar(
                                  content: Text('Followed ${widget.entry.userName}'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ));
                              } else {
                                messenger.showSnackBar(SnackBar(
                                  content: Text(result.message),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add, size: 16, color: Colors.white),
                      label: Text(
                        isLoading ? 'Loading...' : 'Follow',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Active Room Equalizer ───────────────────────────────────────────────────
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
          return const SizedBox.shrink(); // No active room found
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
          return const SizedBox.shrink(); // User is not currently in the room
        }
        
        final room = activeRoom;
        
        return GestureDetector(
          onTap: () {
            final currentUser = AuthController.instance.currentUser;
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
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF64DD17)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: _MiniEqualizer(),
                ),
                SizedBox(width: 2),
                Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
      width: 2,
      height: 10 * heightFactor,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
