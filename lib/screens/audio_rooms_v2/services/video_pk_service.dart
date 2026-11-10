import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/video_pk_models.dart';
import '../../../models/audio_room_v2.dart';

/// Complete Firebase Firestore Service for Live Video Room PK Battles
class VideoPkService {
  VideoPkService._internal();
  static final VideoPkService _instance = VideoPkService._internal();
  factory VideoPkService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _battlesCol =>
      _firestore.collection('video_pk_battles');
  CollectionReference get _invitesCol =>
      _firestore.collection('video_pk_invitations');
  CollectionReference get _roomsCol =>
      _firestore.collection('audio_rooms_v2');

  /// Stream active or punishment PK battle involving a specific room
  Stream<VideoPkBattleModel?> streamActiveBattle(String roomId) {
    if (roomId.isEmpty) return Stream.value(null);

    return _battlesCol
        .where('status', whereIn: ['active', 'punishment'])
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final r1 = data['room1Id'] as String? ?? '';
            final r2 = data['room2Id'] as String? ?? '';
            if (r1 == roomId || r2 == roomId) {
              return VideoPkBattleModel.fromFirestore(doc);
            }
          }
          return null;
        });
  }

  /// Stream incoming pending PK invitations for a host
  Stream<List<VideoPkInvitationModel>> streamIncomingInvitations(
      String hostId, String roomId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _invitesCol
        .where('toHostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => VideoPkInvitationModel.fromFirestore(doc))
          .where((invite) {
        // Expire older than 30 seconds
        return now.difference(invite.createdAt).inSeconds < 30;
      }).toList();
    });
  }

  /// Stream PK effects config from app_config/pk_effects
  Stream<PkEffectsConfig> streamEffectsConfig() {
    return _firestore
        .collection('app_config')
        .doc('pk_effects')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return const PkEffectsConfig();
      return PkEffectsConfig.fromMap(doc.data());
    });
  }

  /// Send PK Battle Invitation to another Live Video Host (Live rooms only!)
  Future<String> sendInvitation({
    required String fromRoomId,
    required String fromHostId,
    required String fromHostName,
    String? fromHostPhoto,
    int? fromAgoraUid,
    required String toRoomId,
    required String toHostId,
    required String toHostName,
    String? toHostPhoto,
    int? toAgoraUid,
    int durationSeconds = 300,
  }) async {
    // 1. Validate that the target room is an active Live Video Room
    final toRoomDoc = await _roomsCol.doc(toRoomId).get();
    if (!toRoomDoc.exists) {
      throw Exception('Target room not found or closed.');
    }
    final toData = toRoomDoc.data() as Map<String, dynamic>?;
    if (toData?['category'] != 'Live') {
      throw Exception('Cannot challenge an Audio Room to Video PK! Video PK is only between Live Video Rooms.');
    }

    // 2. Validate that the sender room is an active Live Video Room
    final fromRoomDoc = await _roomsCol.doc(fromRoomId).get();
    if (!fromRoomDoc.exists) {
      throw Exception('Current room not found.');
    }
    final fromData = fromRoomDoc.data() as Map<String, dynamic>?;
    if (fromData?['category'] != 'Live') {
      throw Exception('Audio rooms cannot send Live Video PK challenges.');
    }

    final docRef = _invitesCol.doc();
    final invite = VideoPkInvitationModel(
      id: docRef.id,
      fromRoomId: fromRoomId,
      fromHostId: fromHostId,
      fromHostName: fromHostName,
      fromHostPhoto: fromHostPhoto,
      fromAgoraUid: fromAgoraUid,
      toRoomId: toRoomId,
      toHostId: toHostId,
      toHostName: toHostName,
      toHostPhoto: toHostPhoto,
      toAgoraUid: toAgoraUid,
      durationSeconds: durationSeconds,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await docRef.set(invite.toFirestore());
    return docRef.id;
  }

  /// Accept incoming PK Battle Invitation and initiate active battle (Live rooms only!)
  Future<String> acceptInvitation(String invitationId) async {
    final inviteDoc = await _invitesCol.doc(invitationId).get();
    if (!inviteDoc.exists) {
      throw Exception('Invitation not found or has expired.');
    }

    final invite = VideoPkInvitationModel.fromFirestore(inviteDoc);
    if (invite.status != 'pending') {
      throw Exception('Invitation is no longer pending.');
    }

    // Validate both rooms are Live rooms
    final fromDoc = await _roomsCol.doc(invite.fromRoomId).get();
    final toDoc = await _roomsCol.doc(invite.toRoomId).get();
    if (!fromDoc.exists || !toDoc.exists) {
      throw Exception('One of the rooms is no longer available.');
    }
    final fromCategory = (fromDoc.data() as Map<String, dynamic>?)?['category'];
    final toCategory = (toDoc.data() as Map<String, dynamic>?)?['category'];
    if (fromCategory != 'Live' || toCategory != 'Live') {
      throw Exception('Video PK Battle is only supported between Live Video Rooms.');
    }

    final battleDocRef = _battlesCol.doc();
    final now = DateTime.now();
    final endsAt = now.add(Duration(seconds: invite.durationSeconds));

    final battle = VideoPkBattleModel(
      id: battleDocRef.id,
      room1Id: invite.fromRoomId,
      room2Id: invite.toRoomId,
      host1Id: invite.fromHostId,
      host2Id: invite.toHostId,
      host1Name: invite.fromHostName,
      host2Name: invite.toHostName,
      host1Photo: invite.fromHostPhoto,
      host2Photo: invite.toHostPhoto,
      host1Channel: invite.fromRoomId,
      host2Channel: invite.toRoomId,
      host1AgoraUid: invite.fromAgoraUid,
      host2AgoraUid: invite.toAgoraUid,
      durationSeconds: invite.durationSeconds,
      startedAt: now,
      endsAt: endsAt,
      status: 'active',
      createdAt: now,
    );

    final batch = _firestore.batch();
    batch.set(battleDocRef, battle.toFirestore());
    batch.update(_invitesCol.doc(invitationId), {'status': 'accepted'});

    await batch.commit();
    return battleDocRef.id;
  }

  /// Reject incoming PK Battle Invitation
  Future<void> rejectInvitation(String invitationId) async {
    await _invitesCol.doc(invitationId).update({'status': 'rejected'});
  }

  /// Record gifts sent to host during active PK battle
  Future<void> recordGiftScore({
    required String battleId,
    required String targetHostId,
    required String userId,
    required String userName,
    String? userPhoto,
    required int giftDiamonds,
  }) async {
    if (battleId.isEmpty || giftDiamonds <= 0) return;

    try {
      final battleRef = _battlesCol.doc(battleId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(battleRef);
        if (!snapshot.exists) return;

        final battle = VideoPkBattleModel.fromFirestore(snapshot);
        if (!battle.isActive && !battle.isPunishment) return;

        final isHost1 = targetHostId == battle.host1Id;
        final isHost2 = targetHostId == battle.host2Id;
        if (!isHost1 && !isHost2) return;

        if (isHost1) {
          final newScore = battle.host1Score + giftDiamonds;
          final currentContributor = battle.host1Contributors[userId];
          final newPoints = (currentContributor?.points ?? 0) + giftDiamonds;

          final updateMap = <String, dynamic>{
            'host1Score': newScore,
            'host1Contributors.$userId': {
              'userId': userId,
              'userName': userName,
              'userPhoto': userPhoto ?? currentContributor?.userPhoto,
              'points': newPoints,
            },
          };
          transaction.update(battleRef, updateMap);
        } else {
          final newScore = battle.host2Score + giftDiamonds;
          final currentContributor = battle.host2Contributors[userId];
          final newPoints = (currentContributor?.points ?? 0) + giftDiamonds;

          final updateMap = <String, dynamic>{
            'host2Score': newScore,
            'host2Contributors.$userId': {
              'userId': userId,
              'userName': userName,
              'userPhoto': userPhoto ?? currentContributor?.userPhoto,
              'points': newPoints,
            },
          };
          transaction.update(battleRef, updateMap);
        }
      });
    } catch (e) {
      debugPrint('⚠️ [VideoPkService] Error recording PK gift score: $e');
    }
  }

  /// Start 60-second punishment phase when battle duration ends
  Future<void> startPunishment(String battleId,
      {int punishmentSeconds = 60}) async {
    final endsAt = DateTime.now().add(Duration(seconds: punishmentSeconds));
    await _battlesCol.doc(battleId).update({
      'status': 'punishment',
      'endsAt': Timestamp.fromDate(endsAt),
    });
  }

  /// End PK battle and calculate winner
  Future<void> endPkBattle(String battleId, [String? requestedByUserId]) async {
    try {
      final doc = await _battlesCol.doc(battleId).get();
      if (!doc.exists) return;

      final battle = VideoPkBattleModel.fromFirestore(doc);
      if (battle.isEnded) return;

      String winnerId;
      int newStreak1 = battle.host1Streak;
      int newStreak2 = battle.host2Streak;

      if (battle.host1Score > battle.host2Score) {
        winnerId = battle.host1Id;
        newStreak1++;
        newStreak2 = 0;
      } else if (battle.host2Score > battle.host1Score) {
        winnerId = battle.host2Id;
        newStreak2++;
        newStreak1 = 0;
      } else {
        winnerId = 'draw';
      }

      await _battlesCol.doc(battleId).update({
        'status': 'ended',
        'winnerId': winnerId,
        'host1Streak': newStreak1,
        'host2Streak': newStreak2,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ [VideoPkService] Error ending PK battle: $e');
    }
  }

  /// Cancel battle manually
  Future<void> cancelBattle(String battleId) async {
    await _battlesCol.doc(battleId).update({
      'status': 'cancelled',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Find another active Live Video Room host for quick matching
  Future<OnlineVideoHost?> findRandomVideoHost(String currentRoomId) async {
    try {
      final snapshot = await _roomsCol
          .where('category', isEqualTo: 'Live')
          .limit(15)
          .get();

      final candidateRooms = <OnlineVideoHost>[];
      for (final doc in snapshot.docs) {
        if (doc.id == currentRoomId) continue;
        final room = AudioRoomV2.fromFirestore(doc);
        candidateRooms.add(OnlineVideoHost.fromRoom(room));
      }

      if (candidateRooms.isEmpty) return null;
      candidateRooms.shuffle();
      return candidateRooms.first;
    } catch (e) {
      debugPrint('⚠️ [VideoPkService] Error finding random video host: $e');
      return null;
    }
  }

  /// Get list of all online Live Video rooms currently available
  Future<List<OnlineVideoHost>> getOnlineVideoHosts(String currentRoomId) async {
    try {
      final snapshot = await _roomsCol
          .where('category', isEqualTo: 'Live')
          .limit(25)
          .get();

      return snapshot.docs
          .where((doc) => doc.id != currentRoomId)
          .map((doc) => OnlineVideoHost.fromRoom(AudioRoomV2.fromFirestore(doc)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [VideoPkService] Error getting online video hosts: $e');
      return [];
    }
  }
}
