import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class PinkGreedyGameSheet extends StatefulWidget {
  final bool isInAudioRoom;
  const PinkGreedyGameSheet({super.key, this.isInAudioRoom = true});

  static void show(BuildContext context, {bool isInAudioRoom = true}) {
    if (!isInAudioRoom) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFF3B0B3C),
            body: SafeArea(
              child: Stack(
                children: [
                  const PinkGreedyGameSheet(isInAudioRoom: false),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (context) => const SafeArea(top: false, bottom: true, child: PinkGreedyGameSheet(isInAudioRoom: true)),
      ).then((_) {
        WidgetsBinding.instance.scheduleFrame();
      });
    }
  }

  @override
  State<PinkGreedyGameSheet> createState() => _PinkGreedyGameSheetState();
}

class _PinkGreedyGameSheetState extends State<PinkGreedyGameSheet>
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
  final bool _isSuper = false; // false = Normal, true = Super
  bool _isTickingBackend = false;
  DateTime? _lastBetSoundTime;
  final Map<int, int> _pendingBets = {};
  Timer? _betSyncTimer;
  bool _hasSpunThisRound = false;

  // --- NEW VARIABLES ---
  Timer? _blinkTimer;
  final ValueNotifier<int> _blinkIndexNotifier = ValueNotifier<int>(0);

  late AnimationController _handController;
  late Animation<double> _handAnimation;

  Timer? _handTimer;
  final ValueNotifier<int> _handTargetIndexNotifier = ValueNotifier<int>(4);

  final GlobalKey _sheetKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, GlobalKey> _chipKeys = {};

  final List<Map<String, dynamic>> _activeChips = [];

  // Audio players
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _spinTickPlayer = AudioPlayer();
  double _volumeLevel = 1.0; // 1.0 -> 0.5 -> 0.0

  // Normal mode bet chips
  static const List<int> normalChips = [100, 1000, 10000, 50000, 100000];
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
      'image': 'assets/images/food_game/hotdog.webp',
      'win': 'x10',
      'multiplier': 10,
      'type': 'meat'
    },
    {
      'name': 'Skewer',
      'emoji': '🍢',
      'image': 'assets/images/food_game/skewer.webp',
      'win': 'x15',
      'multiplier': 15,
      'type': 'meat'
    },
    {
      'name': 'Ham',
      'emoji': '🍖',
      'image': 'assets/images/food_game/ham.webp',
      'win': 'x25',
      'multiplier': 25,
      'type': 'meat'
    },
    {
      'name': 'Steak',
      'emoji': '🥩',
      'image': 'assets/images/food_game/steak.webp',
      'win': 'x45',
      'multiplier': 45,
      'type': 'meat'
    },
    {
      'name': 'Carrot',
      'emoji': '🥕',
      'image': 'assets/images/food_game/carrot.webp',
      'win': 'x5',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Corn',
      'emoji': '🌽',
      'image': 'assets/images/food_game/corn.webp',
      'win': 'x5',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Cabbage',
      'emoji': '🥬',
      'image': 'assets/images/food_game/cabbage.webp',
      'win': 'x5',
      'multiplier': 5,
      'type': 'veg'
    },
    {
      'name': 'Tomato',
      'emoji': '🍅',
      'image': 'assets/images/food_game/tomato.webp',
      'win': 'x5',
      'multiplier': 5,
      'type': 'veg'
    },
  ];

  final List<String> history = ['🥬', '🍅', '🌽', '🥕', '🥬'];

  @override
  void initState() {
    super.initState();
    activeIndex = -1;

    for (int i = 0; i < 8; i++) {
      _itemKeys[i] = GlobalKey();
    }
    for (var c in normalChips) {
      _chipKeys[c] = GlobalKey();
    }
    for (var c in superChips) {
      _chipKeys[c] = GlobalKey();
    }

    _handController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _handAnimation = Tween<double>(begin: 0, end: 15).animate(
        CurvedAnimation(parent: _handController, curve: Curves.easeInOut));

    _handTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && isBettingOpen && userBets.isEmpty) {
        _handTargetIndexNotifier.value = (_handTargetIndexNotifier.value + 1) % 8;
      }
    });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);

    _bgmPlayer.setVolume(_volumeLevel);
    _sfxPlayer.setVolume(_volumeLevel);
    _spinTickPlayer.setVolume(_volumeLevel);
    // _spinTickPlayer.setSource(AssetSource('sounds/greedy_spin.mp3')); // Disabled to prevent hang
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
                activeIndex = _bonusType; // Highlight all meat/veg
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
    _startBlinking();

    configSub = FirebaseFirestore.instance
        .collection('config')
        .doc('pink_greedy_game')
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
    _blinkTimer?.cancel();
    _handTimer?.cancel();
    _spinController.dispose();
    _handController.dispose();
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
                      activeColor: Colors.pinkAccent,
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
  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (mounted && isBettingOpen) {
        _blinkIndexNotifier.value = (_blinkIndexNotifier.value + 1) % 8;
      }
    });
  }

  int _calculateWinningResult(Map<String, dynamic> config) {
    if (config['isCustomScheduled'] == true && config['customItem'] != null) {
      final customName = config['customItem'].toString().trim().toLowerCase();
      if (customName == 'pizza') return -2;
      if (customName == 'salad') return -3;
      final idx = items.indexWhere((item) => item['name'].toString().toLowerCase() == customName);
      if (idx != -1) return idx;
    }

    final num ratioNum = config['winRatio'] ?? 50;
    final int winRatio = ratioNum > 1 ? ratioNum.toInt() : (ratioNum * 100).toInt();
    final randRoll = Random().nextInt(100);

    if (randRoll < winRatio) {
      return Random().nextInt(items.length);
    } else {
      final bonusRoll = Random().nextInt(10);
      if (bonusRoll == 0) return -2;
      if (bonusRoll == 1) return -3;
      return Random().nextInt(items.length);
    }
  }

  Future<void> _advanceRoundInDatabase() async {
    try {
      final ref = FirebaseDatabase.instance.ref('pink_greedy_game/current_round');
      final snap = await ref.get();
      final now = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

      if (!snap.exists || snap.value == null) {
        await ref.set({
          'roundNumber': 1001,
          'phase': 'betting',
          'phaseEndTime': now + 30000,
          'result': 'PENDING',
          'dailyRoundDate': DateTime.now().toString().split(' ').first,
        });
        return;
      }

      final data = Map<String, dynamic>.from(snap.value as Map);
      final currentPhase = data['phase'] ?? 'betting';
      final currentRoundNumber = data['roundNumber'] ?? 1000;
      final phaseEndTime = (data['phaseEndTime'] as num?)?.toInt() ?? 0;

      // Ensure server time has elapsed before forcing phase change
      if (phaseEndTime > 0 && now < phaseEndTime - 500) return;

      if (currentPhase == 'betting') {
        final randResult = _calculateWinningResult(greedyConfig);
        await ref.update({
          'phase': 'spinning',
          'result': randResult,
          'phaseEndTime': now + 3000,
        });
      } else if (currentPhase == 'spinning') {
        await ref.update({
          'phase': 'result',
          'phaseEndTime': now + 4000,
        });
      } else {
        await ref.update({
          'roundNumber': currentRoundNumber + 1,
          'phase': 'betting',
          'result': 'PENDING',
          'phaseEndTime': now + 30000,
          'dailyRoundDate': DateTime.now().toString().split(' ').first,
        });
        await ref.child('bets').remove();
      }
    } catch (e) {
      debugPrint('Pink Greedy fallback tick error: $e');
    }
  }

  void startGlobalTimer() {
    timer?.cancel();
    roundSub?.cancel();

    roundSub = FirebaseDatabase.instance
        .ref('pink_greedy_game/current_round')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      setState(() {
        _currentPhase = data['phase'] ?? 'betting';
        _phaseEndTime = (data['phaseEndTime'] as num?)?.toInt() ?? 0;

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
          _startBlinking();
        } else {
          isBettingOpen = false;
          _blinkTimer?.cancel();
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
      if (_phaseEndTime == 0) return;

      int currentServerTime = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
      int newTimeLeft = max(0, ((_phaseEndTime - currentServerTime) / 1000).ceil());

      setState(() {
        timeLeft = newTimeLeft;
      });

      if (newTimeLeft == 0) {
        if (!_isTickingBackend) {
          _isTickingBackend = true;
          FirebaseFunctions.instance.httpsCallable('tickPinkGreedyGame').call().then((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _isTickingBackend = false;
            });
          }).catchError((e) {
            debugPrint("Pink Greedy Tick Error: $e");
            _advanceRoundInDatabase();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _isTickingBackend = false;
            });
          });
        }
      }
    });
  }

  void _loadUserBets() {
    FirebaseDatabase.instance
        .ref('pink_greedy_game/current_round/bets/$currentUserId')
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
    if (_spinController.isAnimating) return;

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
    _spinController.reset();
    _spinController.forward();
  }

  void _handleWinLogic(int finalResult) {
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

    // Show result dialog immediately so UI never blocks/hangs waiting for network
    if (mounted) {
      showResultDialog(finalResult, totalBetPlaced, prize);
    }

    // Process database & wallet updates asynchronously in background
    if (prize > 0) {
      Future(() async {
        try {
          final currentUser = AuthController.instance.currentUser;
          final todayDate = DateTime.now().toString().split(' ').first;
          final leaderboardRef = FirebaseFirestore.instance
              .collection('pink_greedy_game_leaderboard')
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
      });
    }
  }

  void _animateChip(int itemIndex, int amount) {
    final itemContext = _itemKeys[itemIndex]?.currentContext;
    final chipContext = _chipKeys[amount]?.currentContext;
    final sheetContext = _sheetKey.currentContext;

    if (itemContext != null && chipContext != null && sheetContext != null) {
      final itemBox = itemContext.findRenderObject() as RenderBox;
      final chipBox = chipContext.findRenderObject() as RenderBox;
      final sheetBox = sheetContext.findRenderObject() as RenderBox;

      final itemPos =
          sheetBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
      final chipPos =
          sheetBox.globalToLocal(chipBox.localToGlobal(Offset.zero));

      final chipId = DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(1000).toString();

      setState(() {
        _activeChips.add({
          'id': chipId,
          'start': chipPos,
          'end': itemPos,
          'amount': amount,
        });
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _activeChips.removeWhere((c) => c['id'] == chipId);
          });
        }
      });
    }
  }

  void _syncBets() {
    if (_pendingBets.isEmpty) return;
    
    final betsToSend = Map<int, int>.from(_pendingBets);
    _pendingBets.clear();
    
    for (var entry in betsToSend.entries) {
      final index = entry.key;
      final amount = entry.value;
      
      FirebaseFunctions.instance.httpsCallable('placePinkGreedyGameBet').call({
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
                  child: const Text('OK', style: TextStyle(color: Colors.pinkAccent)),
                ),
              ],
            ),
          );
        }
        throw e;
      });
    }
  }

  void _showHowToPlayRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF4A0028),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'How to play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRuleCard(
                      '1. Choose the amount and the food of your bet.',
                      'Select your chip amount and tap the food items to place your bets.',
                    ),
                    const SizedBox(height: 12),
                    _buildRuleCard(
                      '2. The time for choosing is 30 seconds each round and the winners will be announced after betting.',
                      'You have 30 seconds to place bets each round. After 30s, the wheel spins to reveal the winner.',
                    ),
                    const SizedBox(height: 12),
                    _buildRuleCard(
                      '3. All users choosing the correct food can win the corresponding diamonds.',
                      'If the wheel lands on your selected food, you receive the winning multiplier payout instantly!',
                    ),
                    const SizedBox(height: 12),
                    _buildRuleCard(
                      '4. Each user can choose and bet on up to 6 kinds of food each round, with no upper limit on the bet amount.',
                      'You can pick up to 6 different food items per round with no max limit on total bet diamonds.',
                    ),
                    const SizedBox(height: 12),
                    _buildRuleCard(
                      '5. Prize Pool & Special Pizza / Salad Rules',
                      'If Salad is opened, all players who bet on any vegetable (Carrot, Corn, Cabbage, Tomato) win! If Pizza is opened, all players who bet on any meat (Hotdog, Skewer, Ham, Steak) win!',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.pinkAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
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
              child: const Text('OK', style: TextStyle(color: Colors.pinkAccent)),
            ),
          ],
        ),
      );
      return;
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
              child: const Text('OK', style: TextStyle(color: Colors.pinkAccent)),
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient diamonds!')));
      return;
    }

    // Optimistic update
    _animateChip(index, selectedChip);
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
                colors: [Color(0xFFFF007F), Color(0xFF8B0045)],
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
                                    ? 'assets/images/food_game/pizza.webp'
                                    : 'assets/images/food_game/salad.webp',
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
                      .collection('pink_greedy_game_round_leaderboard')
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
    Future.delayed(const Duration(seconds: 4), () {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
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
            color: Color(0xFF4A0024),
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
                      .collection('pink_greedy_game_bet_history')
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
                              if (win > 0) ...[
                                const Text('Win: ',
                                    style:
                                        TextStyle(color: Colors.greenAccent)),
                                DynamicDiamondIcon(height: 12),
                                Text('$win',
                                    style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold)),
                              ] else ...[
                                const Text('Loss',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold)),
                              ]
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
            color: Color(0xFF4A0024),
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
                      .collection('pink_greedy_game_leaderboard')
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
        return 'assets/images/food_game/pizza.webp';
      case '🥗':
        return 'assets/images/food_game/salad.webp';
      case '🌭':
        return 'assets/images/food_game/hotdog.webp';
      case '🍢':
        return 'assets/images/food_game/skewer.webp';
      case '🍗':
      case '🍖':
        return 'assets/images/food_game/ham.webp';
      case '🥩':
        return 'assets/images/food_game/steak.webp';
      case '🥕':
        return 'assets/images/food_game/carrot.webp';
      case '🌽':
        return 'assets/images/food_game/corn.webp';
      case '🥬':
        return 'assets/images/food_game/cabbage.webp';
      case '🍅':
        return 'assets/images/food_game/tomato.webp';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = MediaQuery.of(context).size.height * (widget.isInAudioRoom ? 0.75 : 1.0);
    return SizedBox(
      key: _sheetKey,
      height: sheetHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: sheetHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3B0B3C),
                  Color(0xFF65154C),
                  Color(0xFF901859)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildWheelArea(),
                            ),
                            _buildPrizeArea(),
                            _buildBettingArea(),
                            const SizedBox(height: 12),
                            _buildFooter(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chip Animations
          ..._activeChips.map((chipData) {
            return TweenAnimationBuilder<double>(
              key: ValueKey(chipData['id']),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final start = chipData['start'] as Offset;
                final end = chipData['end'] as Offset;

                // Add an offset so it targets the center of the bubble
                final currentX = start.dx + (end.dx - start.dx + 25) * value;
                final currentY = start.dy + (end.dy - start.dy + 25) * value;

                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: 1.0 - (value > 0.8 ? (value - 0.8) * 5 : 0),
                    child: Transform.scale(
                      scale: 1.0 - (value * 0.3),
                      child: Image.asset(
                        _getChipImage(chipData['amount']),
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconButton(Icons.watch_later_rounded, _showMyHistory),
              const SizedBox(width: 8),
              _buildIconButton(
                _volumeLevel == 0.0
                    ? Icons.volume_off_rounded
                    : _volumeLevel < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                _showVolumeDialog,
              ),
            ],
          ),
          const Text(
            'Greedy Pink',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          _buildIconButton(Icons.help_outline, _showHowToPlayRules),
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

  Widget _buildWheelArea({bool assignKeys = true}) {
    return Transform.scale(
      scale: 1.12, // Zoom in the entire wheel area
      child: SizedBox(
        height: 450,
        width: 450,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Ferris Wheel Image
            Image.asset(
              'assets/images/pink_wheel_bg_new.webp',
              width: 450,
              height: 450,
              fit: BoxFit.contain,
            ),

            Positioned(
              top: 210,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(
                          0xFFC2185B), // Deep pink to match theme and cover yellow
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      'Round $roundNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPhase == 'betting' ? timeLeft : 0}s',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // The items positioned in the empty bubbles of the background
            AnimatedBuilder(
              animation: Listenable.merge([_spinController, _blinkIndexNotifier, _handTargetIndexNotifier]),
              builder: (context, child) {
                int currentActiveIndex = activeIndex;
                if (_spinController.isAnimating) {
                  int targetPosition = 48 + _winningIndex;
                  double curve = Curves.easeOutCubic.transform(_spinController.value);
                  currentActiveIndex = (curve * targetPosition).floor() % items.length;
                }
                int blinkIndex = _blinkIndexNotifier.value;
                int handTargetIndex = _handTargetIndexNotifier.value;

                return SizedBox(
                  width: 450,
                  height: 450,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                    ...List.generate(items.length, (index) {
                      final List<Offset> bubbleOffsets = const [
                        Offset(0, -172), // 0: Top
                        Offset(132, -128), // 1: Top-Right (moved right 12px, up 12px)
                        Offset(154, -17), // 2: Right (moved left 2px more)
                        Offset(120, 86), // 3: Bottom-Right
                        Offset(0, 130), // 4: Bottom
                        Offset(-120, 86), // 5: Bottom-Left
                        Offset(-157, -17), // 6: Left (moved 3px right)
                        Offset(-132, -128), // 7: Top-Left (moved left 12px, up 12px)
                      ];

                      bool isHighlighted = false;
                      if (!isBettingOpen) {
                        if (currentActiveIndex == index) isHighlighted = true;
                        if (currentActiveIndex == -2 && items[index]['type'] == 'meat') {
                          isHighlighted = true;
                        }
                        if (currentActiveIndex == -3 && items[index]['type'] == 'veg') {
                          isHighlighted = true;
                        }
                      } else {
                        if (timeLeft <= 3 && blinkIndex == index) isHighlighted = true;
                      }

                      final betAmount = userBets[index];
                      return Transform.translate(
                        offset: bubbleOffsets[index],
                        child: GestureDetector(
                          onTap: () => placeBet(index),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                key: assignKeys ? _itemKeys[index] : null,
                                width: 90,
                                height: 90,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isHighlighted
                                      ? Colors.pinkAccent.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  boxShadow: isHighlighted
                                      ? [
                                          BoxShadow(
                                            color: Colors.pinkAccent
                                                .withValues(alpha: 0.8),
                                            blurRadius: 20,
                                            spreadRadius: 8,
                                          )
                                        ]
                                      : [],
                                ),
                                child: items[index]['image'] != null
                                    ? Image.asset(
                                        items[index]['image'] as String,
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Text(
                                          items[index]['emoji'] ?? '',
                                          style: const TextStyle(fontSize: 40),
                                        ),
                                      )
                                    : Text(
                                        items[index]['emoji'] ?? '',
                                        style: const TextStyle(fontSize: 40),
                                      ),
                              ),

                              // Bet amount badge
                              if (betAmount != null)
                                Positioned(
                                  bottom: -10,
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

                    // Hand Assist Icon
                    if (userBets.isEmpty && isBettingOpen)
                      AnimatedBuilder(
                        animation: _handAnimation,
                        builder: (context, child) {
                          final targetOffset = const [
                            Offset(0, -172),
                            Offset(132, -128),
                            Offset(154, -17),
                            Offset(120, 86),
                            Offset(0, 130),
                            Offset(-120, 86),
                            Offset(-157, -17),
                            Offset(-132, -128),
                          ][handTargetIndex];

                          return Transform.translate(
                            offset: Offset(
                              targetOffset.dx,
                              targetOffset.dy + 15 + _handAnimation.value,
                            ),
                            child: const Icon(
                              Icons.touch_app,
                              color: Colors.amber,
                              size: 40,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                            ),
                          );
                        },
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

  Widget _buildPrizeArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPodium('🥗', 'Salad',
              'When the Salad Prize is opened, all players who selected any vegetable ingredient will win a share of the prize pool.'),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, 10),
              child: Image.asset('assets/images/pink_game_center_image.webp',
                  fit: BoxFit.fitWidth),
            ),
          ),
          _buildPodium('🍕', 'Pizza',
              'When the Pizza Prize is opened, all players who selected any meat ingredient will win a share of the prize pool.'),
        ],
      ),
    );
  }

  Widget _buildBettingArea() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF00FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: (_isSuper ? superChips : normalChips).map((amount) {
                  return _buildBetButton(amount);
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF007F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('My Diamond',
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('Users')
                                      .doc(currentUserId)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    int diamonds = 0;
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data = snapshot.data!.data()
                                          as Map<String, dynamic>;
                                      diamonds = data['diamonds'] ?? 0;
                                    }
                                    return Text(diamonds.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold));
                                  }),
                            ],
                          ),
                          Container(
                            decoration: const BoxDecoration(
                                color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(Icons.add,
                                color: Colors.deepOrange, size: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF007F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text("Today's prize",
                              style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('pink_greedy_game_leaderboard')
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
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    DynamicDiamondIcon(height: 14),
                                    const SizedBox(width: 4),
                                    Text(userTodayWon.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                );
                              }),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: isHighlighted ? Colors.white : Colors.transparent,
                width: isHighlighted ? 2 : 1,
              ),
              boxShadow: isHighlighted
                  ? [
                      const BoxShadow(
                          color: Colors.white54,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              name == 'Pizza'
                  ? 'assets/images/food_game/pizza.webp'
                  : 'assets/images/food_game/salad.webp',
              width: 55,
              height: 55,
              errorBuilder: (context, error, stackTrace) =>
                  Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFF65154C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24)),
            child: Text(
              name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getChipImage(int amount) {
    switch (amount) {
      case 100:
        return 'assets/images/chip_100.webp';
      case 1000:
        return 'assets/images/chip_1k.webp';
      case 10000:
        return 'assets/images/chip_10k.webp';
      case 50000:
        return 'assets/images/chip_50k.webp';
      case 100000:
        return 'assets/images/chip_100k.webp';
      default:
        return 'assets/images/chip_100.webp';
    }
  }

  Widget _buildBetButton(int amount) {
    final isSelected = selectedChip == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedChip = amount;
        });
      },
      child: AnimatedContainer(
        key: _chipKeys[amount],
        duration: const Duration(milliseconds: 150),
        transform: isSelected
            ? Matrix4.diagonal3Values(1.1, 1.1, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 15,
                      spreadRadius: 4)
                ]
              : [],
        ),
        child: Image.asset(
          _getChipImage(amount),
          width: 70,
          height: 70,
          fit: BoxFit.contain,
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
                          color: Colors.white,
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
                    .collection('pink_greedy_game_leaderboard')
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
