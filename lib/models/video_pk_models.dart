import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'audio_room_v2.dart';

/// Configuration for PK Battle visual effects (SVGA/WebP/GIF animations)
class PkEffectsConfig extends Equatable {
  final String? countdownSvgaUrl;
  final String? openingSvgaUrl;
  final String? winnerSvgaUrl;
  final String? drawSvgaUrl;
  final String? progressSvgaUrl;
  final int countdownSeconds;
  final bool isEnabled;

  const PkEffectsConfig({
    this.countdownSvgaUrl,
    this.openingSvgaUrl,
    this.winnerSvgaUrl,
    this.drawSvgaUrl,
    this.progressSvgaUrl,
    this.countdownSeconds = 3,
    this.isEnabled = true,
  });

  factory PkEffectsConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PkEffectsConfig();
    return PkEffectsConfig(
      countdownSvgaUrl: data['countdownSvgaUrl'] as String?,
      openingSvgaUrl: data['openingSvgaUrl'] as String?,
      winnerSvgaUrl: data['winnerSvgaUrl'] as String?,
      drawSvgaUrl: data['drawSvgaUrl'] as String?,
      progressSvgaUrl:
          (data['progressSvgaUrl'] ?? data['drawSvgaUrl']) as String?,
      countdownSeconds: (data['countdownSeconds'] as num?)?.toInt() ?? 3,
      isEnabled: data['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'countdownSvgaUrl': countdownSvgaUrl,
        'openingSvgaUrl': openingSvgaUrl,
        'winnerSvgaUrl': winnerSvgaUrl,
        'drawSvgaUrl': drawSvgaUrl,
        'progressSvgaUrl': progressSvgaUrl,
        'countdownSeconds': countdownSeconds,
        'isEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [
        countdownSvgaUrl,
        openingSvgaUrl,
        winnerSvgaUrl,
        drawSvgaUrl,
        progressSvgaUrl,
        countdownSeconds,
        isEnabled,
      ];
}

/// Contributor (gifter) supporting a host in PK battle
class VideoPkContributor {
  final String userId;
  final String userName;
  final String? userPhoto;
  final int points;

  const VideoPkContributor({
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.points,
  });

