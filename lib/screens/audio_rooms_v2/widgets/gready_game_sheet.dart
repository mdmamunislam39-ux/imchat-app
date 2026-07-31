import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class GreadyGameSheet extends StatefulWidget {
  const GreadyGameSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GreadyGameSheet(),
    );
  }

  @override
  State<GreadyGameSheet> createState() => _GreadyGameSheetState();
}

class _GreadyGameSheetState extends State<GreadyGameSheet>
    with TickerProviderStateMixin {
  int timeLeft = 30;
  Timer? timer;
  StreamSubscription? roundSub;
  StreamSubscription? _offsetSub;
  int _serverTimeOffset = 0;
  String _currentPhase = 'betting';
  int _phaseEndTime = 0;
  int activeIndex = -1; // -1 means no highlight, -2 Pizza, -3 Salad
  late AnimationController _spinController;
  int _winningIndex = -1;
  int _bonusType = -1;
  int _lastPassedItem = -1;
  bool isBettingOpen = true;
  int selectedChip = 100;
  Map<int, int> userBets = {};
  int roundNumber = 0;
  String dailyRoundDate = "";
  bool _isSuper = false; // false = Normal, true = Super
  bool _isTickingBackend = false;
  DateTime? _lastBetSoundTime;
  final Map<int, int> _pendingBets = {};
  Timer? _betSyncTimer;
  bool _hasSpunThisRound = false;

  // Audio players
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _spinTickPlayer = AudioPlayer();
  double _volumeLevel = 1.0; // 1.0 -> 0.5 -> 0.0

  // Normal mode bet chips
  static const List<int> normalChips = [100, 1000, 5000, 10000];
  // Super mode bet chips
  static const List<int> superChips = [1000, 10000, 50000, 100000];

  Map<String, dynamic> greedyConfig = {};
  StreamSubscription? configSub;

  String get currentUserId => AuthController.instance.currentUser.userId;
  String get todayDate => DateTime.now().toIso8601String().split('T')[0];

  final List<Map<String, dynamic>> items = [
    {
      'name': 'Hotdog',
      'emoji': '🌭',
      'image': 'assets/images/food_game/hotdog.png',
      'win': 'Win 10 Times',
      'multiplier': 10,
      'type': 'meat'
    },
    {
      'name': 'Skewer',
      'emoji': '🍢',
      'image': 'assets/images/food_game/skewer.png',
      'win': 'Win 15 Times',
      'multiplier': 15,
      'type': 'meat'
    },
    {
      'name': 'Ham',
      'emoji': '🍖',
      'image': 'assets/images/food_game/ham.png',
      'win': 'Win 25 Times',
      'multiplier': 25,
      'type': 'meat'
    },
    {
      'name': 'Steak',
      'emoji': '🥩',
      'image': 'assets/images/food_game/steak.png',
      'win': 'Win 45 Times',
      'multiplier': 45,
      'type': 'meat'
    },
    {
      'name': 'Carrot',
      'emoji': '🥕',
      'image': 'assets/images/food_game/carrot.png',
      'win': 'Win 5 Times',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Corn',
      'emoji': '🌽',
      'image': 'assets/images/food_game/corn.png',
      'win': 'Win 5 Times',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Cabbage',
      'emoji': '🥬',
      'image': 'assets/images/food_game/cabbage.png',
      'win': 'Win 5 Times',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Tomato',
      'emoji': '🍅',
      'image': 'assets/images/food_game/tomato.png',
      'win': 'Win 5 Times',
      'multiplier': 5,
      'type': 'veg'
    },
  ];

  final List<String> history = ['🥬', '🍅', '🌽', '🥕', '🥬'];

  @override
  void initState() {
    super.initState();
    activeIndex = -1;
    activeIndex = -1;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);

    _bgmPlayer.setVolume(_volumeLevel);
    _sfxPlayer.setVolume(_volumeLevel);
    _spinTickPlayer.setVolume(_volumeLevel);
    _bgmPlayer.play(AssetSource('sounds/greedy_bgm.mp3'));

    _spinController.addListener(() {
      int passedItems = (CurveTween(curve: Curves.easeIn).evaluate(_spinController) * 40).floor();
      if (passedItems > _lastPassedItem) {
        _lastPassedItem = passedItems;
        // _spinTickPlayer.play removed to prevent hang
        if (mounted) {
          setState(() {
            activeIndex = passedItems % 8;
          });
        }
      }
    });

    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration.zero, () {
          // if (_volumeLevel > 0) {
          //   _sfxPlayer.play(AssetSource('sounds/greedy_win.mp3'));
          // }
          if (mounted) {
            setState(() {
              if (_bonusType != -1) {
                activeIndex = _bonusType;
                history.insert(0, _bonusType == -2 ? '🍕' : '🥗');
              } else {
                activeIndex = _winningIndex;
                history.insert(0, items[activeIndex]['emoji']);
              }
              if (history.length > 5) history.removeLast();
            });
          }
          _handleWinLogic(_bonusType != -1 ? _bonusType : activeIndex);
        });
      }
    });

    _offsetSub = FirebaseDatabase.instance.ref(".info/serverTimeOffset").onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        int offset = (event.snapshot.value as num).toInt();
        if (_serverTimeOffset == 0 || (_serverTimeOffset - offset).abs() > 2000) {
          setState(() {
            _serverTimeOffset = offset;
          });
        }
      }
    });

    startGlobalTimer();

    configSub = FirebaseFirestore.instance
        .collection('config')
        .doc('greedy_game')
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          greedyConfig = doc.data() as Map<String, dynamic>;
        });
      }
    });
  }

  @override
  void dispose() {
    _betSyncTimer?.cancel();
    if (_pendingBets.isNotEmpty) {
      _syncBets();
    }
    timer?.cancel();
    roundSub?.cancel();
    _offsetSub?.cancel();
    _spinController.dispose();
    configSub?.cancel();
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _spinTickPlayer.dispose();
    super.dispose();
  }

  void _showVolumeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C3E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Volume Control',
                  style: TextStyle(color: Colors.white)),
              content: Row(
                children: [
                  Icon(
                    _volumeLevel == 0.0
                        ? Icons.volume_off_rounded
                        : _volumeLevel < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Slider(
                      value: _volumeLevel,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setDialogState(() {
                          _volumeLevel = value;
                        });
                        setState(() {
                          _volumeLevel = value;
                          _bgmPlayer.setVolume(_volumeLevel);
                          _sfxPlayer.setVolume(_volumeLevel);
                          _spinTickPlayer.setVolume(_volumeLevel);
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _advanceRoundInDatabase() async {
    try {
      final ref = FirebaseDatabase.instance.ref('greedy_game/current_round');
      final snap = await ref.get();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!snap.exists || snap.value == null) {
        await ref.set({
          'roundNumber': 1001,
          'phase': 'betting',
          'phaseEndTime': now + 15000,
          'result': 'PENDING',
          'dailyRoundDate': DateTime.now().toString().split(' ').first,
        });
        return;
      }

      final data = Map<String, dynamic>.from(snap.value as Map);
      final currentPhase = data['phase'] ?? 'betting';
      final currentRoundNumber = data['roundNumber'] ?? 1000;
      final phaseEndTime = (data['phaseEndTime'] as num?)?.toInt() ?? 0;

      if (now < phaseEndTime - 500) return;

      if (currentPhase == 'betting') {
        final randResult = Random().nextInt(8);
        await ref.update({
          'phase': 'spinning',
          'result': randResult,
          'phaseEndTime': now + 10000,
        });
      } else {
        await ref.update({
          'roundNumber': currentRoundNumber + 1,
          'phase': 'betting',
          'result': 'PENDING',
          'phaseEndTime': now + 15000,
          'dailyRoundDate': DateTime.now().toString().split(' ').first,
        });
        await ref.child('bets').remove();
      }
    } catch (e) {
      debugPrint('Greedy Red fallback tick error: $e');
    }
  }

  void startGlobalTimer() {
    roundSub = FirebaseDatabase.instance
        .ref('greedy_game/current_round')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      setState(() {
        _currentPhase = data['phase'] ?? 'betting';
        _phaseEndTime = data['phaseEndTime'] ?? 0;

        bool wasZero = roundNumber == 0;
        if (roundNumber != (data['roundNumber'] ?? 0)) {
          roundNumber = data['roundNumber'] ?? 0;
          dailyRoundDate = data['dailyRoundDate'] ?? "";
          if (_currentPhase == 'betting' && !wasZero) {
            userBets.clear();
          } else if (wasZero) {
            _loadUserBets();
          }
        }

        if (_currentPhase == 'betting') {
          isBettingOpen = true;
          _hasSpunThisRound = false;
          if (activeIndex != -1 && !_spinController.isAnimating) activeIndex = -1;
          _spinController.reset();
        } else {
          isBettingOpen = false;
        }
      });

      if (_currentPhase == 'spinning') {
        dynamic result = data['result'];
        if (result != null &&
            result != 'PENDING' &&
            !_hasSpunThisRound) {
          _hasSpunThisRound = true;
          int finalResult =
              result is int ? result : int.tryParse(result.toString()) ?? 0;
          startSpin(finalResult);
        }
      }
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        int currentServerTime = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
        int newTimeLeft = max(0, (_phaseEndTime - currentServerTime) ~/ 1000);

        if (newTimeLeft == 0) {
          if (!_isTickingBackend) {
            _isTickingBackend = true;
            FirebaseFunctions.instance.httpsCallable('tickGreedyGame').call().then((_) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _isTickingBackend = false;
              });
            }).catchError((e) {
              debugPrint("Greedy Tick Error: $e");
              _advanceRoundInDatabase();
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _isTickingBackend = false;
              });
            });
          } else {
            _advanceRoundInDatabase();
          }
        }
        
        timeLeft = newTimeLeft;
      });
    });
  }

  void _loadUserBets() {
    FirebaseDatabase.instance
        .ref('greedy_game/current_round/bets/$currentUserId')
        .once()
        .then((snapshot) {
      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        Map<int, int> restoredBets = {};
        data.forEach((key, value) {
          int index = int.tryParse(key) ?? -1;
          if (index != -1) {
            restoredBets[index] = (value as num).toInt();
          }
        });
        if (mounted) {
          setState(() {
            userBets = restoredBets;
          });
        }
      }
    });
  }

  void startSpin(int finalResult) {
    int winningIndex = -1;
    int bonusType = -1;
    if (finalResult >= 0) {
      winningIndex = finalResult;
    } else {
      bonusType = finalResult;
    }

    // Failsafe
    if (winningIndex == -1 && bonusType == -1) winningIndex = 0;

    _winningIndex = winningIndex;
    _bonusType = bonusType;
    _lastPassedItem = -1;
    _spinController.forward(from: 0);
  }

  Future<void> _handleWinLogic(int finalResult) async {
    int prize = 0;
    int bet = 0;
    int totalBetPlaced = userBets.values.fold(0, (acc, b) => acc + b);

    if (finalResult >= 0) {
      final winningItem = items[finalResult];
      bet = userBets[finalResult] ?? 0;
      prize = bet * (winningItem['multiplier'] as int);
    } else {
      String targetType = finalResult == -2 ? 'meat' : 'veg';
      for (int i = 0; i < items.length; i++) {
        if (items[i]['type'] == targetType && userBets.containsKey(i)) {
          bet += userBets[i]!;
        }
      }
      if (bet > 0) prize = bet * 5;
    }

    if (prize > 0) {
      try {
        final currentUser = AuthController.instance.currentUser;
        final todayDate = DateTime.now().toString().split(' ').first;
        final leaderboardRef = FirebaseFirestore.instance
            .collection('gready_game_leaderboard')
            .doc('daily')
            .collection(todayDate)
            .doc(currentUser.userId);

        await leaderboardRef.set({
          'userId': currentUser.userId,
          'username': currentUser.fullname,
          'profilePic': currentUser.photoUrl,
          'totalWon': FieldValue.increment(prize),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.userId)
            .update({
          'diamonds': FieldValue.increment(prize),
        });
      } catch (e) {
        debugPrint('Win logic update error: $e');
      }
    }

    if (mounted) {
      showResultDialog(finalResult, totalBetPlaced, prize);
    }
  }

  void _syncBets() {
    if (_pendingBets.isEmpty) return;
    
    final betsToSend = Map<int, int>.from(_pendingBets);
    _pendingBets.clear();
    
    for (var entry in betsToSend.entries) {
      final index = entry.key;
      final amount = entry.value;
      
      FirebaseFunctions.instance.httpsCallable('placeGreedyGameBet').call({
        'symbol': index,
        'amount': amount,
      }).catchError((e) {
        if (mounted) {
          setState(() {
            userBets[index] = (userBets[index] ?? 0) - amount;
            AuthController.instance.currentUser.diamonds += amount;
            if (userBets[index]! <= 0) {
              userBets.remove(index);
            }
          });
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black87,
              title: const Text('Error', style: TextStyle(color: Colors.white)),
              content: const Text('Failed to place bet. Try again.', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Colors.amber)),
                ),
              ],
            ),
          );
        }
        throw e;
      });
    }
  }

  Future<void> placeBet(int index) async {
    if (!isBettingOpen) return;

    if (!userBets.containsKey(index) && userBets.length >= 6) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Limit Reached', style: TextStyle(color: Colors.white)),
          content: const Text('Max 6 kinds of food allowed!', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
      return;
    }

    if (_volumeLevel > 0) {
      final now = DateTime.now();
      if (_lastBetSoundTime == null || now.difference(_lastBetSoundTime!).inMilliseconds > 150) {
        _lastBetSoundTime = now;
        _sfxPlayer.play(AssetSource('sounds/greedy_bet.mp3'));
      }
    }

    if (AuthController.instance.currentUser.diamonds < selectedChip) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Insufficient Balance', style: TextStyle(color: Colors.white)),
          content: const Text('You do not have enough diamonds to place this bet.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
      return;
    }

    // Optimistic update
    if (mounted) {
      setState(() {
        userBets[index] = (userBets[index] ?? 0) + selectedChip;
        AuthController.instance.currentUser.diamonds -= selectedChip;
      });
    }

    _pendingBets[index] = (_pendingBets[index] ?? 0) + selectedChip;
    _betSyncTimer?.cancel();
    _betSyncTimer = Timer(const Duration(milliseconds: 400), _syncBets);
  }

  void showInfoDialog(String title, String emoji, String desc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amber, width: 2)),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(desc,
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          )
        ],
      ),
    );
  }

  void showResultDialog(int finalResult, int bet, int prize) {
    Map<String, dynamic> winningItemData;
    if (finalResult >= 0) {
      winningItemData = items[finalResult];
    } else {
      winningItemData = {
        'emoji': finalResult == -2 ? '🍕' : '🥗',
        'name': finalResult == -2 ? 'Pizza Bonus' : 'Salad Bonus',
      };
    }

    bool dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFFD32F2F), Color(0xFF7F0000)],
                radius: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.5),
                                blurRadius: 20)
                          ]),
                      child: Center(
                        child: finalResult >= 0
                            ? (winningItemData['image'] != null
                                ? Image.asset(
                                    winningItemData['image'] as String,
                                    width: 65,
                                    height: 65,
                                    errorBuilder:
                                        (context, error, stackTrace) => Text(
                                      winningItemData['emoji'] ?? '',
                                      style: const TextStyle(fontSize: 60),
                                    ),
                                  )
                                : Text(
                                    winningItemData['emoji'] ?? '',
                                    style: const TextStyle(fontSize: 60),
                                  ))
                            : Image.asset(
                                finalResult == -2
                                    ? 'assets/images/food_game/pizza.png'
                                    : 'assets/images/food_game/salad.png',
                                width: 65,
                                height: 65,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(
                                  winningItemData['emoji'] ?? '',
                                  style: const TextStyle(fontSize: 60),
                                ),
                              ),
                      ),
                    ),
                    const Positioned(
                      top: -10,
                      left: -10,
                      child: Text('🎉', style: TextStyle(fontSize: 30)),
                    ),
                    const Positioned(
                      bottom: -10,
                      right: -10,
                      child: Text('🎊', style: TextStyle(fontSize: 30)),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Result of Round $roundNumber',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildResultBox('Your Bet', bet.toString()),
                    _buildResultBox('Your Prize', prize.toString()),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Top Round Winners',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // Real-time Top 3 Winners of the CURRENT ROUND
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gready_game_round_leaderboard')
                      .doc('round_${dailyRoundDate}_$roundNumber')
                      .collection('users')
                      .orderBy('won', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No winners this round',
                              style: TextStyle(color: Colors.white54)));
                    }

                    final docs = snapshot.data!.docs;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(3, (index) {
                        if (index >= docs.length) {
                          return const SizedBox(width: 60); // empty placeholder
                        }
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isTop = index == 0;
                        return _buildBiggestWinner(
                          data['username'] ?? 'User',
                          (data['won'] ?? 0).toString(),
                          '${index + 1}',
                          data['profilePic'] ?? '',
                          isTop: isTop,
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      if (dialogOpen) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Close',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    ).then((_) => dialogOpen = false);

    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (dialogOpen && mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _showMyHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Color(0xFF4A0000),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Text('My Bet History',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gready_game_bet_history')
                      .doc(currentUserId)
                      .collection('history')
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.amber));
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No history found',
                              style: TextStyle(color: Colors.white54)));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                        final int bet = data['totalBet'] ?? 0;
                        final int win = data['winAmount'] ?? 0;

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.black45),
                            child: Center(
                                child: Text(data['winningEmoji'] ?? '',
                                    style: const TextStyle(fontSize: 24))),
                          ),
                          title: Text('Round ${data['roundNumber'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              const Text('Bet: ',
                                  style: TextStyle(color: Colors.white54)),
                              DynamicDiamondIcon(height: 12),
                              Text('$bet',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(width: 12),
                              const Text('Win: ',
                                  style: TextStyle(color: Colors.white54)),
                              DynamicDiamondIcon(height: 12),
                              Text('$win',
                                  style: TextStyle(
                                      color: win > 0
                                          ? Colors.amber
                                          : Colors.white70,
                                      fontWeight: win > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                            ],
                          ),
                          trailing: win > 0
                              ? const Icon(Icons.arrow_upward,
                                  color: Colors.greenAccent)
                              : const Icon(Icons.arrow_downward,
                                  color: Colors.redAccent),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTop10History() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Color(0xFF4A0000),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Text('Daily Top 10 Winners',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gready_game_leaderboard')
                      .doc('daily')
                      .collection(todayDate)
                      .orderBy('totalWon', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.amber));
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('No history today',
                              style: TextStyle(color: Colors.white54)));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: data['profilePic'] != null &&
                                    data['profilePic'].toString().isNotEmpty
                                ? NetworkImage(data['profilePic'])
                                : const NetworkImage(
                                    'https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                          ),
                          title: Text(data['username'] ?? 'User',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DynamicDiamondIcon(height: 16),
                              const SizedBox(width: 4),
                              Text('${data['totalWon']}',
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          subtitle: Text('Rank #${index + 1}',
                              style: const TextStyle(color: Colors.white54)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _getFoodImageFromEmoji(String emoji) {
    switch (emoji) {
      case '🍕':
        return 'assets/images/food_game/pizza.png';
      case '🥗':
        return 'assets/images/food_game/salad.png';
      case '🌭':
        return 'assets/images/food_game/hotdog.png';
      case '🍢':
        return 'assets/images/food_game/skewer.png';
      case '🍗':
      case '🍖':
        return 'assets/images/food_game/ham.png';
      case '🥩':
        return 'assets/images/food_game/steak.png';
      case '🥕':
        return 'assets/images/food_game/carrot.png';
      case '🌽':
        return 'assets/images/food_game/corn.png';
      case '🥬':
        return 'assets/images/food_game/cabbage.png';
      case '🍅':
        return 'assets/images/food_game/tomato.png';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        gradient: _isSuper
            ? const LinearGradient(
                colors: [
                  Color(0xFF2D0066),
                  Color(0xFF3D0080),
                  Color(0xFF1A003A)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
              )
            : const RadialGradient(
                colors: [Color(0xFF8B0000), Color(0xFF4A0000)],
                center: Alignment.topCenter,
                radius: 1.5,
              ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildWheelArea(),
                  ),
                  const SizedBox(height: 8),
                  _buildPrizeArea(),
                  const SizedBox(height: 8),
                  _buildBettingArea(),
                  const SizedBox(height: 12),
                  _buildFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(
        children: [
          _buildIconButton(
              Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildIconButton(Icons.arrow_drop_down, () {}),
          const SizedBox(width: 8),
          _buildIconButton(
            _volumeLevel == 0.0
                ? Icons.volume_off_rounded
                : _volumeLevel < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            _showVolumeDialog,
          ),
          const Spacer(),
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                int diamonds = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  diamonds = data['diamonds'] ?? 0;
                }
                String displayDiamonds = diamonds.toString();
                if (diamonds > 1000000) {
                  displayDiamonds =
                      '${(diamonds / 1000000).toStringAsFixed(1)}m';
                } else if (diamonds > 1000) {
                  displayDiamonds = '${(diamonds / 1000).toStringAsFixed(1)}k';
                }
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      DynamicDiamondIcon(height: 16),
                      const SizedBox(width: 6),
                      Text(displayDiamonds,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildWheelArea() {
    return SizedBox(
      height: 370,
      width: 370,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing center background
          Container(
            width: 370,
            height: 370,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.purple.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
          ),
          // The center circle
          Container(
            width: 135,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isSuper
                  ? const LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF6A0080)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Colors.orange, Colors.red],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              border: Border.all(
                color: _isSuper ? const Color(0xFFCE93D8) : Colors.amber,
                width: _isSuper ? 3 : 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isSuper
                      ? Colors.purple.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.5),
                  blurRadius: _isSuper ? 20 : 10,
                  spreadRadius: _isSuper ? 4 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Round $roundNumber',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isSuper ? const Color(0xFF4A0066) : Colors.red[900],
                    borderRadius: BorderRadius.circular(20),
                    border: _isSuper ? Border.all(color: Colors.white24) : null,
                  ),
                  child: Text(
                    '${_currentPhase == 'betting' ? timeLeft : 0}s',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // The items
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              int currentActiveIndex = activeIndex;
              if (_spinController.isAnimating) {
                int targetPosition = 40 + _winningIndex;
                double curve = Curves.easeOutCirc.transform(_spinController.value);
                currentActiveIndex = (curve * targetPosition).floor() % items.length;
              }
              return SizedBox(
                width: 380,
                height: 380,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: List.generate(items.length, (index) {
                  final angle = (index * 45 - 90) * (pi / 180);
                  const double radius = 143.0;

                  bool isHighlighted = false;
                  if (currentActiveIndex == index) isHighlighted = true;
                  if (currentActiveIndex == -2 && items[index]['type'] == 'meat') {
                    isHighlighted = true;
                  }
                  if (currentActiveIndex == -3 && items[index]['type'] == 'veg') {
                    isHighlighted = true;
                  }

                  final betAmount = userBets[index];
                  final isSpinning = _spinController.isAnimating;
                  final double pulse =
                      isSpinning ? (sin(_spinController.value * pi * 15) + 1) / 2 : 0;

                  return Transform.translate(
                    offset: Offset(cos(angle) * radius, sin(angle) * radius),
                    child: GestureDetector(
                      onTap: () => placeBet(index),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 82,
                            height: 92,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isHighlighted
                                    ? [Colors.yellow.shade300, Colors.amber.shade600]
                                    : _isSuper
                                        ? [
                                            Color.lerp(
                                                const Color(0xFFCE93D8),
                                                const Color(0xFFAB47BC),
                                                pulse * 0.3)!,
                                            Color.lerp(
                                                const Color(0xFF7B1FA2),
                                                const Color(0xFF6A1B9A),
                                                pulse * 0.3)!,
                                          ]
                                        : [
                                            Color.lerp(Colors.orange.shade300,
                                                Colors.orange.shade100, pulse * 0.3)!,
                                            Color.lerp(Colors.orange.shade600,
                                                Colors.orange.shade400, pulse * 0.3)!,
                                          ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isHighlighted
                                    ? Colors.white
                                    : _isSuper
                                        ? Color.lerp(const Color(0xFFCE93D8),
                                            Colors.purpleAccent, pulse)!
                                        : Color.lerp(Colors.amber,
                                            Colors.orangeAccent, pulse)!,
                                width: isHighlighted ? 3 : 2,
                              ),
                              boxShadow: isHighlighted
                                  ? [
                                      const BoxShadow(
                                          color: Colors.amberAccent,
                                          blurRadius: 15,
                                          spreadRadius: 3)
                                    ]
                                  : _isSuper
                                      ? [
                                          BoxShadow(
                                              color: Colors.purple.withValues(
                                                  alpha: 0.4 + pulse * 0.3),
                                              blurRadius: 8 + 4 * pulse)
                                        ]
                                      : [
                                          BoxShadow(
                                              color: Colors.amberAccent
                                                  .withValues(alpha: pulse * 0.3),
                                              blurRadius: 8 * pulse,
                                              spreadRadius: 2 * pulse)
                                        ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: items[index]['image'] != null
                                      ? Image.asset(
                                          items[index]['image'] as String,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) => Text(
                                            items[index]['emoji'] ?? '',
                                            style: const TextStyle(fontSize: 40),
                                          ),
                                        )
                                      : Text(
                                          items[index]['emoji'] ?? '',
                                          style: const TextStyle(fontSize: 40),
                                        ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  items[index]['win'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Bet amount badge
                          if (betAmount != null)
                            Positioned(
                              bottom: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple[700],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DynamicDiamondIcon(height: 8),
                                    const SizedBox(width: 2),
                                    Text('$betAmount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeArea() {
    return GestureDetector(
      onTap: _showMyHistory,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Today's prize ",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            DynamicDiamondIcon(height: 14),
            StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('gready_game_leaderboard')
                    .doc('daily')
                    .collection(todayDate)
                    .doc(currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  int userTodayWon = 0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    userTodayWon = data?['totalWon'] ?? 0;
                  }
                  return Text(
                    ' $userTodayWon',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  );
                }),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBettingArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.only(top: 44),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: _isSuper ? Colors.black26 : const Color(0xFF6A0000),
              borderRadius: BorderRadius.circular(_isSuper ? 20 : 16),
              border: Border.all(
                color: _isSuper
                    ? Colors.white12
                    : Colors.redAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                // Regular / Advanced tabs
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTab('Normal', !_isSuper),
                      const SizedBox(width: 6),
                      _buildTab('Super', _isSuper),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: (_isSuper ? superChips : normalChips)
                      .map((c) => _buildBetButton(c))
                      .toList(),
                ),
              ],
            ),
          ),
          Positioned(
            left: -10,
            top: -44,
            child: _buildPodium('🥗', 'Salad',
                'When the Salad Prize is opened, all players who selected any vegetable ingredient will win a share of the prize pool.'),
          ),
          Positioned(
            right: -10,
            top: -44,
            child: _buildPodium('🍕', 'Pizza',
                'When the Pizza Prize is opened, all players who selected any meat ingredient will win a share of the prize pool.'),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSuper = (text == 'Super');
          selectedChip = _isSuper ? superChips[0] : normalChips[0];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isSuper ? Colors.white : Colors.redAccent)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? (_isSuper ? const Color(0xFF6A0080) : Colors.white)
                : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(String emoji, String name, String desc) {
    bool isHighlighted = false;
    if (activeIndex == -2 && name == 'Pizza') isHighlighted = true;
    if (activeIndex == -3 && name == 'Salad') isHighlighted = true;

    return GestureDetector(
      onTap: () => showInfoDialog('$name Prize', emoji, desc),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isHighlighted ? 1.2 : 1.0,
              child: Image.asset(
                name == 'Pizza'
                    ? 'assets/images/food_game/pizza.png'
                    : 'assets/images/food_game/salad.png',
                width: 72,
                height: 72,
                errorBuilder: (context, error, stackTrace) => Text(
                  emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _isSuper ? const Color(0xFF4A0066) : Colors.red[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isSuper ? const Color(0xFFCE93D8) : Colors.amber,
                width: 1,
              ),
            ),
            child: Text(
              name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetButton(int amount) {
    final isSelected = selectedChip == amount;
    final String label =
        amount >= 1000 ? '${amount ~/ 1000}k' : amount.toString();
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedChip = amount;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [Colors.amber.shade300, Colors.orange.shade700]
                : [Colors.orange.shade600, Colors.deepOrange.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.orange.shade300,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.7),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DynamicDiamondIcon(height: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Text('Result',
                      style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(width: 8),
                  ...history.map((e) {
                    final imgPath = _getFoodImageFromEmoji(e);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: imgPath != null
                          ? Image.asset(
                              imgPath,
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(e, style: const TextStyle(fontSize: 16)),
                            )
                          : Text(e, style: const TextStyle(fontSize: 16)),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Realtime Top 1 Winner -> Click for History
          GestureDetector(
            onTap: _showTop10History,
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('gready_game_leaderboard')
                    .doc('daily')
                    .collection(todayDate)
                    .orderBy('totalWon', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  String name = 'Waiting...';
                  int won = 0;
                  String pic = '';

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final data = snapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    name = data['username'] ?? 'User';
                    won = data['totalWon'] ?? 0;
                    pic = data['profilePic'] ?? '';
                  }

                  String displayWon = won.toString();
                  if (won > 1000000) {
                    displayWon = '${(won / 1000000).toStringAsFixed(1)}m';
                  } else if (won > 1000) {
                    displayWon = '${(won / 1000).toStringAsFixed(1)}k';
                  }

                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: pic.isNotEmpty
                              ? NetworkImage(pic)
                              : const NetworkImage(
                                  'https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                          backgroundColor: Colors.grey.shade800,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                    name.length > 8
                                        ? '${name.substring(0, 8)}...'
                                        : name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                const Icon(Icons.emoji_events,
                                    color: Colors.amber, size: 16),
                              ],
                            ),
                            Row(
                              children: [
                                DynamicDiamondIcon(height: 10),
                                const SizedBox(width: 2),
                                Text(displayWon,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.menu, color: Colors.white70, size: 18),
                      ],
                    ),
                  );
                }),
          )
        ],
      ),
    );
  }

  Widget _buildResultBox(String title, String amount) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DynamicDiamondIcon(height: 14),
              const SizedBox(width: 4),
              Text(amount,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBiggestWinner(
      String name, String amount, String rank, String picUrl,
      {bool isTop = false}) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: isTop ? 30 : 25,
              backgroundImage: picUrl.isNotEmpty
                  ? NetworkImage(picUrl)
                  : const NetworkImage(
                      'https://cdn-icons-png.flaticon.com/512/847/847969.png'),
              backgroundColor: Colors.grey.shade800,
            ),
            Positioned(
              bottom: -5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTop
                      ? Colors.amber
                      : (rank == '2'
                          ? Colors.grey.shade400
                          : Colors.brown.shade300),
                ),
                child: Text(rank,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(name.length > 8 ? '${name.substring(0, 8)}...' : name,
            style: TextStyle(color: Colors.white, fontSize: isTop ? 14 : 12)),
        Row(
          children: [
            DynamicDiamondIcon(height: 10),
            const SizedBox(width: 2),
            Text(amount,
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: isTop ? 12 : 10,
                    fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}
