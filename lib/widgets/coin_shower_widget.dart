import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

/// Particles animation widget for falling coins and diamonds
class CoinShowerWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onCompleted;

  const CoinShowerWidget({
    super.key,
    this.duration = const Duration(seconds: 4),
    this.onCompleted,
  });

  @override
  State<CoinShowerWidget> createState() => _CoinShowerWidgetState();
}

class _CoinShowerWidgetState extends State<CoinShowerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _generateParticles();

    _controller.forward().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        xRatio: _random.nextDouble(),
        speedRatio: 0.6 + _random.nextDouble() * 0.8,
        size: 14.0 + _random.nextDouble() * 10.0,
        initialDelay: _random.nextDouble() * 0.3,
        rotationSpeed: (_random.nextDouble() - 0.5) * 6.0,
        isDiamond: _random.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final size = MediaQuery.of(context).size;

        return IgnorePointer(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: _particles.map((p) {
                final particleProgress = max(0.0, (progress - p.initialDelay) / (1.0 - p.initialDelay));
                if (particleProgress <= 0 || particleProgress >= 1.0) {
                  return const SizedBox.shrink();
                }

                final currentY = particleProgress * (size.height + 100) * p.speedRatio - 50;
                final currentX = p.xRatio * size.width + sin(particleProgress * pi * 4) * 20;
                final rotation = particleProgress * pi * p.rotationSpeed;
                final opacity = (1.0 - particleProgress).clamp(0.0, 1.0);

                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.isDiamond ? Colors.cyan.withValues(alpha: 0.6) : Colors.amber.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: p.isDiamond
                            ? DynamicDiamondIcon(
                                width: p.size,
                                height: p.size,
                                fit: BoxFit.contain,
                              )
                            : Icon(
                                Icons.monetization_on_rounded,
                                size: p.size,
                                color: Colors.amberAccent,
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  final double xRatio;
  final double speedRatio;
  final double size;
  final double initialDelay;
  final double rotationSpeed;
  final bool isDiamond;

  _Particle({
    required this.xRatio,
    required this.speedRatio,
    required this.size,
    required this.initialDelay,
    required this.rotationSpeed,
    required this.isDiamond,
  });
}
