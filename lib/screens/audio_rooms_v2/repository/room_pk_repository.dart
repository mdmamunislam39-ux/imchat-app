import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/models/room_pk_match.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

class RoomPKRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collections
  final String _invitesCollection = 'room_pk_invites';
  final String _matchesCollection = 'room_pk_matches';
  final String _autoMatchCollection = 'room_pk_auto_match_queue';

  /// Send a Room PK Invite
  Future<void> sendInvite({
    required String senderRoomId,
    required String targetRoomId,
    required String senderRoomName,
    required String senderRoomImageUrl,
    required int durationMinutes,
  }) async {
    try {
      final docRef = _firestore.collection(_invitesCollection).doc();
      final invite = RoomPKInvite(
        id: docRef.id,
        senderRoomId: senderRoomId,
        targetRoomId: targetRoomId,
        senderRoomName: senderRoomName,
        senderRoomImageUrl: senderRoomImageUrl,
        durationMinutes: durationMinutes,
        status: RoomPKInviteStatus.pending,
        createdAt: DateTime.now(),
      );
      
      await docRef.set(invite.toJson());
      debugPrint('Sent Room PK Invite to $targetRoomId');
    } catch (e) {
      debugPrint('Error sending PK invite: $e');
      throw Exception('Failed to send PK invite');
    }
  }

  /// Listen to incoming invites for a specific room
  Stream<List<RoomPKInvite>> listenToIncomingInvites(String roomId) {
    return _firestore
        .collection(_invitesCollection)
        .where('targetRoomId', isEqualTo: roomId)
        .where('status', isEqualTo: RoomPKInviteStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomPKInvite.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  /// Accept an invite and create a match
  Future<RoomPKMatch> acceptInvite({
    required RoomPKInvite invite,
    required String targetRoomName,
    required String targetRoomImageUrl,
  }) async {
    try {
      // 1. Update invite status
      await _firestore.collection(_invitesCollection).doc(invite.id).update({
        'status': RoomPKInviteStatus.accepted.name,
      });

      // 2. Create the Match document
      final matchRef = _firestore.collection(_matchesCollection).doc();
      final startTime = DateTime.now();
      final match = RoomPKMatch(
        id: matchRef.id,
        leftRoomId: invite.senderRoomId,
        rightRoomId: invite.targetRoomId,
        state: RoomPKMatchState.active,
        createdAt: startTime,
        startTime: startTime,
        durationMinutes: invite.durationMinutes,
        leftRoomName: invite.senderRoomName,
        leftRoomImageUrl: invite.senderRoomImageUrl,
        rightRoomName: targetRoomName,
        rightRoomImageUrl: targetRoomImageUrl,
      );

      final batch = _firestore.batch();
      batch.set(matchRef, match.toJson());
      
      final senderPkState = PKBattleState(
        isActive: true,
        durationMinutes: invite.durationMinutes,
        startTime: startTime,
        opponentRoomId: invite.targetRoomId,
        opponentRoomName: targetRoomName,
        opponentRoomImageUrl: targetRoomImageUrl,
      );
      
      final targetPkState = PKBattleState(
        isActive: true,
        durationMinutes: invite.durationMinutes,
        startTime: startTime,
        opponentRoomId: invite.senderRoomId,
        opponentRoomName: invite.senderRoomName,
        opponentRoomImageUrl: invite.senderRoomImageUrl,
      );
      
      batch.update(_firestore.collection('audio_rooms_v2').doc(invite.senderRoomId), {
        'pkBattleState': senderPkState.toJson(),
      });
      batch.update(_firestore.collection('audio_rooms_v2').doc(invite.targetRoomId), {
        'pkBattleState': targetPkState.toJson(),
      });
      
      await batch.commit();
      debugPrint('Accepted Room PK Invite and created match: ${match.id}');
      return match;
    } catch (e) {
      debugPrint('Error accepting PK invite: $e');
      throw Exception('Failed to accept PK invite');
    }
  }
  
  /// Reject an invite
  Future<void> rejectInvite(String inviteId) async {
    try {
      await _firestore.collection(_invitesCollection).doc(inviteId).update({
        'status': RoomPKInviteStatus.rejected.name,
      });
    } catch (e) {
      debugPrint('Error rejecting PK invite: $e');
    }
  }

  /// Listen to an active match for a room
  Stream<RoomPKMatch?> listenToActiveMatch(String roomId) {
    // A room can be either leftRoomId or rightRoomId
    // Since Firestore doesn't support OR queries easily across multiple fields in streams,
    // we listen to both and combine them, or just use a cloud function to sync it to the room doc.
    // For now, we do a simple stream that merges both queries.
    
    // Left side stream
    final leftStream = _firestore
        .collection(_matchesCollection)
        .where('leftRoomId', isEqualTo: roomId)
        .where('state', whereIn: [RoomPKMatchState.active.name, RoomPKMatchState.punishment.name])
        .snapshots();
        
    // Right side stream
    // final rightStream = _firestore
    //     .collection(_matchesCollection)
    //     .where('rightRoomId', isEqualTo: roomId)
    //     .where('state', whereIn: [RoomPKMatchState.active.name, RoomPKMatchState.punishment.name])
    //     .snapshots();

    // In a real app we'd use RxDart to combine these, but since we want to keep it simple:
    // We recommend storing currentMatchId in the AudioRoomV2 document when a match starts!
    
    return leftStream.map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return RoomPKMatch.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    }); // NOTE: This only checks if we are the left room. Full implementation needs RxDart or saving matchId in room doc.
  }

  // Auto Match Logic
  Future<void> enterAutoMatchQueue({
    required String roomId,
    required String roomName,
    required String roomImageUrl,
    required int durationMinutes,
  }) async {
    try {
      // Check if someone else is in the queue
      final queueSnapshot = await _firestore
          .collection(_autoMatchCollection)
          .orderBy('joinedAt')
          .limit(1)
          .get();

      if (queueSnapshot.docs.isNotEmpty) {
        final opponentData = queueSnapshot.docs.first.data();
        final opponentId = opponentData['roomId'] as String;
        
        // Prevent matching with self
        if (opponentId != roomId) {
          // Remove opponent from queue
          await _firestore.collection(_autoMatchCollection).doc(queueSnapshot.docs.first.id).delete();
          
          // Create match
          final matchRef = _firestore.collection(_matchesCollection).doc();
          final startTime = DateTime.now();
          final match = RoomPKMatch(
            id: matchRef.id,
            leftRoomId: opponentId,
            rightRoomId: roomId,
            state: RoomPKMatchState.active,
            createdAt: startTime,
            startTime: startTime,
            durationMinutes: durationMinutes,
            leftRoomName: opponentData['roomName'] ?? 'Room',
            leftRoomImageUrl: opponentData['roomImageUrl'] ?? '',
            rightRoomName: roomName,
            rightRoomImageUrl: roomImageUrl,
          );
          
          final batch = _firestore.batch();
          batch.set(matchRef, match.toJson());
          
          final leftPkState = PKBattleState(
            isActive: true,
            durationMinutes: durationMinutes,
            startTime: startTime,
            opponentRoomId: roomId,
            opponentRoomName: roomName,
            opponentRoomImageUrl: roomImageUrl,
          );
          
          final rightPkState = PKBattleState(
            isActive: true,
            durationMinutes: durationMinutes,
            startTime: startTime,
            opponentRoomId: opponentId,
            opponentRoomName: opponentData['roomName'] ?? 'Room',
            opponentRoomImageUrl: opponentData['roomImageUrl'] ?? '',
          );
          
          batch.update(_firestore.collection('audio_rooms_v2').doc(opponentId), {
            'pkBattleState': leftPkState.toJson(),
          });
          batch.update(_firestore.collection('audio_rooms_v2').doc(roomId), {
            'pkBattleState': rightPkState.toJson(),
          });
          
          await batch.commit();
          debugPrint('Auto-matched with $opponentId');
          return;
        }
      }

      // No opponent found, enter queue
      await _firestore.collection(_autoMatchCollection).doc(roomId).set({
        'roomId': roomId,
        'roomName': roomName,
        'roomImageUrl': roomImageUrl,
        'durationMinutes': durationMinutes,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Entered auto-match queue for Room $roomId');
    } catch (e) {
      debugPrint('Error in auto match: $e');
      throw Exception('Failed to auto match');
    }
  }
  
  Future<void> leaveAutoMatchQueue(String roomId) async {
    try {
      await _firestore.collection(_autoMatchCollection).doc(roomId).delete();
    } catch (e) {
      debugPrint('Error leaving auto match queue: $e');
    }
  }
}
