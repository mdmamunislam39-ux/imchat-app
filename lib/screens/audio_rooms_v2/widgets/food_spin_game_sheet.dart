import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

class FoodSpinSymbol {
  final String id;
  final String name;
  final String imageAsset;
  final String label;
  final int multiplier;
  final Color color;

  const FoodSpinSymbol({
    required this.id,
    required this.name,
    required this.imageAsset,
    required this.label,
    required this.multiplier,
    required this.color,
  });
}

class FoodSpinGameSheet extends StatefulWidget {
  final bool isInAudioRoom;
  const FoodSpinGameSheet({super.key, this.isInAudioRoom = true});

  static void show(BuildContext context, {bool isInAudioRoom = true}) {
    if (!isInAudioRoom) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFF141422),
            body: SafeArea(
              child: Stack(
                children: [
                  const FoodSpinGameSheet(isInAudioRoom: false),
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
        builder: (context) => const SafeArea(top: false, bottom: true, child: FoodSpinGameSheet(isInAudioRoom: true)),
      ).then((_) {
        WidgetsBinding.instance.scheduleFrame();
      });
    }
  }

  @override
  State<FoodSpinGameSheet> createState() => _FoodSpinGameSheetState();
}

class _FoodSpinGameSheetState extends State<FoodSpinGameSheet>
    with TickerProviderStateMixin {
  static const List<FoodSpinSymbol> symbols = [
    FoodSpinSymbol(
      id: 'jackpot',
      name: 'Steak Jackpot',
      imageAsset: 'assets/images/food_game/steak.webp',
      label: '50x',
      multiplier: 50,
      color: Colors.amber,
    ),
    FoodSpinSymbol(
      id: 'burger',
      name: 'Hotdog',
      imageAsset: 'assets/images/food_game/hotdog.webp',
      label: '25x',
      multiplier: 25,
      color: Colors.orange,
    ),
    FoodSpinSymbol(
      id: 'pizza',
      name: 'Pizza',
      imageAsset: 'assets/images/food_game/pizza.webp',
      label: '20x',
      multiplier: 20,
      color: Colors.redAccent,
    ),
    FoodSpinSymbol(
      id: 'taco',
      name: 'Skewer',
      imageAsset: 'assets/images/food_game/skewer.webp',
      label: '15x',
      multiplier: 15,
      color: Colors.yellow,
    ),
    FoodSpinSymbol(
      id: 'fries',
      name: 'Ham',
      imageAsset: 'assets/images/food_game/ham.webp',
      label: '10x',
      multiplier: 10,
      color: Colors.amberAccent,
    ),
    FoodSpinSymbol(
      id: 'donut',
      name: 'Carrot',
      imageAsset: 'assets/images/food_game/carrot.webp',
      label: '5x',
      multiplier: 5,
      color: Colors.pinkAccent,
    ),
    FoodSpinSymbol(
      id: 'icecream',
      name: 'Corn',
      imageAsset: 'assets/images/food_game/corn.webp',
      label: '3x',
      multiplier: 3,
      color: Colors.lightBlueAccent,
    ),
  ];

  static const List<int> betOptions = [100, 500, 1000, 5000];

  int selectedBet = 100;
  bool isSpinning = false;

  int reel1Index = 0;
  int reel2Index = 1;
  int reel3Index = 2;

  late AnimationController _reel1Controller;
  late AnimationController _reel2Controller;
  late AnimationController _reel3Controller;

  final Random _random = Random();
  List<Widget> lastWinsHistory = [];

  String get currentUserId => AuthController.instance.currentUser.userId;

  @override
  void initState() {
    super.initState();
    _reel1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _reel2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _reel3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    reel1Index = _random.nextInt(symbols.length);
    reel2Index = _random.nextInt(symbols.length);
    reel3Index = _random.nextInt(symbols.length);
    
    // Initial dummy history
    lastWinsHistory = [
      _buildHistoryRow(symbols[0], symbols[0], symbols[0]),
      _buildHistoryRow(symbols[1], symbols[1], symbols[1]),
      _buildHistoryRow(symbols[2], symbols[2], symbols[2]),
    ];
  }

  @override
  void dispose() {
    _reel1Controller.dispose();
    _reel2Controller.dispose();
    _reel3Controller.dispose();
    super.dispose();
  }

  Future<void> _startSpin() async {
    if (isSpinning) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final currentBalance = (userDoc.data()?['diamonds'] ?? 0) as int;

    if (currentBalance < selectedBet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough diamonds for this bet!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({
      'diamonds': FieldValue.increment(-selectedBet),
    });

    setState(() {
      isSpinning = true;
    });

    final target1 = _random.nextInt(symbols.length);
    final target2 = _random.nextInt(symbols.length);
    final target3 = _random.nextInt(symbols.length);

    _reel1Controller.reset();
    _reel2Controller.reset();
    _reel3Controller.reset();

    // Start reel animations
    _reel1Controller.forward();
    _reel2Controller.forward();
    final f3 = _reel3Controller.forward();

    final Timer timer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (mounted && isSpinning) {
        setState(() {
          if (_reel1Controller.isAnimating) {
            reel1Index = (reel1Index + 1) % symbols.length;
          }
          if (_reel2Controller.isAnimating) {
            reel2Index = (reel2Index + 1) % symbols.length;
          }
          if (_reel3Controller.isAnimating) {
            reel3Index = (reel3Index + 1) % symbols.length;
          }
        });
      }
    });

    await f3;
    timer.cancel();

    if (!mounted) return;

    setState(() {
      reel1Index = target1;
      reel2Index = target2;
      reel3Index = target3;
      isSpinning = false;
    });

    _calculatePayout(target1, target2, target3);
  }

  Future<void> _calculatePayout(int r1, int r2, int r3) async {
    final s1 = symbols[r1];
    final s2 = symbols[r2];
    final s3 = symbols[r3];

    int winMultiplier = 0;
    String winMessage = '';

    if (r1 == r2 && r2 == r3) {
      winMultiplier = s1.multiplier;
      winMessage = 'JACKPOT! 3x Match';
    } else if (r1 == r2 || r2 == r3 || r1 == r3) {
      final matchedSymbol = (r1 == r2) ? s1 : ((r2 == r3) ? s2 : s1);
      winMultiplier = max(2, (matchedSymbol.multiplier / 2).floor());
      winMessage = 'PAIR MATCH! 2x Match';
    }

    final winAmount = selectedBet * winMultiplier;

    if (winAmount > 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'diamonds': FieldValue.increment(winAmount),
      });

      setState(() {
        lastWinsHistory.insert(0, _buildHistoryRow(s1, s2, s3));
        if (lastWinsHistory.length > 5) lastWinsHistory.removeLast();
      });

      if (mounted) {
        _showWinDialog(winMessage, winAmount, winMultiplier, (r1 == r2 && r2 == r3) ? s1 : ((r1 == r2) ? s1 : ((r2 == r3) ? s2 : s1)));
      }
    }
  }
  
  Widget _buildHistoryRow(FoodSpinSymbol s1, FoodSpinSymbol s2, FoodSpinSymbol s3) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(s1.imageAsset, width: 14, height: 14),
        const SizedBox(width: 2),
        Image.asset(s2.imageAsset, width: 14, height: 14),
        const SizedBox(width: 2),
        Image.asset(s3.imageAsset, width: 14, height: 14),
      ],
    );
  }

  void _showWinDialog(String title, int amount, int multiplier, FoodSpinSymbol symbol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: symbol.color, width: 2),
        ),
        title: Center(
          child: Text(
            title,
            style: TextStyle(
              color: symbol.color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(symbol.imageAsset, width: 60, height: 60),
            const SizedBox(height: 12),
            const Text(
              '🎉 WINNER 🎉',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DynamicDiamondIcon(width: 28, height: 28),
                const SizedBox(width: 8),
                Text(
                  '+$amount',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '($multiplier Multiplier)',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: symbol.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CLAIM',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Food Spin Rules & Multipliers',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...symbols.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Image.asset(s.imageAsset, width: 24, height: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '3x Match = ${s.label}',
                        style: TextStyle(
                          color: s.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              '• Matching any 2 symbols pays 2x or half symbol multiplier.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: MediaQuery.of(context).size.height * (widget.isInAudioRoom ? 0.75 : 1.0),
        decoration: const BoxDecoration(
          color: Color(0xFF141422),
          image: DecorationImage(
            image: AssetImage('assets/images/food_game/food_spin_bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildGlassContainer(
              borderRadius: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.amber),
                        onPressed: _showRules,
                      ),
                      const Row(
                        children: [
                          Icon(Icons.casino, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'FOOD SPIN',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          int userDiamonds = 0;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            userDiamonds = (data?['diamonds'] ?? 0) as int;
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const DynamicDiamondIcon(width: 16, height: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$userDiamonds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildGlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 24,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'WIN UP TO 50X DIAMONDS',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildReel(symbols[reel1Index]),
                              _buildReel(symbols[reel2Index]),
                              _buildReel(symbols[reel3Index]),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 2,
                            color: Colors.redAccent.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'SELECT BET AMOUNT',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: betOptions.map((bet) {
                              final isSelected = selectedBet == bet;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: isSpinning
                                      ? null
                                      : () => setState(() => selectedBet = bet),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.amber.withValues(alpha: 0.9)
                                          : Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.amberAccent
                                            : Colors.transparent,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        DynamicDiamondIcon(
                                            width: 14,
                                            height: 14,
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$bet',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSpinning ? Colors.grey : Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: Colors.amber.withValues(alpha: 0.5),
                        ),
                        onPressed: isSpinning ? null : _startSpin,
                        child: isSpinning
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'SPIN NOW',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (lastWinsHistory.isNotEmpty) ...[
                      _buildGlassContainer(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RECENT COMBINATIONS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: lastWinsHistory
                                    .map((historyRow) => Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: historyRow,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReel(FoodSpinSymbol symbol) {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: symbol.color.withValues(alpha: 0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: symbol.color.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSpinning ? 0.8 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Image.asset(symbol.imageAsset, width: 44, height: 44),
          ),
          const SizedBox(height: 8),
          Text(
            symbol.label,
            style: TextStyle(
              color: symbol.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
