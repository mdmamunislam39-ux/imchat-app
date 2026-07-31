import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/services/emoji_chat_service.dart';

class VotingController extends GetxController {
  final String roomId;
  final bool isHost;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<VotingState> gameState = const VotingState(id: '').obs;
  
  StreamSubscription? _sub;
  Timer? _timer;

  VotingController(this.roomId, {this.isHost = false});

  @override
  void onInit() {
    super.onInit();
    _listenToState();
  }

  void _listenToState() {
    _sub = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('voting')
        .doc('state')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final state = VotingState.fromJson(doc.data()!);
        gameState.value = state;
        
        // Auto-end poll if timer expired and we are host
        if (state.isActive && isHost) {
          final elapsed = (DateTime.now().millisecondsSinceEpoch - state.startTime) / 1000;
          if (elapsed >= state.durationSeconds) {
            endVoting();
          }
        }
      } else {
        // Document deleted, clear local state
        gameState.value = const VotingState(id: '');
      }
    });
    
    // Check every second to end voting if time's up
    if (isHost) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final state = gameState.value;
        if (state.isActive) {
          final elapsed = (DateTime.now().millisecondsSinceEpoch - state.startTime) / 1000;
          if (elapsed >= state.durationSeconds) {
            endVoting();
          }
        }
      });
    }
  }

  Future<void> startVoting(String question, List<String> options, int durationSeconds) async {
    final newState = VotingState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      question: question,
      options: options,
      votes: const {},
      startTime: DateTime.now().millisecondsSinceEpoch,
      durationSeconds: durationSeconds,
      isActive: true,
    );
    
    await _syncState(newState);
    
    // Also update main room flag
    final repo = AudioRoomsRepository();
    await repo.updateVotingState(roomId: roomId, isActive: true);
  }

  Future<void> castVote(String userId, String username, String? userAvatar, int optionIndex) async {
    if (!gameState.value.isActive) return;
    
    // Don't allow double voting
    if (gameState.value.votes.containsKey(userId)) return;

    final newVotes = Map<String, int>.from(gameState.value.votes);
    newVotes[userId] = optionIndex;
    
    final newState = gameState.value.copyWith(votes: newVotes);
    await _syncState(newState);

    // Send chat message
    if (optionIndex >= 0 && optionIndex < gameState.value.options.length) {
      final optionText = gameState.value.options[optionIndex];
      await EmojiChatService.sendVoteMessage(
        roomId: roomId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        optionIndex: optionIndex,
        optionText: optionText,
      );
    }
  }

  Future<void> endVoting() async {
    if (!gameState.value.isActive) return;
    
    final newState = gameState.value.copyWith(isActive: false);
    await _syncState(newState);
    
    // Update main room flag
    final repo = AudioRoomsRepository();
    await repo.updateVotingState(roomId: roomId, isActive: false);

    // Send summary chat message
    await EmojiChatService.sendVoteResultMessage(
      roomId: roomId,
      message: jsonEncode(newState.toJson()),
    );
  }

  Future<void> clearVoting() async {
    if (!isHost) return;
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('voting')
          .doc('state')
          .delete();
    } catch (e) {
      debugPrint('Error clearing Voting state: $e');
    }
  }

  Future<void> _syncState(VotingState newState) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('voting')
          .doc('state')
          .set(newState.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing Voting state: $e');
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
