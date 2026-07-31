import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_models.dart';
import 'package:chat_messenger/services/emoji_chat_service.dart';

class RouletteController extends GetxController {
  final String roomId;
  final bool isHost;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<RouletteState> gameState = const RouletteState(id: '').obs;
  
  // Store custom options for Custom Roulette
  final RxList<String> customOptions = <String>[].obs;
  
  StreamSubscription? _sub;

  RouletteController(this.roomId, {this.isHost = false});

  @override
  void onInit() {
    super.onInit();
    _listenToState();
  }

  void _listenToState() {
    _sub = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('roulette')
        .doc('state')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final state = RouletteState.fromJson(doc.data()!);
        gameState.value = state;
        
        // If we are host and state is spinning, we should handle the transition to ended
        if (state.status == RouletteStatus.spinning && isHost) {
          // Calculate when it should end (e.g. 5 seconds spin)
          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = now - state.startTime;
          final remainingTime = 5000 - elapsed;
          
          if (remainingTime <= 0) {
            _endSpin(state);
          } else {
            Future.delayed(Duration(milliseconds: remainingTime), () {
              // Ensure state hasn't changed manually
              if (gameState.value.status == RouletteStatus.spinning && gameState.value.id == state.id) {
                _endSpin(state);
              }
            });
          }
        }
      } else {
        gameState.value = const RouletteState(id: '');
      }
    });
  }

  Future<void> startRoulette(List<String> options) async {
    if (!isHost) return;
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    // Randomize the result instantly
    final resultIndex = Random().nextInt(options.length);
    
    final state = RouletteState(
      id: id,
      options: options,
      status: RouletteStatus.spinning,
      resultIndex: resultIndex,
      startTime: DateTime.now().millisecondsSinceEpoch,
    );

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('roulette')
        .doc('state')
        .set(state.toJson());
  }

  Future<void> _endSpin(RouletteState state) async {
    final newState = state.copyWith(status: RouletteStatus.ended);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('roulette')
        .doc('state')
        .set(newState.toJson());

    // Send result to chat
    if (state.resultIndex >= 0 && state.resultIndex < state.options.length) {
      final resultText = state.options[state.resultIndex];
      await EmojiChatService.sendRouletteResultMessage(roomId, resultText);
    }

    // We removed the auto-close here so it stays open until host closes it
  }

  Future<void> closeRoulette() async {
    if (!isHost) return;
    
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('roulette')
        .doc('state')
        .delete();
  }

  void saveCustomOptions(List<String> options) {
    customOptions.assignAll(options);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
