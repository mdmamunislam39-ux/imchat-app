import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/screens/room/wallet_screen.dart';

import '../../data/models/user_bet_history_model.dart';
import '../../data/repositories/fruit_wheel_repository_impl.dart';
import '../bloc/fruit_wheel_bloc.dart';
import '../bloc/fruit_wheel_event.dart';
import '../bloc/fruit_wheel_state.dart';
import '../widgets/spinning_wheel.dart';
import '../widgets/daily_ranking_sheet.dart';
import '../widgets/betting_panel.dart';
import '../widgets/chip_selector.dart';
import '../widgets/round_timer.dart';
import '../widgets/round_history.dart';
import '../widgets/result_overlay.dart';
import '../widgets/diamond_balance.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


/// Shows the Fruit Wheel game as a bottom sheet (in voice room) or full screen (outside voice room).
void showFruitWheelSheet(BuildContext context, {bool isInAudioRoom = true}) {
  if (!isInAudioRoom) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFF0D0020),
          body: SafeArea(
            child: Stack(
              children: [
                const FruitWheelSheet(isInAudioRoom: false),
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
      enableDrag: true,
      builder: (_) => const SafeArea(top: false, bottom: true, child: FruitWheelSheet(isInAudioRoom: true)),
    );
  }
}

class FruitWheelSheet extends StatelessWidget {
  final bool isInAudioRoom;
  const FruitWheelSheet({super.key, this.isInAudioRoom = true});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FruitWheelBloc(
        repository: FruitWheelRepositoryImpl(
          realtimeDb: FirebaseDatabase.instance,
          auth: FirebaseAuth.instance,
          firestore: FirebaseFirestore.instance,
        ),
      )..add(ConnectToGame()),
      child: _FruitWheelSheetContent(isInAudioRoom: isInAudioRoom),
    );
  }
}

class _FruitWheelSheetContent extends StatefulWidget {
  final bool isInAudioRoom;
  const _FruitWheelSheetContent({this.isInAudioRoom = true});

  @override
  State<_FruitWheelSheetContent> createState() =>
      _FruitWheelSheetContentState();
}

