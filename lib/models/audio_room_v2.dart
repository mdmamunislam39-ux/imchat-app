import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is DateTime) return value;
  return DateTime.now();
}

bool _parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return defaultValue;
}

/// Chat message model for live comments
class ChatMessage extends Equatable {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String message;
  final DateTime timestamp;
  final String roomId;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.message,
    required this.timestamp,
    required this.roomId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      message: json['message'] ?? '',
      timestamp: _parseDateTime(json['timestamp']),
      roomId: json['roomId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'roomId': roomId,
    };
  }

  @override
  List<Object?> get props =>
      [id, userId, username, userAvatar, message, timestamp, roomId];
}

/// Room modes with different layouts and configurations
enum RoomMode {
  lite, // Simple layout - 9 seats
  // immersive, // Standard layout - 10 seats (REMOVED as per client request)
  party, // Party layout - 12 seats
  multiMic, // Multi-microphone - 15 seats (changed from 16)
  // ktv,       // Karaoke mode - 8 seats (REMOVED as per client request)
  // cp,        // Couple mode - 4 seats (REMOVED as per client request)
  fiveSeats, // 5 seats mode
  tenSeats, // 10 seats mode
  twentySeats, // 20 seats mode
}

/// Extension for RoomMode
extension RoomModeExtension on RoomMode {
  String get displayName {
    switch (this) {
      case RoomMode.lite:
        return 'Lite Mode';
      // case RoomMode.immersive:
      //   return 'Immersive Mode';
      case RoomMode.party:
        return 'Party Mode';
      case RoomMode.multiMic:
        return 'Multi-Mic Mode';
      // case RoomMode.ktv:
      //   return 'KTV';
      // case RoomMode.cp:
      //   return 'CP';
      case RoomMode.fiveSeats:
        return '5 Seats Mode';
      case RoomMode.tenSeats:
        return '10 Seats Mode';
      case RoomMode.twentySeats:
        return '20 Seats Mode';
    }
  }

  int get seatCount {
    switch (this) {
      case RoomMode.lite:
        return 9;
      // case RoomMode.immersive:
      //   return 10;
      case RoomMode.party:
        return 12;
      case RoomMode.multiMic:
        return 15; // Changed from 16 to 15
      // case RoomMode.ktv:
      //   return 8;
      // case RoomMode.cp:
      //   return 4;
      case RoomMode.fiveSeats:
        return 5;
      case RoomMode.tenSeats:
        return 10;
      case RoomMode.twentySeats:
        return 20;
    }
  }

  String get backgroundAsset {
    switch (this) {
      case RoomMode.lite:
        return 'assets/images/welcome_image.webp';
      // case RoomMode.immersive:
      //   return 'assets/images/welcome_image.webp';
      case RoomMode.party:
        return 'assets/images/welcome_image.webp';
      case RoomMode.multiMic:
        return 'assets/images/welcome_image.webp';
      // case RoomMode.ktv:
      //   return 'assets/images/welcome_image.webp';
      // case RoomMode.cp:
      //   return 'assets/images/welcome_image.webp';
      case RoomMode.fiveSeats:
        return 'assets/images/welcome_image.webp';
      case RoomMode.tenSeats:
        return 'assets/images/welcome_image.webp';
      case RoomMode.twentySeats:
        return 'assets/images/welcome_image.webp';
    }
  }

  String toJson() => name;

  static RoomMode fromJson(String value) {
    return RoomMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => RoomMode.lite, // Default to lite (was immersive)
    );
  }
}

/// Seat color mood options for room UI
enum SeatColorMode {
  original,
  golden,
  purple,
  dashedPink,
  dashedOrange,
}

extension SeatColorModeExtension on SeatColorMode {
  String get displayName {
    switch (this) {
      case SeatColorMode.original:
        return 'Original';
      case SeatColorMode.golden:
        return 'Golden';
      case SeatColorMode.purple:
        return 'Purple';
      case SeatColorMode.dashedPink:
        return 'Dashed Pink';
      case SeatColorMode.dashedOrange:
        return 'Dashed Orange';
    }
  }

  String toJson() => name;

  static SeatColorMode fromJson(String value) {
    return SeatColorMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => SeatColorMode.original,
    );
  }
}

/// Room Contributor Model (for ranking and tracking)
class RoomContributor extends Equatable {
  final String userId;
  final String userName;
  final String? userAvatar;
  final int totalContribution;
  final int dailyContribution;
  final int weeklyContribution;
  final int monthlyContribution;
  final DateTime lastContributionAt;

  const RoomContributor({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.totalContribution,
    this.dailyContribution = 0,
    this.weeklyContribution = 0,
    this.monthlyContribution = 0,
    required this.lastContributionAt,
  });

