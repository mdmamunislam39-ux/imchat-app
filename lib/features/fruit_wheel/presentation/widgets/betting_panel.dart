import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


/// Premium casino-style bet card with gold accents.
class BetCard extends StatefulWidget {
  final String symbol;
  final String emoji;
  final int multiplier;
  final int userBet;
  final int totalBet;
  final bool isWinner;
  final bool isBettingOpen;
  final bool soundEnabled;
  final VoidCallback? onTap;

  const BetCard({
    super.key,
    required this.symbol,
    required this.emoji,
    required this.multiplier,
    required this.userBet,
    required this.totalBet,
    required this.isWinner,
    required this.isBettingOpen,
    this.soundEnabled = true,
    this.onTap,
  });

  @override
  State<BetCard> createState() => _BetCardState();
}

class _BetCardState extends State<BetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isBettingOpen) return;
    _tapController.forward().then((_) => _tapController.reverse());
    if (widget.soundEnabled) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasBet = widget.userBet > 0;

    // Border colors based on state
    final borderColor = widget.isWinner
        ? const Color(0xFFFFD700)
        : hasBet
            ? const Color(0xFFFF6B8A).withValues(alpha: 0.9)
            : const Color(0xFFDAA520).withValues(alpha: 0.25);

    // Background gradient based on state
    final bgColors = widget.isWinner
        ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
        : hasBet
            ? [const Color(0xFF3D1170), const Color(0xFF2A0B50)]
            : [const Color(0xFF1E0845), const Color(0xFF150630)];

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: bgColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: borderColor,
              width: widget.isWinner ? 2.5 : 1.5,
            ),
            boxShadow: widget.isWinner
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : hasBet
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B8A).withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total pool
              Text(
                _formatAmount(widget.totalBet),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // Emoji symbol
              widget.emoji == '7️⃣7️⃣' 
                 ? Image.asset('assets/images/77_icon.png', width: 34, height: 34) 
                 : Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),

              // Multiplier badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.2),
                      const Color(0xFFDAA520).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  'x${widget.multiplier}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // User bet amount
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: hasBet
                      ? const Color(0xFFFF6B8A).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: hasBet
                      ? Border.all(
                          color:
                              const Color(0xFFFF6B8A).withValues(alpha: 0.35),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBet) ...[
                      DynamicDiamondIcon(width: 11, height: 11),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      hasBet ? _formatAmount(widget.userBet) : '-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: hasBet
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toString();
  }
}

/// The full betting panel with all 3 symbols.
class BettingPanel extends StatelessWidget {
  final Map<String, int> userBets;
  final Map<String, int> totalBets;
  final String? result;
  final bool isBettingOpen;
  final bool soundEnabled;
  final String phase;
  final void Function(String symbol) onBet;

  const BettingPanel({
    super.key,
    required this.userBets,
    required this.totalBets,
    this.result,
    required this.isBettingOpen,
    this.soundEnabled = true,
    required this.phase,
    required this.onBet,
  });

  @override
  Widget build(BuildContext context) {
    final isResultPhase = phase == 'result';

    return Row(
      children: [
        Expanded(
          child: BetCard(
            symbol: 'watermelon',
            emoji: '🍉',
            multiplier: 2,
            userBet: userBets['watermelon'] ?? 0,
            totalBet: totalBets['watermelon'] ?? 0,
            isWinner: isResultPhase && result == 'watermelon',
            isBettingOpen: isBettingOpen,
            soundEnabled: soundEnabled,
            onTap: () => onBet('watermelon'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BetCard(
            symbol: 'sevens',
            emoji: '7️⃣7️⃣',
            multiplier: 8,
            userBet: userBets['sevens'] ?? 0,
            totalBet: totalBets['sevens'] ?? 0,
            isWinner: isResultPhase && result == 'sevens',
            isBettingOpen: isBettingOpen,
            soundEnabled: soundEnabled,
            onTap: () => onBet('sevens'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BetCard(
            symbol: 'plum',
            emoji: '🍇',
            multiplier: 2,
            userBet: userBets['plum'] ?? 0,
            totalBet: totalBets['plum'] ?? 0,
            isWinner: isResultPhase && result == 'plum',
            isBettingOpen: isBettingOpen,
            soundEnabled: soundEnabled,
            onTap: () => onBet('plum'),
          ),
        ),
      ],
    );
  }
}
