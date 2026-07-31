import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum RoomPKMatchState {
  waiting,
  active,
  punishment,
  finished,
}

class RoomPKMatch extends Equatable {
  final String id;
  final String leftRoomId;
  final String rightRoomId;
  final RoomPKMatchState state;
  final DateTime createdAt;
  final DateTime? startTime;
  final int durationMinutes;
  
  // Scores
  final int leftRoomScore;
  final int rightRoomScore;
  
  // Basic info for quick UI rendering without needing to fetch full room docs
  final String leftRoomName;
  final String leftRoomImageUrl;
  final String rightRoomName;
  final String rightRoomImageUrl;

  const RoomPKMatch({
    required this.id,
    required this.leftRoomId,
    required this.rightRoomId,
    this.state = RoomPKMatchState.waiting,
    required this.createdAt,
    this.startTime,
    this.durationMinutes = 5,
    this.leftRoomScore = 0,
    this.rightRoomScore = 0,
    required this.leftRoomName,
    required this.leftRoomImageUrl,
    required this.rightRoomName,
    required this.rightRoomImageUrl,
  });

  factory RoomPKMatch.fromJson(Map<String, dynamic> json, String id) {
    return RoomPKMatch(
      id: id,
      leftRoomId: json['leftRoomId'] ?? '',
      rightRoomId: json['rightRoomId'] ?? '',
      state: RoomPKMatchState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => RoomPKMatchState.waiting,
      ),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      startTime: json['startTime'] != null
          ? (json['startTime'] as Timestamp).toDate()
          : null,
      durationMinutes: json['durationMinutes'] ?? 5,
      leftRoomScore: json['leftRoomScore'] ?? 0,
      rightRoomScore: json['rightRoomScore'] ?? 0,
      leftRoomName: json['leftRoomName'] ?? '',
      leftRoomImageUrl: json['leftRoomImageUrl'] ?? '',
      rightRoomName: json['rightRoomName'] ?? '',
      rightRoomImageUrl: json['rightRoomImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leftRoomId': leftRoomId,
      'rightRoomId': rightRoomId,
      'state': state.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'durationMinutes': durationMinutes,
      'leftRoomScore': leftRoomScore,
      'rightRoomScore': rightRoomScore,
      'leftRoomName': leftRoomName,
      'leftRoomImageUrl': leftRoomImageUrl,
      'rightRoomName': rightRoomName,
      'rightRoomImageUrl': rightRoomImageUrl,
    };
  }

  RoomPKMatch copyWith({
    String? id,
    String? leftRoomId,
    String? rightRoomId,
    RoomPKMatchState? state,
    DateTime? createdAt,
    DateTime? startTime,
    int? durationMinutes,
    int? leftRoomScore,
    int? rightRoomScore,
    String? leftRoomName,
    String? leftRoomImageUrl,
    String? rightRoomName,
    String? rightRoomImageUrl,
  }) {
    return RoomPKMatch(
      id: id ?? this.id,
      leftRoomId: leftRoomId ?? this.leftRoomId,
      rightRoomId: rightRoomId ?? this.rightRoomId,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      leftRoomScore: leftRoomScore ?? this.leftRoomScore,
      rightRoomScore: rightRoomScore ?? this.rightRoomScore,
      leftRoomName: leftRoomName ?? this.leftRoomName,
      leftRoomImageUrl: leftRoomImageUrl ?? this.leftRoomImageUrl,
      rightRoomName: rightRoomName ?? this.rightRoomName,
      rightRoomImageUrl: rightRoomImageUrl ?? this.rightRoomImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        leftRoomId,
        rightRoomId,
        state,
        createdAt,
        startTime,
        durationMinutes,
        leftRoomScore,
        rightRoomScore,
        leftRoomName,
        leftRoomImageUrl,
        rightRoomName,
        rightRoomImageUrl,
      ];
}

enum RoomPKInviteStatus { pending, accepted, rejected, cancelled }

class RoomPKInvite extends Equatable {
  final String id;
  final String senderRoomId;
  final String targetRoomId;
  final String senderRoomName;
  final String senderRoomImageUrl;
  final int durationMinutes;
  final RoomPKInviteStatus status;
  final DateTime createdAt;

  const RoomPKInvite({
    required this.id,
    required this.senderRoomId,
    required this.targetRoomId,
    required this.senderRoomName,
    required this.senderRoomImageUrl,
    this.durationMinutes = 5,
    this.status = RoomPKInviteStatus.pending,
    required this.createdAt,
  });

  factory RoomPKInvite.fromJson(Map<String, dynamic> json, String id) {
    return RoomPKInvite(
      id: id,
      senderRoomId: json['senderRoomId'] ?? '',
      targetRoomId: json['targetRoomId'] ?? '',
      senderRoomName: json['senderRoomName'] ?? '',
      senderRoomImageUrl: json['senderRoomImageUrl'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 5,
      status: RoomPKInviteStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RoomPKInviteStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderRoomId': senderRoomId,
      'targetRoomId': targetRoomId,
      'senderRoomName': senderRoomName,
      'senderRoomImageUrl': senderRoomImageUrl,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
        id,
        senderRoomId,
        targetRoomId,
        senderRoomName,
        senderRoomImageUrl,
        durationMinutes,
        status,
        createdAt,
      ];
}