  factory VideoPkContributor.fromMap(Map<String, dynamic> json) {
    return VideoPkContributor(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'User',
      userPhoto: json['userPhoto'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'points': points,
      };
}

/// Active or concluded Live Video PK Battle
class VideoPkBattleModel {
  final String id;
  final String room1Id;
  final String room2Id;
  final String host1Id;
  final String host2Id;
  final String host1Name;
  final String host2Name;
  final String? host1Photo;
  final String? host2Photo;
  final String host1Channel;
  final String host2Channel;
  final int? host1AgoraUid;
  final int? host2AgoraUid;
  final int host1Score;
  final int host2Score;
  final int host1Streak;
  final int host2Streak;
  final Map<String, VideoPkContributor> host1Contributors;
  final Map<String, VideoPkContributor> host2Contributors;
  final int durationSeconds;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String status; // 'active', 'punishment', 'ended', 'cancelled'
  final String? winnerId; // hostId or 'draw'
  final DateTime createdAt;

  const VideoPkBattleModel({
    required this.id,
    required this.room1Id,
    required this.room2Id,
    required this.host1Id,
    required this.host2Id,
    required this.host1Name,
    required this.host2Name,
    this.host1Photo,
    this.host2Photo,
    required this.host1Channel,
    required this.host2Channel,
    this.host1AgoraUid,
    this.host2AgoraUid,
    this.host1Score = 0,
    this.host2Score = 0,
    this.host1Streak = 0,
    this.host2Streak = 0,
    this.host1Contributors = const {},
    this.host2Contributors = const {},
    this.durationSeconds = 300,
    this.startedAt,
    this.endsAt,
    this.status = 'active',
    this.winnerId,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPunishment => status == 'punishment';
  bool get isEnded => status == 'ended' || status == 'cancelled';

  int get remainingSeconds {
    if (endsAt == null) return durationSeconds;
    final diff = endsAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory VideoPkBattleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, VideoPkContributor> parseContributors(dynamic raw) {
      if (raw is! Map) return {};
      final map = <String, VideoPkContributor>{};
      raw.forEach((key, val) {
        if (val is Map) {
          final cMap = Map<String, dynamic>.from(val);
          map[key.toString()] = VideoPkContributor.fromMap({
            'userId': cMap['userId'] ?? key.toString(),
            'userName': cMap['userName'] ?? cMap['name'] ?? 'User',
            'userPhoto': cMap['userPhoto'] ?? cMap['photo'],
            'points': cMap['points'] ?? 0,
          });
        }
      });
      return map;
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return VideoPkBattleModel(
      id: doc.id,
      room1Id: data['room1Id'] as String? ?? '',
      room2Id: data['room2Id'] as String? ?? '',
      host1Id: data['host1Id'] as String? ?? '',
      host2Id: data['host2Id'] as String? ?? '',
      host1Name: data['host1Name'] as String? ?? 'Host 1',
      host2Name: data['host2Name'] as String? ?? 'Host 2',
      host1Photo: data['host1Photo'] as String?,
      host2Photo: data['host2Photo'] as String?,
      host1Channel: data['host1Channel'] as String? ?? '',
      host2Channel: data['host2Channel'] as String? ?? '',
      host1AgoraUid: (data['host1AgoraUid'] as num?)?.toInt(),
      host2AgoraUid: (data['host2AgoraUid'] as num?)?.toInt(),
      host1Score: (data['host1Score'] as num?)?.toInt() ?? 0,
      host2Score: (data['host2Score'] as num?)?.toInt() ?? 0,
      host1Streak: (data['host1Streak'] as num?)?.toInt() ?? 0,
      host2Streak: (data['host2Streak'] as num?)?.toInt() ?? 0,
      host1Contributors: parseContributors(data['host1Contributors']),
      host2Contributors: parseContributors(data['host2Contributors']),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 300,
      startedAt: parseDate(data['startedAt']),
      endsAt: parseDate(data['endsAt']),
      status: data['status'] as String? ?? 'active',
      winnerId: data['winnerId'] as String?,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'room1Id': room1Id,
      'room2Id': room2Id,
      'host1Id': host1Id,
      'host2Id': host2Id,
      'host1Name': host1Name,
      'host2Name': host2Name,
      'host1Photo': host1Photo,
      'host2Photo': host2Photo,
      'host1Channel': host1Channel,
      'host2Channel': host2Channel,
      'host1AgoraUid': host1AgoraUid,
      'host2AgoraUid': host2AgoraUid,
      'host1Score': host1Score,
      'host2Score': host2Score,
      'host1Streak': host1Streak,
      'host2Streak': host2Streak,
      'durationSeconds': durationSeconds,
      'startedAt': startedAt != null
          ? Timestamp.fromDate(startedAt!)
          : FieldValue.serverTimestamp(),
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      'status': status,
      'winnerId': winnerId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Invitation to start a PK Battle
class VideoPkInvitationModel {
  final String id;
  final String fromRoomId;
  final String fromHostId;
  final String fromHostName;
  final String? fromHostPhoto;
  final int? fromAgoraUid;
  final String toRoomId;
  final String toHostId;
  final String toHostName;
  final String? toHostPhoto;
  final int? toAgoraUid;
  final int durationSeconds;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final DateTime createdAt;

  const VideoPkInvitationModel({
    required this.id,
    required this.fromRoomId,
    required this.fromHostId,
    required this.fromHostName,
    this.fromHostPhoto,
    this.fromAgoraUid,
    required this.toRoomId,
    required this.toHostId,
    required this.toHostName,
    this.toHostPhoto,
    this.toAgoraUid,
    this.durationSeconds = 300,
    this.status = 'pending',
    required this.createdAt,
  });

  int get remainingSeconds {
    final diff = DateTime.now().difference(createdAt).inSeconds;
    return (30 - diff).clamp(0, 30);
  }

  bool get isExpired => remainingSeconds <= 0;

  factory VideoPkInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return VideoPkInvitationModel(
      id: doc.id,
      fromRoomId: data['fromRoomId'] as String? ?? '',
      fromHostId: data['fromHostId'] as String? ?? '',
      fromHostName: data['fromHostName'] as String? ?? 'Host',
      fromHostPhoto: data['fromHostPhoto'] as String?,
      fromAgoraUid: (data['fromAgoraUid'] as num?)?.toInt(),
      toRoomId: data['toRoomId'] as String? ?? '',
      toHostId: data['toHostId'] as String? ?? '',
      toHostName: data['toHostName'] as String? ?? 'Host',
      toHostPhoto: data['toHostPhoto'] as String?,
      toAgoraUid: (data['toAgoraUid'] as num?)?.toInt(),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 300,
      status: data['status'] as String? ?? 'pending',
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromRoomId': fromRoomId,
      'fromHostId': fromHostId,
      'fromHostName': fromHostName,
      'fromHostPhoto': fromHostPhoto,
      'fromAgoraUid': fromAgoraUid,
      'toRoomId': toRoomId,
      'toHostId': toHostId,
      'toHostName': toHostName,
      'toHostPhoto': toHostPhoto,
      'toAgoraUid': toAgoraUid,
      'durationSeconds': durationSeconds,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Representation of an active Live video room host available for PK challenge
class OnlineVideoHost {
  final String roomId;
  final String hostId;
  final String hostName;
  final String hostPhotoUrl;
  final int viewerCount;

  const OnlineVideoHost({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.hostPhotoUrl,
    required this.viewerCount,
  });

  factory OnlineVideoHost.fromRoom(AudioRoomV2 room) {
    return OnlineVideoHost(
      roomId: room.id,
      hostId: room.creatorId,
      hostName: room.creatorName,
      hostPhotoUrl: room.creatorImageUrl ?? '',
      viewerCount: room.participants.length,
    );
  }
}
