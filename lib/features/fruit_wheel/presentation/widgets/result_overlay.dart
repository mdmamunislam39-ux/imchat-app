import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/round_state_model.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class ResultOverlay extends StatefulWidget {
  final String result; // "watermelon", "plum", "sevens"
  final List<WinnerEntry> winners;
  final int myTotalBet;
  final int myWinAmount;

  const ResultOverlay({
    super.key,
    required this.result,
    required this.winners,
    this.myTotalBet = 0,
    this.myWinAmount = 0,
  });

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.winners.isNotEmpty) {
      for (int i = 0; i < 40; i++) {
        _particles.add(_ConfettiParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble() * 0.3,
          speed: 0.5 + _random.nextDouble() * 1.5,
          angle: _random.nextDouble() * 2 * pi,
          size: 4 + _random.nextDouble() * 6,
          color: [
            const Color(0xFFFFD700),
            const Color(0xFFFF6B8A),
            const Color(0xFF4CAF50),
            const Color(0xFF2196F3),
            const Color(0xFFFF9800),
            const Color(0xFFE040FB),
          ][_random.nextInt(6)],
        ));
      }
      _confettiController.repeat();

      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.mediumImpact();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        HapticFeedback.mediumImpact();
      });
    } else {
      HapticFeedback.mediumImpact();
    }

    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  static const Map<String, String> _symbolEmoji = {
    'watermelon': '🍉',
    'plum': '🍇',
    'sevens': '7️⃣7️⃣',
  };

  static const Map<String, String> _symbolName = {
    'watermelon': 'Watermelon',
    'plum': 'Plum',
    'sevens': '77',
  };

  @override
  Widget build(BuildContext context) {
    final hasWinners = widget.winners.isNotEmpty;

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              // Confetti layer
              if (hasWinners)
                AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _ConfettiPainter(
                        _particles,
                        _confettiController.value,
                      ),
                    );
                  },
                ),

              // Result card
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasWinners
                            ? [
                                const Color(0xFF1B5E20),
                                const Color(0xFF2E7D32),
                              ]
                            : [
                                const Color(0xFF37474F),
                                const Color(0xFF455A64),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasWinners
                            ? const Color(0xFFFFD700)
                            : Colors.white24,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (hasWinners
                                  ? const Color(0xFFFFD700)
                                  : Colors.white)
                              .withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Result emoji
                        widget.result == 'sevens'
                            ? Image.asset('assets/images/77_icon.webp', width: 44, height: 44)
                            : Text(
                                _symbolEmoji[widget.result] ?? '?',
                                style: const TextStyle(fontSize: 44),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          _symbolName[widget.result] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Personal Result
                        if (widget.myTotalBet > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.myWinAmount > 0 ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Your Bet: ${widget.myTotalBet} ',
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                    DynamicDiamondIcon(width: 14, height: 14),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.myWinAmount > 0 
                                          ? 'You Won: ${widget.myWinAmount} '
                                          : 'You Lost 😢',
                                      style: TextStyle(
                                        color: widget.myWinAmount > 0 ? const Color(0xFF81C784) : const Color(0xFFEF5350),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (widget.myWinAmount > 0) ...[
                                      DynamicDiamondIcon(width: 16, height: 16),
                                      const Text(' 🎉', style: TextStyle(fontSize: 16)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Winners header
                        if (hasWinners) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏆',
                                  style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                'WINNERS (${widget.winners.length})',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 8),
                          // Winners list
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: widget.winners.length,
                              itemBuilder: (context, index) {
                                final winner = widget.winners[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      // Profile image
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: index == 0
                                                ? const Color(0xFFFFD700)
                                                : Colors.white24,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: winner.photo.isNotEmpty
                                              ? Image.network(
                                                  winner.photo,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.person,
                                                    color: Colors.white38,
                                                    size: 18,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  color: Colors.white38,
                                                  size: 18,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Name
                                      Expanded(
                                        child: Text(
                                          winner.name,
                                          style: TextStyle(
                                            color: index == 0
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 14,
                                            fontWeight: index == 0
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Payout
                                      const SizedBox(width: 4),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Won: ${_formatAmount(winner.payout)} ',
                                        style: TextStyle(
                                          color: index == 0
                                              ? const Color(0xFFFFD700)
                                              : const Color(0xFF81C784),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      DynamicDiamondIcon(width: 12, height: 12),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'NO WINNERS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class _ConfettiParticle {
  final double x;
  final double y;
  final double speed;
  final double angle;
  final double size;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width + sin(p.angle + progress * 10) * 20;
      final y = (p.y + progress * p.speed) * size.height;

      if (y > size.height) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: 1.0 - progress * 0.5)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.speed * 5);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