class _FruitWheelSheetContentState extends State<_FruitWheelSheetContent>
    with TickerProviderStateMixin {
  final GlobalKey _bettingPanelKey = GlobalKey();
  final GlobalKey _chipSelectorKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final List<_FlyingChip> _flyingChips = [];
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  // Track previous totalBets to detect new bets from ANY user
  Map<String, int> _prevTotalBets = {};
  int _prevRoundNumber = -1;

  /// Called from the BlocConsumer listener on every state change.
  /// Compares totalBets to detect increases and triggers the animation.
  void _detectNewBets(FruitWheelState state) {
    if (state is! FruitWheelActive) return;

    final round = state.roundState;

    // New round started — reset tracking, don't animate
    if (round.roundNumber != _prevRoundNumber) {
      _prevRoundNumber = round.roundNumber;
      _prevTotalBets = Map.from(round.totalBets);
      return;
    }

    // Check each symbol for bet increases
    for (final symbol in ['watermelon', 'sevens', 'plum']) {
      final prev = _prevTotalBets[symbol] ?? 0;
      final curr = round.totalBets[symbol] ?? 0;
      if (curr > prev) {
        _animateBet(symbol);
      }
    }
    _prevTotalBets = Map.from(round.totalBets);
  }

  void _animateBet(String symbol) {
    final chipBox =
        _chipSelectorKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _bettingPanelKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;

    if (chipBox == null || panelBox == null || stackBox == null) return;

    // Start: center of chip selector
    final startGlobal = chipBox.localToGlobal(chipBox.size.center(Offset.zero));
    final start = stackBox.globalToLocal(startGlobal);

    // End: center of the target bet card
    final panelWidth = panelBox.size.width;
    final cardWidth = (panelWidth - 16) / 3; // 16 = 2 × 8px gaps
    double cardCenterX;
    switch (symbol) {
      case 'watermelon':
        cardCenterX = cardWidth / 2;
        break;
      case 'sevens':
        cardCenterX = cardWidth + 8 + cardWidth / 2;
        break;
      case 'plum':
      default:
        cardCenterX = cardWidth * 2 + 16 + cardWidth / 2;
        break;
    }
    final endLocal = Offset(cardCenterX, panelBox.size.height / 2);
    final endGlobal = panelBox.localToGlobal(endLocal);
    final end = stackBox.globalToLocal(endGlobal);

    // Spawn 3 diamonds with slight variation for a burst effect
    final random = Random();
    for (int i = 0; i < 3; i++) {
      final delay = Duration(milliseconds: i * 60);
      Future.delayed(delay, () {
        if (!mounted) return;
        final offsetX = (random.nextDouble() - 0.5) * 30;
        final offsetY = (random.nextDouble() - 0.5) * 20;
        final chipStart = Offset(start.dx + offsetX, start.dy + offsetY);

        final controller = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 420 + random.nextInt(120)),
        );

        final chip = _FlyingChip(
          start: chipStart,
          end: end,
          controller: controller,
          arcHeight: 50 + random.nextDouble() * 40,
        );

        setState(() => _flyingChips.add(chip));
        controller.forward().then((_) {
          if (mounted) {
            if (_hapticEnabled) HapticFeedback.selectionClick();
            setState(() => _flyingChips.remove(chip));
          }
          controller.dispose();
        });
      });
    }
  }

  void _showGameSettings() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E0845),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            title: const Text(
              'Game Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _settingsRow(
                  icon: Icons.volume_up_rounded,
                  label: 'Sound',
                  value: _soundEnabled,
                  onChanged: (val) {
                    setDialogState(() => _soundEnabled = val);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                _settingsRow(
                  icon: Icons.vibration_rounded,
                  label: 'Haptic',
                  value: _hapticEnabled,
                  onChanged: (val) {
                    setDialogState(() => _hapticEnabled = val);
                    setState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Done',
                  style: TextStyle(color: Color(0xFFDAA520)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFDAA520),
            activeTrackColor: const Color(0xFFDAA520).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  void _showBetHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _BetHistorySheet(),
    );
  }

  void _showDailyRankings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DailyRankingSheet(),
    );
  }

  @override
  void dispose() {
    for (final chip in List.of(_flyingChips)) {
      chip.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight * (widget.isInAudioRoom ? 0.75 : 1.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A0E6E), Color(0xFF1E0840), Color(0xFF0D0020)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        key: _stackKey,
        children: [
          // Main content
          Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Game content
              Expanded(
                child: BlocConsumer<FruitWheelBloc, FruitWheelState>(
                  listener: (context, state) {
                    if (state is FruitWheelError) {
                      if (_hapticEnabled) HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.message,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          backgroundColor: const Color(0xFFCC2244),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(milliseconds: 1500),
                        ),
                      );
                    }

                    // Detect bet increases from ANY user (local + remote)
                    _detectNewBets(state);
                  },
                  builder: (context, state) {
                    final activeState = state is FruitWheelActive
                        ? state
                        : null;
                    final isActive = activeState != null;
                    final round = activeState?.roundState;
                    final phase = round?.phase ?? 'betting';
                    final isResultPhase = phase == 'result';

                    int myTotalBet = 0;
                    int myWinAmount = 0;
                    if (isResultPhase && round != null && round.result != null) {
                      myTotalBet = round.userBets.values.fold(0, (total, amt) => total + amt);
                      if (round.userBets.containsKey(round.result)) {
                        int multiplier = round.result == 'sevens' ? 8 : 2;
                        myWinAmount = round.userBets[round.result!]! * multiplier;
                      }
                    }

                    return AnimatedOpacity(
                      opacity: isActive ? 1.0 : 0.6,
                      duration: const Duration(milliseconds: 400),
                      child: Column(
                        children: [
                          // Top bar: timer + balance
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: round != null
                                        ? RoundTimer(
                                            key: ValueKey(round.roundNumber),
                                            phaseEndTime: round.phaseEndTime,
                                            phase: round.phase,
                                            roundNumber: round.roundNumber,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _GameSettingsButton(
                                  onTap: _showGameSettings,
                                ),
                                const SizedBox(width: 8),
                                _RankingsButton(
                                  onTap: () => _showDailyRankings(context),
                                ),
                                const SizedBox(width: 8),
                                _BetHistoryButton(
                                  onTap: () => _showBetHistory(context),
                                ),
                                const SizedBox(width: 8),
                                Obx(() => DiamondBalance(
                                  diamonds: AuthController.instance.currentUser.diamonds,
                                )),
                              ],
                            ),
                          ),

                          // Wheel + overlays
                          Expanded(
                            child: Stack(
                              children: [
                                // Spinning wheel
                                Center(
                                  child: SpinningWheel(
                                    phase: phase,
                                    result: round?.result,
                                  ),
                                ),

                                // History sidebar — left
                                if (activeState != null &&
                                    activeState.history.isNotEmpty)
                                  Positioned(
                                    left: 6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: RoundHistory(
                                        history: activeState.history,
                                      ),
                                    ),
                                  ),

                                // Result overlay — shown to all users
                                if (isResultPhase && round?.result != null)
                                  Positioned.fill(
                                    child: ResultOverlay(
                                      result: round!.result!,
                                      winners: round.winners,
                                      myTotalBet: myTotalBet,
                                      myWinAmount: myWinAmount,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Betting panel
                          AnimatedOpacity(
                            opacity: phase == 'betting' ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 300),
                            child: Padding(
                              key: _bettingPanelKey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: BettingPanel(
                                userBets: round?.userBets ?? {},
                                totalBets: round?.totalBets ?? {},
                                result: round?.result,
                                isBettingOpen: round?.isBettingOpen ?? false,
                                phase: phase,
                                soundEnabled: _soundEnabled,
                                onBet: (symbol) {
                                  if (_hapticEnabled) HapticFeedback.lightImpact();

                                  int amountToBet = activeState?.selectedChipAmount ?? 100;
                                  int currentBalance = AuthController.instance.currentUser.diamonds;
                                  
                                  if (currentBalance < amountToBet) {
                                      showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(0xFF1E0845),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.5), width: 2)),
                                            title: Row(
                                              children: const [
                                                Icon(Icons.warning_amber_rounded, color: Color(0xFFDAA520)),
                                                SizedBox(width: 8),
                                                Text('Insufficient Diamonds', style: TextStyle(color: Colors.white, fontSize: 18)),
                                              ],
                                            ),
                                            content: const Text('You do not have enough diamonds to place this bet. Please recharge your wallet.', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  Navigator.pop(context); // Close the fruit wheel sheet
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DiamondRechargePage(
                                                        diamondBalance: currentBalance,
                                                        walletService: WalletService(),
                                                        userId: AuthController.instance.currentUser.userId,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Recharge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                              ),
                                            ],
                                          ),
                                        );
                                      return;
                                  }

                                  context.read<FruitWheelBloc>().add(
                                    PlaceBet(
                                      symbol: symbol,
                                      amount: amountToBet,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Chip selector
                          Padding(
                            key: _chipSelectorKey,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ChipSelector(
                              selectedAmount:
                                  activeState?.selectedChipAmount ?? 500,
                              onSelected: (amount) {
                                if (_hapticEnabled) HapticFeedback.selectionClick();
                                context.read<FruitWheelBloc>().add(
                                  SelectChipAmount(amount),
                                );
                              },
                            ),
                          ),

                          SizedBox(height: bottomPadding + 10),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Flying diamond chips overlay
          for (final chip in _flyingChips) _FlyingChipWidget(chip: chip),
        ],
      ),
    );
  }
}

/// Data for a single flying diamond animation.
class _FlyingChip {
  final Offset start;
  final Offset end;
  final AnimationController controller;
  final double arcHeight;

  _FlyingChip({
    required this.start,
    required this.end,
    required this.controller,
    this.arcHeight = 70,
  });
}

/// Animated diamond that flies along a bezier arc with 3D flip.
class _FlyingChipWidget extends StatelessWidget {
  final _FlyingChip chip;

  const _FlyingChipWidget({required this.chip});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: chip.controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(chip.controller.value);

        // Quadratic bezier arc
        final controlPoint = Offset(
          (chip.start.dx + chip.end.dx) / 2,
          min(chip.start.dy, chip.end.dy) - chip.arcHeight,
        );
        final x = _quadBezier(chip.start.dx, controlPoint.dx, chip.end.dx, t);
        final y = _quadBezier(chip.start.dy, controlPoint.dy, chip.end.dy, t);

        // Scale: grow then shrink on landing
        final scale = t < 0.3
            ? 0.4 +
                  t *
                      3.0 // 0.4 → 1.3
            : t < 0.7
            ? 1.3 // hold
            : 1.3 - (t - 0.7) * 2.0; // 1.3 → 0.7

        // 3D Y-axis flip
        final flipAngle = t * pi * 3;

        // Opacity: quick fade in, solid, fade out at end
        final opacity = t < 0.08
            ? t / 0.08
            : t > 0.8
            ? (1 - t) / 0.2
            : 1.0;

        return Positioned(
          left: x - 14,
          top: y - 14,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale.clamp(0.3, 1.5),
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateY(flipAngle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFFF).withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: DynamicDiamondIcon(width: 18, height: 18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _quadBezier(double p0, double p1, double p2, double t) {
    return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;
  }
}

class _GameSettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GameSettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Icon(Icons.settings, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _BetHistoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BetHistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Icon(Icons.history, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _BetHistorySheet extends StatefulWidget {
  const _BetHistorySheet();

  @override
  State<_BetHistorySheet> createState() => _BetHistorySheetState();
}

class _BetHistorySheetState extends State<_BetHistorySheet> {
  late Future<List<UserBetHistoryModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = FruitWheelRepositoryImpl(
      realtimeDb: FirebaseDatabase.instance,
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    ).getUserBetHistory(limit: 30);
  }

  static const Map<String, String> _symbolEmoji = {
    'watermelon': '🍉',
    'plum': '🍇',
    'sevens': '7️⃣7️⃣',
  };

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A0E6E), Color(0xFF1E0840)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bet History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // List
          Expanded(
            child: FutureBuilder<List<UserBetHistoryModel>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  );
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(
                    child: Text(
                      'No bets yet',
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: bottomPadding + 12,
                    left: 14,
                    right: 14,
                  ),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _BetHistoryRow(
                    entry: history[i],
                    symbolEmoji: _symbolEmoji,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BetHistoryRow extends StatelessWidget {
  final UserBetHistoryModel entry;
  final Map<String, String> symbolEmoji;

  const _BetHistoryRow({required this.entry, required this.symbolEmoji});

  @override
  Widget build(BuildContext context) {
    final net = entry.netResult;
    final isWin = net > 0;
    final resultEmoji = symbolEmoji[entry.result] ?? '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isWin ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))
              .withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Round number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                '#${entry.roundNumber}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bets placed
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: entry.bets.entries
                      .where((e) => e.value > 0)
                      .map((e) {
                         return Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              e.key == 'sevens' 
                                 ? Image.asset('assets/images/77_icon.webp', width: 14) 
                                 : Text(symbolEmoji[e.key] ?? e.key),
                              const SizedBox(width: 4),
                              Text('${e.value}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                           ]
                         );
                      }).toList(),
                ),
                const SizedBox(height: 2),
                Row(
                   children: [
                      const Text('Result: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      entry.result == 'sevens' 
                          ? Image.asset('assets/images/77_icon.webp', width: 12) 
                          : Text(resultEmoji, style: const TextStyle(fontSize: 11)),
                   ]
                ),
              ],
            ),
          ),
          // Win/loss amount
          Row(
            children: [
              Text(
                '${isWin ? '+' : ''}$net ',
                style: TextStyle(
                  color: isWin ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DynamicDiamondIcon(width: 14, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RankingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