  factory RoomContributor.fromJson(Map<String, dynamic> json) {
    final DateTime lastContributionAt =
        _parseDateTime(json['lastContributionAt']);

    final dailySuffix = RankingHelper.dailySuffix;
    final weeklySuffix = RankingHelper.weeklySuffix;
    final mondayWeeklySuffix = RankingHelper.mondayWeeklySuffix;
    final monthlySuffix = RankingHelper.monthlySuffix;

    final localDailySuffix = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final utcDailySuffix =
        DateFormat('yyyy_MM_dd').format(DateTime.now().toUtc());
    final localMonthlySuffix = DateFormat('yyyy_MM').format(DateTime.now());

    int dailyContribution = 0;
    if (json['dailyContribution_$dailySuffix'] != null) {
      dailyContribution =
          (json['dailyContribution_$dailySuffix'] as num).toInt();
    } else if (json['dailyContribution_$localDailySuffix'] != null) {
      dailyContribution =
          (json['dailyContribution_$localDailySuffix'] as num).toInt();
    } else if (json['dailyContribution_$utcDailySuffix'] != null) {
      dailyContribution =
          (json['dailyContribution_$utcDailySuffix'] as num).toInt();
    } else if (json['dailyContribution'] != null) {
      dailyContribution = (json['dailyContribution'] as num).toInt();
    }

    int weeklyContribution = 0;
    if (json['weeklyContribution_$weeklySuffix'] != null) {
      weeklyContribution =
          (json['weeklyContribution_$weeklySuffix'] as num).toInt();
    } else if (json['weeklyContribution_$mondayWeeklySuffix'] != null) {
      weeklyContribution =
          (json['weeklyContribution_$mondayWeeklySuffix'] as num).toInt();
    } else if (json['weeklyContribution'] != null) {
      weeklyContribution = (json['weeklyContribution'] as num).toInt();
    }

    int monthlyContribution = 0;
    if (json['monthlyContribution_$monthlySuffix'] != null) {
      monthlyContribution =
          (json['monthlyContribution_$monthlySuffix'] as num).toInt();
    } else if (json['monthlyContribution_$localMonthlySuffix'] != null) {
      monthlyContribution =
          (json['monthlyContribution_$localMonthlySuffix'] as num).toInt();
    } else if (json['monthlyContribution'] != null) {
      monthlyContribution = (json['monthlyContribution'] as num).toInt();
    }

    // Smart fallback if period keys weren't found:
    if (dailyContribution == 0) {
      final now = DateTime.now();
      final bool isSameDay = lastContributionAt.year == now.year &&
          lastContributionAt.month == now.month &&
          lastContributionAt.day == now.day;
      if (isSameDay) {
        for (final entry in json.entries) {
          if (entry.key.startsWith('dailyContribution_') && entry.value is num) {
            dailyContribution = (entry.value as num).toInt();
            break;
          }
        }
      }
    }

    if (weeklyContribution == 0) {
      final now = DateTime.now();
      if (now.difference(lastContributionAt).inDays.abs() < 7) {
        for (final entry in json.entries) {
          if (entry.key.startsWith('weeklyContribution_') && entry.value is num) {
            weeklyContribution = (entry.value as num).toInt();
            break;
          }
        }
      }
    }

    if (monthlyContribution == 0) {
      final now = DateTime.now();
      if (lastContributionAt.year == now.year &&
          lastContributionAt.month == now.month) {
        for (final entry in json.entries) {
          if (entry.key.startsWith('monthlyContribution_') &&
              entry.value is num) {
            monthlyContribution = (entry.value as num).toInt();
            break;
          }
        }
      }
    }

    return RoomContributor(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Unknown',
      userAvatar: json['userAvatar'],
      totalContribution: (json['totalContribution'] as num?)?.toInt() ?? 0,
      dailyContribution: dailyContribution,
      weeklyContribution: weeklyContribution,
      monthlyContribution: monthlyContribution,
      lastContributionAt: lastContributionAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'totalContribution': totalContribution,
      'dailyContribution_${RankingHelper.dailySuffix}': dailyContribution,
      'weeklyContribution_${RankingHelper.weeklySuffix}': weeklyContribution,
      'weeklyContribution_${RankingHelper.mondayWeeklySuffix}':
          weeklyContribution,
      'monthlyContribution_${RankingHelper.monthlySuffix}': monthlyContribution,
      'dailyContribution': dailyContribution,
      'weeklyContribution': weeklyContribution,
      'monthlyContribution': monthlyContribution,
      'lastContributionAt': Timestamp.fromDate(lastContributionAt),
    };
  }

  RoomContributor copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    int? totalContribution,
    int? dailyContribution,
    int? weeklyContribution,
    int? monthlyContribution,
    DateTime? lastContributionAt,
  }) {
    return RoomContributor(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      totalContribution: totalContribution ?? this.totalContribution,
      dailyContribution: dailyContribution ?? this.dailyContribution,
      weeklyContribution: weeklyContribution ?? this.weeklyContribution,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      lastContributionAt: lastContributionAt ?? this.lastContributionAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        userName,
        userAvatar,
        totalContribution,
        dailyContribution,
        weeklyContribution,
        monthlyContribution,
        lastContributionAt
      ];
}

class PKBattleState extends Equatable {
  final bool isActive;
  final int durationMinutes;
  final DateTime? startTime;
  final int teamSize;
  final int leftTeamScore;
  final int rightTeamScore;
  final Map<String, int> individualScores;
  final List<String> leftTeamUserIds;
  final List<String> rightTeamUserIds;
  final String? opponentRoomId;
  final String? opponentRoomName;
  final String? opponentRoomImageUrl;

  const PKBattleState({
    this.isActive = false,
    this.durationMinutes = 5,
    this.startTime,
    this.teamSize = 2,
    this.leftTeamScore = 0,
    this.rightTeamScore = 0,
    this.individualScores = const {},
    this.leftTeamUserIds = const [],
    this.rightTeamUserIds = const [],
    this.opponentRoomId,
    this.opponentRoomName,
    this.opponentRoomImageUrl,
  });

  factory PKBattleState.fromJson(Map<String, dynamic> json) {
    return PKBattleState(
      isActive: json['isActive'] ?? false,
      durationMinutes: json['durationMinutes'] ?? 5,
      startTime: json['startTime'] != null
          ? _parseDateTime(json['startTime'])
          : null,
      teamSize: json['teamSize'] ?? 2,
      leftTeamScore: json['leftTeamScore'] ?? 0,
      rightTeamScore: json['rightTeamScore'] ?? 0,
      individualScores: json['individualScores'] != null
          ? Map<String, int>.from(json['individualScores'] as Map)
          : const {},
      leftTeamUserIds: (json['leftTeamUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rightTeamUserIds: (json['rightTeamUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      opponentRoomId: json['opponentRoomId'],
      opponentRoomName: json['opponentRoomName'],
      opponentRoomImageUrl: json['opponentRoomImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'durationMinutes': durationMinutes,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'teamSize': teamSize,
      'leftTeamScore': leftTeamScore,
      'rightTeamScore': rightTeamScore,
      'individualScores': individualScores,
      'leftTeamUserIds': leftTeamUserIds,
      'rightTeamUserIds': rightTeamUserIds,
      'opponentRoomId': opponentRoomId,
      'opponentRoomName': opponentRoomName,
      'opponentRoomImageUrl': opponentRoomImageUrl,
    };
  }

  PKBattleState copyWith({
    bool? isActive,
    int? durationMinutes,
    DateTime? startTime,
    int? teamSize,
    int? leftTeamScore,
    int? rightTeamScore,
    Map<String, int>? individualScores,
    List<String>? leftTeamUserIds,
    List<String>? rightTeamUserIds,
    String? opponentRoomId,
    String? opponentRoomName,
    String? opponentRoomImageUrl,
  }) {
    return PKBattleState(
      isActive: isActive ?? this.isActive,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
      teamSize: teamSize ?? this.teamSize,
      leftTeamScore: leftTeamScore ?? this.leftTeamScore,
      rightTeamScore: rightTeamScore ?? this.rightTeamScore,
      individualScores: individualScores ?? this.individualScores,
      leftTeamUserIds: leftTeamUserIds ?? this.leftTeamUserIds,
      rightTeamUserIds: rightTeamUserIds ?? this.rightTeamUserIds,
      opponentRoomId: opponentRoomId ?? this.opponentRoomId,
      opponentRoomName: opponentRoomName ?? this.opponentRoomName,
      opponentRoomImageUrl: opponentRoomImageUrl ?? this.opponentRoomImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        isActive,
        durationMinutes,
        startTime,
        teamSize,
        leftTeamScore,
        rightTeamScore,
        individualScores,
        leftTeamUserIds,
        rightTeamUserIds,
        opponentRoomId,
        opponentRoomName,
        opponentRoomImageUrl,
      ];
}

/// Audio Room v2 Model
class AudioRoomV2 extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String creatorId;
  final String creatorName;
  final String? creatorImageUrl;
  final String? creatorPhone;
  final String? creatorCountry;
  final List<AudioRoomParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int maxParticipants;
  final int totalRevenue; // Total value of gifts sent in the room
  final int dailyRevenue;
  final int weeklyRevenue;
  final int monthlyRevenue;
  final Map<String, RoomContributor> contributors; // User contributions
  final AudioRoomSettings settings;
  final PKBattleState pkBattleState;
  final List<String> joinedUserIds;
  final List<String> joinRequests; // Users requesting to join the Live Video call
  final Map<String, DateTime> membersLastActive;
  final List<Map<String, dynamic>> removedUsers;
  final String category; // Category for exploring/filtering: All Rooms, Game, PK, Event
  final String? roomLink;
  final bool isPinned;
  final DateTime? pinnedUntil;
  final String? roomFrameUrl;
  final DateTime? roomFrameUntil;
  final String? activeYoutubeVideoId;
  final bool youtubeIsPlaying;
  final int youtubeSyncPosition;
  final DateTime? youtubeUpdatedAt;
  final bool isLudoActive;
  final bool isCarromActive;
  final bool isVotingActive;
  final bool isBanned;
  final DateTime? banEndTime;
  final String? groupId;
  final bool isGroupRoom;
  final bool isPrivate;
  final List<String> allowedUserIds;
  final bool excludeFromRanking;
  final double trendingScore;
  final int onlineCount;
  final int uniqueJoiners10m;
  final int giftCoins10m;
  final int likes10m;
  final int messages10m;
  final int activeSpeakers;
  final double avgStayTime;
  final double growthRate;
  final DateTime? lastCalculated;
  final int recentGiftsDiamonds;
  final String? countryCode;
  final bool isOfficial;

  const AudioRoomV2({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.creatorId,
    required this.creatorName,
    this.creatorImageUrl,
    this.creatorPhone,
    this.creatorCountry,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.maxParticipants = 50,
    this.totalRevenue = 0,
    this.dailyRevenue = 0,
    this.weeklyRevenue = 0,
    this.monthlyRevenue = 0,
    this.contributors = const {},
    required this.settings,
    this.pkBattleState = const PKBattleState(),
    this.joinedUserIds = const [],
    this.joinRequests = const [],
    this.membersLastActive = const {},
    this.removedUsers = const [],
    this.category = 'Game',
    this.roomLink,
    this.isPinned = false,
    this.pinnedUntil,
    this.roomFrameUrl,
    this.roomFrameUntil,
    this.activeYoutubeVideoId,
    this.youtubeIsPlaying = false,
    this.youtubeSyncPosition = 0,
    this.youtubeUpdatedAt,
    this.isLudoActive = false,
    this.isCarromActive = false,
    this.isVotingActive = false,
    this.isBanned = false,
    this.banEndTime,
    this.groupId,
    this.isGroupRoom = false,
    this.isPrivate = false,
    this.allowedUserIds = const [],
    this.excludeFromRanking = false,
    this.trendingScore = 0.0,
    this.onlineCount = 0,
    this.uniqueJoiners10m = 0,
    this.giftCoins10m = 0,
    this.likes10m = 0,
    this.messages10m = 0,
    this.activeSpeakers = 0,
    this.avgStayTime = 0.0,
    this.growthRate = 1.0,
    this.lastCalculated,
    this.recentGiftsDiamonds = 0,
    this.countryCode,
    this.isOfficial = false,
  });

  /// Create from Firestore document
  factory AudioRoomV2.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Smart legacy classification for categories
      String category = data['category'] ?? '';
      if (category.isEmpty) {
        final nameLower = (data['name'] ?? '').toString().toLowerCase();
        final descLower = (data['description'] ?? '').toString().toLowerCase();
        if (nameLower.contains('pk') || descLower.contains('pk') || nameLower.contains('battle') || descLower.contains('battle')) {
          category = 'PK';
        } else if (nameLower.contains('game') || descLower.contains('game') || nameLower.contains('play') || nameLower.contains('pubg')) {
          category = 'Game';
        } else if (nameLower.contains('event') || descLower.contains('event') || nameLower.contains('party') || nameLower.contains('meet') || nameLower.contains('live')) {
          category = 'Event';
        } else {
          category = 'Game'; // Fallback default
        }
      }

      final roomId = doc.id;
      final generatedLink = 'https://invite.imchatapp.com/room/$roomId';

      return AudioRoomV2(
        id: roomId,
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        imageUrl: data['imageUrl'],
        creatorId: data['creatorId'] ?? '',
        creatorName: data['creatorName'] ?? '',
        creatorImageUrl: data['creatorImageUrl'],
        creatorPhone: data['creatorPhone'],
        creatorCountry: data['creatorCountry'],
        participants: (data['participants'] as List<dynamic>?)
                ?.map((p) =>
                    AudioRoomParticipant.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList() ??
            [],
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: _parseBool(data['isActive'], defaultValue: true),
        maxParticipants: data['maxParticipants'] ?? 50,
        totalRevenue: (data['totalRevenue'] as num?)?.toInt() ?? 0,
        dailyRevenue: (data['dailyRevenue_${RankingHelper.dailySuffix}'] as num?)?.toInt() ??
            (data['dailyRevenue'] as num?)?.toInt() ??
            0,
        weeklyRevenue: (data['weeklyRevenue_${RankingHelper.weeklySuffix}'] as num?)?.toInt() ??
            (data['weeklyRevenue_${RankingHelper.mondayWeeklySuffix}'] as num?)?.toInt() ??
            (data['weeklyRevenue'] as num?)?.toInt() ??
            0,
        monthlyRevenue: (data['monthlyRevenue_${RankingHelper.monthlySuffix}'] as num?)?.toInt() ??
            (data['monthlyRevenue'] as num?)?.toInt() ??
            0,
        contributors: (data['contributors'] is Map)
            ? (data['contributors'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  RoomContributor.fromJson(
                      Map<String, dynamic>.from(value as Map)),
                ),
              )
            : {},
        settings: AudioRoomSettings.fromJson(
            Map<String, dynamic>.from(data['settings'] as Map? ?? {})),
        pkBattleState: data['pkBattleState'] != null
            ? PKBattleState.fromJson(
                Map<String, dynamic>.from(data['pkBattleState'] as Map))
            : const PKBattleState(),
        joinedUserIds: (data['joinedUserIds'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            <String>[],
        joinRequests: (data['joinRequests'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            <String>[],
        membersLastActive: (data['membersLastActive'] as Map?)?.map(
              (key, val) => MapEntry(
                key.toString(),
                val is Timestamp ? val.toDate() : DateTime.now(),
              ),
            ) ??
            const {},
        removedUsers: (data['removedUsers'] as List<dynamic>?)
                ?.map((item) => Map<String, dynamic>.from(item as Map))
                .toList() ??
            const [],
        category: category,
        roomLink: data['roomLink'] ?? generatedLink,
        isPinned: _parseBool(data['isPinned']),
        pinnedUntil: data['pinnedUntil'] != null ? _parseDateTime(data['pinnedUntil']) : null,
        roomFrameUrl: data['roomFrameUrl'],
        roomFrameUntil: data['roomFrameUntil'] != null ? _parseDateTime(data['roomFrameUntil']) : null,
        activeYoutubeVideoId: data['activeYoutubeVideoId'],
        youtubeIsPlaying: _parseBool(data['youtubeIsPlaying']),
        youtubeSyncPosition: data['youtubeSyncPosition'] ?? 0,
        youtubeUpdatedAt: data['youtubeUpdatedAt'] != null ? _parseDateTime(data['youtubeUpdatedAt']) : null,
        isLudoActive: _parseBool(data['isLudoActive']),
        isCarromActive: _parseBool(data['isCarromActive']),
        isVotingActive: _parseBool(data['isVotingActive']),
        isBanned: _parseBool(data['isBanned']),
        banEndTime: data['banEndTime'] != null ? _parseDateTime(data['banEndTime']) : null,
        groupId: data['groupId'],
        isGroupRoom: _parseBool(data['isGroupRoom']),
        isPrivate: _parseBool(data['isPrivate']),
        allowedUserIds: (data['allowedUserIds'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            <String>[],
        excludeFromRanking: _parseBool(data['excludeFromRanking']),
        trendingScore: (data['trendingScore'] as num?)?.toDouble() ?? 0.0,
        onlineCount: (data['onlineCount'] as num?)?.toInt() ?? (data['participants'] as List?)?.length ?? 0,
        uniqueJoiners10m: (data['uniqueJoiners10m'] as num?)?.toInt() ?? 0,
        giftCoins10m: (data['giftCoins10m'] as num?)?.toInt() ?? (data['recentGiftsDiamonds'] as num?)?.toInt() ?? 0,
        likes10m: (data['likes10m'] as num?)?.toInt() ?? 0,
        messages10m: (data['messages10m'] as num?)?.toInt() ?? 0,
        activeSpeakers: (data['activeSpeakers'] as num?)?.toInt() ?? 0,
        avgStayTime: (data['avgStayTime'] as num?)?.toDouble() ?? 0.0,
        growthRate: (data['growthRate'] as num?)?.toDouble() ?? 1.0,
        lastCalculated: data['lastCalculated'] != null ? _parseDateTime(data['lastCalculated']) : null,
        recentGiftsDiamonds: (data['recentGiftsDiamonds'] as num?)?.toInt() ?? 0,
        countryCode: data['countryCode'] ?? data['country'],
        isOfficial: _parseBool(data['isOfficial']),
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing AudioRoomV2 from Firestore: $e\n$stackTrace');
      throw Exception('Error parsing AudioRoomV2 from Firestore: $e');
    }
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorImageUrl': creatorImageUrl,
      'creatorPhone': creatorPhone,
      'creatorCountry': creatorCountry,
      'participants': participants.map((p) => p.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'maxParticipants': maxParticipants,
      'totalRevenue': totalRevenue,
      'dailyRevenue_${RankingHelper.dailySuffix}': dailyRevenue,
      'weeklyRevenue_${RankingHelper.weeklySuffix}': weeklyRevenue,
      'monthlyRevenue_${RankingHelper.monthlySuffix}': monthlyRevenue,
      'dailyRevenue': dailyRevenue,
      'weeklyRevenue': weeklyRevenue,
      'monthlyRevenue': monthlyRevenue,
      'contributors':
          contributors.map((key, value) => MapEntry(key, value.toJson())),
      'settings': settings.toJson(),
      'pkBattleState': pkBattleState.toJson(),
      'joinedUserIds': joinedUserIds,
      'joinRequests': joinRequests,
      'membersLastActive': membersLastActive.map(
        (key, val) => MapEntry(key, Timestamp.fromDate(val)),
      ),
      'removedUsers': removedUsers,
      'category': category,
      'roomLink': roomLink ?? 'https://invite.imchatapp.com/room/$id',
      'isPinned': isPinned,
      'pinnedUntil': pinnedUntil != null ? Timestamp.fromDate(pinnedUntil!) : null,
      'roomFrameUrl': roomFrameUrl,
      'roomFrameUntil': roomFrameUntil != null ? Timestamp.fromDate(roomFrameUntil!) : null,
      'activeYoutubeVideoId': activeYoutubeVideoId,
      'youtubeIsPlaying': youtubeIsPlaying,
      'youtubeSyncPosition': youtubeSyncPosition,
      'youtubeUpdatedAt': youtubeUpdatedAt != null ? Timestamp.fromDate(youtubeUpdatedAt!) : null,
      'isLudoActive': isLudoActive,
      'isCarromActive': isCarromActive,
      'isVotingActive': isVotingActive,
      'isBanned': isBanned,
      'banEndTime': banEndTime != null ? Timestamp.fromDate(banEndTime!) : null,
      'groupId': groupId,
      'isGroupRoom': isGroupRoom,
      'isPrivate': isPrivate,
      'allowedUserIds': allowedUserIds,
      'excludeFromRanking': excludeFromRanking,
      'trendingScore': trendingScore,
      'onlineCount': onlineCount,
      'uniqueJoiners10m': uniqueJoiners10m,
      'giftCoins10m': giftCoins10m,
      'likes10m': likes10m,
      'messages10m': messages10m,
      'activeSpeakers': activeSpeakers,
      'avgStayTime': avgStayTime,
      'growthRate': growthRate,
      'lastCalculated': lastCalculated != null ? Timestamp.fromDate(lastCalculated!) : null,
      'recentGiftsDiamonds': recentGiftsDiamonds,
      'countryCode': countryCode,
      'isOfficial': isOfficial,
    };
  }

  /// Create a copy with updated fields
  AudioRoomV2 copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? creatorId,
    String? creatorName,
    String? creatorImageUrl,
    List<AudioRoomParticipant>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? maxParticipants,
    int? totalRevenue,
    int? dailyRevenue,
    int? weeklyRevenue,
    int? monthlyRevenue,
    Map<String, RoomContributor>? contributors,
    AudioRoomSettings? settings,
    PKBattleState? pkBattleState,
    List<String>? joinedUserIds,
    List<String>? joinRequests,
    Map<String, DateTime>? membersLastActive,
    List<Map<String, dynamic>>? removedUsers,
    String? category,
    String? roomLink,
    bool? isPinned,
    DateTime? pinnedUntil,
    String? roomFrameUrl,
    DateTime? roomFrameUntil,
    String? activeYoutubeVideoId,
    bool? youtubeIsPlaying,
    int? youtubeSyncPosition,
    DateTime? youtubeUpdatedAt,
    bool? isLudoActive,
    bool? isCarromActive,
    bool? isVotingActive,
    bool? isBanned,
    DateTime? banEndTime,
    String? groupId,
    bool? isGroupRoom,
    bool? isPrivate,
    List<String>? allowedUserIds,
    bool? excludeFromRanking,
    double? trendingScore,
    int? recentGiftsDiamonds,
    String? countryCode,
    bool? isOfficial,
    int? onlineCount,
    int? uniqueJoiners10m,
    int? giftCoins10m,
    int? likes10m,
    int? messages10m,
    int? activeSpeakers,
    double? avgStayTime,
    double? growthRate,
    DateTime? lastCalculated,
  }) {
    return AudioRoomV2(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorImageUrl: creatorImageUrl ?? this.creatorImageUrl,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      dailyRevenue: dailyRevenue ?? this.dailyRevenue,
      weeklyRevenue: weeklyRevenue ?? this.weeklyRevenue,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      contributors: contributors ?? this.contributors,
      settings: settings ?? this.settings,
      pkBattleState: pkBattleState ?? this.pkBattleState,
      joinedUserIds: joinedUserIds ?? this.joinedUserIds,
      joinRequests: joinRequests ?? this.joinRequests,
      membersLastActive: membersLastActive ?? this.membersLastActive,
      removedUsers: removedUsers ?? this.removedUsers,
      category: category ?? this.category,
      roomLink: roomLink ?? this.roomLink,
      isPinned: isPinned ?? this.isPinned,
      pinnedUntil: pinnedUntil ?? this.pinnedUntil,
      roomFrameUrl: roomFrameUrl ?? this.roomFrameUrl,
      roomFrameUntil: roomFrameUntil ?? this.roomFrameUntil,
      activeYoutubeVideoId: activeYoutubeVideoId ?? this.activeYoutubeVideoId,
      youtubeIsPlaying: youtubeIsPlaying ?? this.youtubeIsPlaying,
      youtubeSyncPosition: youtubeSyncPosition ?? this.youtubeSyncPosition,
      youtubeUpdatedAt: youtubeUpdatedAt ?? this.youtubeUpdatedAt,
      isLudoActive: isLudoActive ?? this.isLudoActive,
      isCarromActive: isCarromActive ?? this.isCarromActive,
      isVotingActive: isVotingActive ?? this.isVotingActive,
      isBanned: isBanned ?? this.isBanned,
      banEndTime: banEndTime ?? this.banEndTime,
      groupId: groupId ?? this.groupId,
      isGroupRoom: isGroupRoom ?? this.isGroupRoom,
      isPrivate: isPrivate ?? this.isPrivate,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      excludeFromRanking: excludeFromRanking ?? this.excludeFromRanking,
      trendingScore: trendingScore ?? this.trendingScore,
      onlineCount: onlineCount ?? this.onlineCount,
      uniqueJoiners10m: uniqueJoiners10m ?? this.uniqueJoiners10m,
      giftCoins10m: giftCoins10m ?? this.giftCoins10m,
      likes10m: likes10m ?? this.likes10m,
      messages10m: messages10m ?? this.messages10m,
      activeSpeakers: activeSpeakers ?? this.activeSpeakers,
      avgStayTime: avgStayTime ?? this.avgStayTime,
      growthRate: growthRate ?? this.growthRate,
      lastCalculated: lastCalculated ?? this.lastCalculated,
      recentGiftsDiamonds: recentGiftsDiamonds ?? this.recentGiftsDiamonds,
      countryCode: countryCode ?? this.countryCode,
      isOfficial: isOfficial ?? this.isOfficial,
    );
  }

  /// Get participant count
  int get participantCount => participants.length;

  /// Check if user is creator
  bool isCreator(String userId) => creatorId == userId;

  /// Check if user is participant
  bool isParticipant(String userId) =>
      participants.any((p) => p.userId == userId);

  /// Check if room is full
  bool get isFull => participantCount >= maxParticipants;

  /// Check if user is blocked
  bool isUserBlocked(String userId) =>
      settings.blockedUsers.any((b) => b.userId == userId);

  /// Get seat information for a specific seat number
  SeatInfo? getSeatInfo(int seatNumber) {
    try {
      return settings.seatConfiguration
          .firstWhere((seat) => seat.seatNumber == seatNumber);
    } catch (e) {
      return null;
    }
  }

  /// Check if a seat is locked
  bool isSeatLocked(int seatNumber) {
    final seatInfo = getSeatInfo(seatNumber);
    return seatInfo?.isLocked ?? false;
  }

  /// Check if a seat is occupied
  bool isSeatOccupied(int seatNumber) {
    final seatInfo = getSeatInfo(seatNumber);
    return seatInfo?.occupiedBy != null;
  }

  /// Get participant in a specific seat
  AudioRoomParticipant? getParticipantInSeat(int seatNumber) {
    final seatInfo = getSeatInfo(seatNumber);
    if (seatInfo?.occupiedBy == null) return null;

    try {
      return participants.firstWhere((p) => p.userId == seatInfo!.occupiedBy);
    } catch (e) {
      return null;
    }
  }

  /// Get available (unlocked and unoccupied) seats
  List<int> getAvailableSeats() {
    // Use the actual seat configuration length instead of room mode seat count
    // This handles cases where the room mode was changed but seat configuration wasn't updated
    final totalSeats = settings.seatConfiguration.length;
    final availableSeats = <int>[];

    for (int i = 1; i <= totalSeats; i++) {
      if (!isSeatLocked(i) && !isSeatOccupied(i)) {
        availableSeats.add(i);
      }
    }

    return availableSeats;
  }

  /// Get participant by userId
  AudioRoomParticipant? getParticipant(String userId) {
    try {
      return participants.firstWhere((p) => p.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user can move to a seat
  bool canUserMoveToSeat(String userId, int seatNumber) {
    // User must be a participant
    if (!isParticipant(userId)) return false;

    // Seat number must be valid (seats are 1-indexed, from 1 to seatConfiguration.length)
    if (seatNumber < 1 || seatNumber > settings.seatConfiguration.length) {
      return false;
    }

    // Check if user is blocked from taking a seat
    final participant = getParticipant(userId);
    if (participant != null && participant.isSeatBlocked) {
      return false;
    }

    // Check if user is creator or admin
    final bool isUserCreatorOrAdmin = isCreator(userId) || settings.adminIds.contains(userId);

    // Special case: Seat 1 is exclusively reserved for the room creator or admins
    if (seatNumber == 1 && !isUserCreatorOrAdmin) {
      return false;
    }

    // Special case: If user is the creator/admin, they can move to any seat
    // even if it's occupied (they can kick the current occupant) or locked
    if (isUserCreatorOrAdmin) {
      return true;
    }

    // Seat must not be locked
    if (isSeatLocked(seatNumber)) return false;

    // For regular participants, seat must not be occupied
    if (isSeatOccupied(seatNumber)) return false;

    return true;
  }

  /// Get room level based on total revenue
  /// Level 0: 0-4999
  /// Level 1: 5000-9999
  /// ...
  /// Max Level: 20
  /// Max Level: 20
  int get roomLevel {
    return calculateRoomLevel(totalRevenue, null);
  }

  /// Get progress to next level (0.0 to 1.0)
  double get levelProgress {
    return calculateLevelProgress(totalRevenue, roomLevel, null);
  }

  /// Calculate room level based on Firebase config
  static int calculateRoomLevel(int revenue, List<dynamic>? config) {
    if (config == null || config.isEmpty) {
      // Default hardcoded logic
      final level = (revenue / 5000).floor();
      return level.clamp(0, 20);
    }
    
    // Sort config by diamondRequirement descending to find highest level met
    final sortedConfig = List<Map<String, dynamic>>.from(config);
    sortedConfig.sort((a, b) => ((b['diamondRequirement'] ?? 0) as num).compareTo((a['diamondRequirement'] ?? 0) as num));
    
    for (final levelInfo in sortedConfig) {
      final req = (levelInfo['diamondRequirement'] ?? 0) as num;
      if (revenue >= req) {
        return levelInfo['levelNumber'] as int;
      }
    }
    return 0; // Default if no requirements met
  }

  /// Calculate level progress based on Firebase config
  static double calculateLevelProgress(int revenue, int currentLevel, List<dynamic>? config) {
    if (config == null || config.isEmpty) {
      if (currentLevel >= 20) return 1.0;
      final currentLevelBase = currentLevel * 5000;
      final progress = (revenue - currentLevelBase) / 5000;
      return progress.clamp(0.0, 1.0);
    }
    
    final sortedConfig = List<Map<String, dynamic>>.from(config);
    sortedConfig.sort((a, b) => ((a['diamondRequirement'] ?? 0) as num).compareTo((b['diamondRequirement'] ?? 0) as num));
    
    int maxLevel = 0;
    if (sortedConfig.isNotEmpty) {
      maxLevel = sortedConfig.last['levelNumber'] as int;
    }
    
    if (currentLevel >= maxLevel) return 1.0;
    
    num currentReq = 0;
    num nextReq = 0;
    
    for (int i = 0; i < sortedConfig.length; i++) {
      final levelInfo = sortedConfig[i];
      if (levelInfo['levelNumber'] == currentLevel) {
        currentReq = (levelInfo['diamondRequirement'] ?? 0) as num;
        if (i + 1 < sortedConfig.length) {
          nextReq = (sortedConfig[i + 1]['diamondRequirement'] ?? 0) as num;
        }
        break;
      } else if (levelInfo['levelNumber'] > currentLevel) {
        // Fallback if currentLevel exactly not found
        nextReq = (levelInfo['diamondRequirement'] ?? 0) as num;
        break;
      }
    }
    
    if (nextReq <= currentReq) return 1.0; // Prevent division by zero
    
    final progress = (revenue - currentReq) / (nextReq - currentReq);
    return progress.clamp(0.0, 1.0);
  }

  /// Calculate the diamond requirement for the next level based on Firebase config
  static int calculateNextLevelRequirement(int currentLevel, List<dynamic>? config) {
    if (config == null || config.isEmpty) {
      return (currentLevel + 1) * 5000;
    }
    
    final sortedConfig = List<Map<String, dynamic>>.from(config);
    sortedConfig.sort((a, b) => ((a['diamondRequirement'] ?? 0) as num).compareTo((b['diamondRequirement'] ?? 0) as num));
    
    for (int i = 0; i < sortedConfig.length; i++) {
      final levelInfo = sortedConfig[i];
      if (levelInfo['levelNumber'] == currentLevel) {
        if (i + 1 < sortedConfig.length) {
          return (sortedConfig[i + 1]['diamondRequirement'] ?? 0) as int;
        }
        return (levelInfo['diamondRequirement'] ?? 0) as int; // Max level reached
      } else if (levelInfo['levelNumber'] > currentLevel) {
        return (levelInfo['diamondRequirement'] ?? 0) as int;
      }
    }
    
    return 5000; // Default fallback
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        creatorId,
        creatorName,
        creatorImageUrl,
        participants,
        createdAt,
        updatedAt,
        isActive,
        maxParticipants,
        totalRevenue,
        dailyRevenue,
        weeklyRevenue,
        monthlyRevenue,
        settings,
        contributors,
        pkBattleState,
        category,
        joinedUserIds,
        joinRequests,
        membersLastActive,
        removedUsers,
        roomLink,
        isVotingActive,
        isBanned,
        banEndTime,
        groupId,
        isGroupRoom,
        isPrivate,
        allowedUserIds,
        trendingScore,
        onlineCount,
        uniqueJoiners10m,
        giftCoins10m,
        likes10m,
        messages10m,
        activeSpeakers,
        avgStayTime,
        growthRate,
        lastCalculated,
        recentGiftsDiamonds,
        countryCode,
        isOfficial,
      ];
}

/// Audio Room Participant Model
class AudioRoomParticipant extends Equatable {
  final String userId;
  final String userName;
  final String? userImageUrl;
  final DateTime joinedAt;
  final bool isMuted;
  final bool isMutedByAdmin; // Muted by admin (cannot be unmuted by self)
  final bool isSpeaker;
  final bool isHost;
  final int? seatNumber; // Which seat the participant is in
  final bool isSeated; // Whether participant is currently seated
  final String? activeEmojiUrl; // Currently active reaction emoji URL
  final String? frameId; // Avatar frame ID
  final bool isMessagingBlocked; // Whether user is blocked from messaging
  final bool isSeatBlocked; // Whether user is blocked from taking a seat

  const AudioRoomParticipant({
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.joinedAt,
    this.isMuted = false,
    this.isMutedByAdmin = false,
    this.isSpeaker = false,
    this.isHost = false,
    this.seatNumber,
    this.isSeated = false,
    this.activeEmojiUrl,
    this.frameId,
    this.isMessagingBlocked = false,
    this.isSeatBlocked = false,
  });

  /// Create from JSON
  factory AudioRoomParticipant.fromJson(Map<String, dynamic> json) {
    try {
      return AudioRoomParticipant(
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? '',
        userImageUrl: json['userImageUrl'],
        joinedAt: _parseDateTime(json['joinedAt']),
        isMuted: _parseBool(json['isMuted']),
        isMutedByAdmin: _parseBool(json['isMutedByAdmin']),
        isSpeaker: _parseBool(json['isSpeaker']),
        isHost: _parseBool(json['isHost']),
        seatNumber: json['seatNumber'],
        isSeated: _parseBool(json['isSeated']),
        activeEmojiUrl: json['activeEmojiUrl'],
        frameId: json['frameId'],
        isMessagingBlocked: _parseBool(json['isMessagingBlocked']),
        isSeatBlocked: _parseBool(json['isSeatBlocked']),
      );
    } catch (e) {
      throw Exception('Error parsing AudioRoomParticipant from JSON: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isMuted': isMuted,
      'isMutedByAdmin': isMutedByAdmin,
      'isSpeaker': isSpeaker,
      'isHost': isHost,
      'seatNumber': seatNumber,
      'isSeated': isSeated,
      'activeEmojiUrl': activeEmojiUrl,
      'frameId': frameId,
      'isMessagingBlocked': isMessagingBlocked,
      'isSeatBlocked': isSeatBlocked,
    };
  }

  /// Create a copy with updated fields
  AudioRoomParticipant copyWith({
    String? userId,
    String? userName,
    String? userImageUrl,
    DateTime? joinedAt,
    bool? isMuted,
    bool? isMutedByAdmin,
    bool? isSpeaker,
    bool? isHost,
    int? seatNumber,
    bool? isSeated,
    String? activeEmojiUrl,
    String? frameId,
    bool? isMessagingBlocked,
    bool? isSeatBlocked,
    bool clearSeatNumber = false, // Flag to explicitly clear seat number
    bool clearActiveEmoji = false, // Flag to explicitly clear active emoji
  }) {
    return AudioRoomParticipant(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      isMuted: isMuted ?? this.isMuted,
      isMutedByAdmin: isMutedByAdmin ?? this.isMutedByAdmin,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isHost: isHost ?? this.isHost,
      seatNumber: clearSeatNumber ? null : (seatNumber ?? this.seatNumber),
      isSeated: isSeated ?? this.isSeated,
      activeEmojiUrl:
          clearActiveEmoji ? null : (activeEmojiUrl ?? this.activeEmojiUrl),
      frameId: frameId ?? this.frameId,
      isMessagingBlocked: isMessagingBlocked ?? this.isMessagingBlocked,
      isSeatBlocked: isSeatBlocked ?? this.isSeatBlocked,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        userName,
        userImageUrl,
        joinedAt,
        isMuted,
        isMutedByAdmin,
        isSpeaker,
        isHost,
        seatNumber,
        isSeated,
        activeEmojiUrl,
        frameId,
        isMessagingBlocked,
        isSeatBlocked,
      ];
}

/// Seat Management Model
class SeatInfo extends Equatable {
  final int seatNumber;
  final bool isLocked;
  final String? occupiedBy; // userId of participant
  final DateTime? lockedAt;
  final String? lockedBy; // userId of host who locked it

  const SeatInfo({
    required this.seatNumber,
    this.isLocked = false,
    this.occupiedBy,
    this.lockedAt,
    this.lockedBy,
  });

  factory SeatInfo.fromJson(Map<String, dynamic> json) {
    return SeatInfo(
      seatNumber: json['seatNumber'] ?? 0,
      isLocked: json['isLocked'] ?? false,
      occupiedBy: json['occupiedBy'],
      lockedAt: json['lockedAt'] != null
          ? _parseDateTime(json['lockedAt'])
          : null,
      lockedBy: json['lockedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seatNumber': seatNumber,
      'isLocked': isLocked,
      'occupiedBy': occupiedBy,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'lockedBy': lockedBy,
    };
  }

  SeatInfo copyWith({
    int? seatNumber,
    bool? isLocked,
    String? occupiedBy,
    DateTime? lockedAt,
    String? lockedBy,
  }) {
    return SeatInfo(
      seatNumber: seatNumber ?? this.seatNumber,
      isLocked: isLocked ?? this.isLocked,
      occupiedBy: occupiedBy ?? this.occupiedBy,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedBy: lockedBy ?? this.lockedBy,
    );
  }

  @override
  List<Object?> get props =>
      [seatNumber, isLocked, occupiedBy, lockedAt, lockedBy];
}

/// Blocked User Model
class BlockedUser extends Equatable {
  final String userId;
  final String userName;
  final String? userImageUrl;
  final DateTime blockedAt;
  final String blockedBy;
  final String reason;

  const BlockedUser({
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.blockedAt,
    required this.blockedBy,
    this.reason = 'Removed by host',
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userImageUrl: json['userImageUrl'],
      blockedAt: _parseDateTime(json['blockedAt']),
      blockedBy: json['blockedBy'] ?? '',
      reason: json['reason'] ?? 'Removed by host',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'blockedBy': blockedBy,
      'reason': reason,
    };
  }

  @override
  List<Object?> get props =>
      [userId, userName, userImageUrl, blockedAt, blockedBy, reason];
}

/// Audio Room Settings Model
class AudioRoomSettings extends Equatable {
  final bool allowRequestToSpeak;
  final bool autoMuteNewParticipants;
  final bool allowBackgroundMusic;
  final int maxSpeakers;
  final bool recordSession;
  // Use maxSpeakers as seat count - existing Firebase field
  final String? backgroundImageUrl;
  final String? announcement;
  final bool musicEnabled;
  final String? musicUrl;
  final RoomMode roomMode;
  final SeatColorMode seatColorMode;
  final List<SeatInfo> seatConfiguration;
  final List<BlockedUser> blockedUsers;
  final List<String> adminIds; // Persistent admin IDs (userIds)
  final String? seatDecorUrl;
  final String? lockedSeatDecorUrl;
  final String? hostSeatDecorUrl;
  final bool isLiveMultipleMode;

  const AudioRoomSettings({
    this.allowRequestToSpeak = true,
    this.autoMuteNewParticipants = true,
    this.allowBackgroundMusic = false,
    this.maxSpeakers = 8,
    this.recordSession = false,
    this.isLiveMultipleMode = false,
    // maxSpeakers is used as seat count
    this.backgroundImageUrl,
    this.announcement,
    this.musicEnabled = false,
    this.musicUrl,
    this.roomMode = RoomMode.lite, // Changed from immersive (removed mode)
    this.seatColorMode = SeatColorMode.original,
    this.seatConfiguration = const [],
    this.blockedUsers = const [],
    this.adminIds = const [],
    this.seatDecorUrl,
    this.lockedSeatDecorUrl,
    this.hostSeatDecorUrl,
  });

  /// Create from JSON
  factory AudioRoomSettings.fromJson(Map<String, dynamic> json) {
    try {
      return AudioRoomSettings(
        allowRequestToSpeak: _parseBool(json['allowRequestToSpeak'], defaultValue: true),
        autoMuteNewParticipants: _parseBool(json['autoMuteNewParticipants'], defaultValue: true),
        allowBackgroundMusic: _parseBool(json['allowBackgroundMusic']),
        maxSpeakers: json['maxSpeakers'] ?? 8,
        recordSession: _parseBool(json['recordSession']),
        isLiveMultipleMode: _parseBool(json['isLiveMultipleMode']),
        // maxSpeakers is used as seat count
        backgroundImageUrl: json['backgroundImageUrl'],
        announcement: json['announcement'],
        musicEnabled: _parseBool(json['musicEnabled']),
        musicUrl: json['musicUrl'],
        roomMode: json['roomMode'] != null
            ? RoomModeExtension.fromJson(json['roomMode'].toString())
            : RoomMode.lite, // Changed from immersive (removed mode)
        seatColorMode: json['seatColorMode'] != null
            ? SeatColorModeExtension.fromJson(json['seatColorMode'].toString())
            : SeatColorMode.original,
        seatConfiguration: (json['seatConfiguration'] as List<dynamic>?)
                ?.map((s) => SeatInfo.fromJson(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
        blockedUsers: (json['blockedUsers'] as List<dynamic>?)
                ?.map((b) => BlockedUser.fromJson(Map<String, dynamic>.from(b as Map)))
                .toList() ??
            [],
        adminIds: (json['adminIds'] as List<dynamic>?)
                ?.map((id) => id.toString())
                .toList() ??
            [],
        seatDecorUrl: json['seatDecorUrl'],
        lockedSeatDecorUrl: json['lockedSeatDecorUrl'],
        hostSeatDecorUrl: json['hostSeatDecorUrl'],
      );
    } catch (e) {
      throw Exception('Error parsing AudioRoomSettings from JSON: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'allowRequestToSpeak': allowRequestToSpeak,
      'autoMuteNewParticipants': autoMuteNewParticipants,
      'allowBackgroundMusic': allowBackgroundMusic,
      'maxSpeakers': maxSpeakers,
      'recordSession': recordSession,
      'isLiveMultipleMode': isLiveMultipleMode,
      // maxSpeakers is used as seat count
      'backgroundImageUrl': backgroundImageUrl,
      'announcement': announcement,
      'musicEnabled': musicEnabled,
      'musicUrl': musicUrl,
      'roomMode': roomMode.toJson(),
      'seatColorMode': seatColorMode.toJson(),
      'seatConfiguration': seatConfiguration.map((s) => s.toJson()).toList(),
      'blockedUsers': blockedUsers.map((b) => b.toJson()).toList(),
      'adminIds': adminIds,
      'seatDecorUrl': seatDecorUrl,
      'lockedSeatDecorUrl': lockedSeatDecorUrl,
      'hostSeatDecorUrl': hostSeatDecorUrl,
    };
  }

  /// Create a copy with updated fields
  AudioRoomSettings copyWith({
    bool? allowRequestToSpeak,
    bool? autoMuteNewParticipants,
    bool? allowBackgroundMusic,
    int? maxSpeakers,
    bool? recordSession,
    bool? isLiveMultipleMode,
    // maxSpeakers is used as seat count
    String? backgroundImageUrl,
    String? announcement,
    bool? musicEnabled,
    String? musicUrl,
    RoomMode? roomMode,
    SeatColorMode? seatColorMode,
    List<SeatInfo>? seatConfiguration,
    List<BlockedUser>? blockedUsers,
    List<String>? adminIds,
    String? seatDecorUrl,
    String? lockedSeatDecorUrl,
    String? hostSeatDecorUrl,
    bool clearBackgroundImage = false,
    bool clearSeatDecor = false,
  }) {
    return AudioRoomSettings(
      allowRequestToSpeak: allowRequestToSpeak ?? this.allowRequestToSpeak,
      autoMuteNewParticipants:
          autoMuteNewParticipants ?? this.autoMuteNewParticipants,
      allowBackgroundMusic: allowBackgroundMusic ?? this.allowBackgroundMusic,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      recordSession: recordSession ?? this.recordSession,
      isLiveMultipleMode: isLiveMultipleMode ?? this.isLiveMultipleMode,
      // maxSpeakers is used as seat count
      backgroundImageUrl: clearBackgroundImage ? null : (backgroundImageUrl ?? this.backgroundImageUrl),
      announcement: announcement ?? this.announcement,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicUrl: musicUrl ?? this.musicUrl,
      roomMode: roomMode ?? this.roomMode,
      seatColorMode: seatColorMode ?? this.seatColorMode,
      seatConfiguration: seatConfiguration ?? this.seatConfiguration,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      adminIds: adminIds ?? this.adminIds,
      seatDecorUrl: clearSeatDecor ? null : (seatDecorUrl ?? this.seatDecorUrl),
      lockedSeatDecorUrl: clearSeatDecor ? null : (lockedSeatDecorUrl ?? this.lockedSeatDecorUrl),
      hostSeatDecorUrl: clearSeatDecor ? null : (hostSeatDecorUrl ?? this.hostSeatDecorUrl),
    );
  }

  @override
  List<Object?> get props => [
        allowRequestToSpeak,
        autoMuteNewParticipants,
        allowBackgroundMusic,
        maxSpeakers,
        recordSession,
        isLiveMultipleMode,
        // maxSpeakers is used as seat count
        backgroundImageUrl,
        announcement,
        musicEnabled,
        musicUrl,
        roomMode,
        seatColorMode,
        seatConfiguration,
        blockedUsers,
        adminIds,
        seatDecorUrl,
        lockedSeatDecorUrl,
        hostSeatDecorUrl,
      ];
}
