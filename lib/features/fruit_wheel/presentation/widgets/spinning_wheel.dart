import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium casino-style spinning wheel with gold frame and casino lights.
class SpinningWheel extends StatefulWidget {
  final String? result;
  final String phase;
  final VoidCallback? onSpinComplete;

  const SpinningWheel({
    super.key,
    this.result,
    required this.phase,
    this.onSpinComplete,
  });

  @override
  State<SpinningWheel> createState() => _SpinningWheelState();
}

class _SpinningWheelState extends State<SpinningWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0;
  String? _lastSpunResult;
  int _lastTickSlice = 0; // Track slice crossings for haptic ticks

  // Richer, deeper slice colors for premium feel
  static const List<WheelSlice> slices = [
    WheelSlice('watermelon', Color(0xFFE8345A), '🍉'),
    WheelSlice('plum', Color(0xFF7B2D8E), '🍇'),
    WheelSlice('watermelon', Color(0xFFD42B50), '🍉'),
    WheelSlice('sevens', Color(0xFFDAA520), '77'),
    WheelSlice('watermelon', Color(0xFFE8345A), '🍉'),
    WheelSlice('plum', Color(0xFF6B2480), '🍇'),
    WheelSlice('watermelon', Color(0xFFD42B50), '🍉'),
    WheelSlice('plum', Color(0xFF7B2D8E), '🍇'),
    WheelSlice('watermelon', Color(0xFFE8345A), '🍉'),
    WheelSlice('plum', Color(0xFF6B2480), '🍇'),
    WheelSlice('watermelon', Color(0xFFD42B50), '🍉'),
    WheelSlice('plum', Color(0xFF7B2D8E), '🍇'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(SpinningWheel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset for new round so the same symbol can win consecutively
    if (widget.phase == 'betting' && oldWidget.phase != 'betting') {
      _lastSpunResult = null;
    }

    if (widget.phase == 'spinning' &&
        widget.result != null &&
        widget.result != _lastSpunResult) {
      _startSpin(widget.result!);
    }
  }

  void _startSpin(String result) {
    _lastSpunResult = result;
    final targetIndices = <int>[];
    for (int i = 0; i < slices.length; i++) {
      if (slices[i].symbol == result) targetIndices.add(i);
    }
    if (targetIndices.isEmpty) return;

    final random = Random();
    final targetIndex = targetIndices[random.nextInt(targetIndices.length)];
    final sliceAngle = 2 * pi / slices.length;
    final targetAngle = -(targetIndex * sliceAngle + sliceAngle / 2);
    final fullRotations = 5 + random.nextInt(3);
    final totalAngle = fullRotations * 2 * pi + targetAngle - _currentAngle;

    final startAngle = _currentAngle;
    _lastTickSlice = 0;

    _animation = Tween<double>(begin: 0, end: totalAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Haptic ticks as the wheel crosses each slice boundary
    _animation.addListener(_onSpinTick);

    HapticFeedback.mediumImpact(); // Initial spin kick

    _controller.reset();
    _controller.forward().then((_) {
      if (!mounted) return;
      _animation.removeListener(_onSpinTick);

      // Heavy thud when the wheel stops
      HapticFeedback.heavyImpact();

      // Lock the wheel at the final position:
      // Replace the running animation with a stopped one so
      // _animation.value becomes 0 and only _currentAngle drives the angle.
      setState(() {
        _currentAngle = (startAngle + totalAngle) % (2 * pi);
        _animation = const AlwaysStoppedAnimation(0.0);
      });
      widget.onSpinComplete?.call();
    });
  }

  void _onSpinTick() {
    final totalAngle = (_currentAngle + _animation.value).abs();
    final sliceAngle = 2 * pi / slices.length;
    final currentSlice = (totalAngle / sliceAngle).floor();
    if (currentSlice != _lastTickSlice) {
      _lastTickSlice = currentSlice;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.80;

        return SizedBox(
          width: size + 52,
          height: size + 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow
              Container(
                width: size + 48,
                height: size + 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF6A0DAD).withValues(alpha: 0.25),
                      blurRadius: 50,
                      spreadRadius: 15,
                    ),
                  ],
                ),
              ),

              // Casino light dots ring
              SizedBox(
                width: size + 44,
                height: size + 44,
                child: CustomPaint(
                  painter: _CasinoLightsPainter(
                    dotCount: 24,
                    isSpinning: widget.phase == 'spinning',
                  ),
                ),
              ),

              // Outer gold frame ring
              Container(
                width: size + 26,
                height: size + 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFE066),
                      Color(0xFFDAA520),
                      Color(0xFFB8860B),
                      Color(0xFFDAA520),
                      Color(0xFFFFE066),
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              // Inner dark ring
              Container(
                width: size + 8,
                height: size + 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1A0830),
                ),
              ),

              // Wheel slices
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _currentAngle + _animation.value,
                    child: child,
                  );
                },
                child: ClipOval(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WheelPainter(slices),
                          ),
                        ),
                        // 77 icons
                        for (int i = 0; i < slices.length; i++)
                          if (slices[i].display == '77')
                            Positioned(
                              left: size / 2 + (size / 2 * 0.65) * cos(i * 2 * pi / slices.length - pi / 2 + (2 * pi / slices.length) / 2) - 15,
                              top: size / 2 + (size / 2 * 0.65) * sin(i * 2 * pi / slices.length - pi / 2 + (2 * pi / slices.length) / 2) - 15,
                              child: Transform.rotate(
                                angle: i * 2 * pi / slices.length - pi / 2 + (2 * pi / slices.length) / 2 + pi / 2,
                                child: Image.asset('assets/images/77_icon.png', width: 30, height: 30),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center hub
              Container(
                width: size * 0.18,
                height: size * 0.18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFE066),
                      Color(0xFFDAA520),
                      Color(0xFFB8860B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF1A0830),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: size * 0.08,
                    height: size * 0.08,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2A0E4A),
                    ),
                  ),
                ),
              ),

              // Pointer at top
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: const Size(34, 30),
                  painter: _PointerPainter(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WheelSlice {
  final String symbol;
  final Color color;
  final String display;

  const WheelSlice(this.symbol, this.color, this.display);
}

class _CasinoLightsPainter extends CustomPainter {
  final int dotCount;
  final bool isSpinning;

  _CasinoLightsPainter({required this.dotCount, required this.isSpinning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi * i / dotCount) - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      final isGold = i % 2 == 0;
      final dotColor =
          isGold ? const Color(0xFFFFD700) : const Color(0xFFFFF8DC);

      final paint = Paint()
        ..color = dotColor.withValues(alpha: isSpinning ? 0.95 : 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3.5, paint);

      // Glow halo
      final glowPaint = Paint()
        ..color = dotColor.withValues(alpha: isSpinning ? 0.4 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), 5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CasinoLightsPainter oldDelegate) =>
      oldDelegate.isSpinning != isSpinning;
}

class _WheelPainter extends CustomPainter {
  final List<WheelSlice> slices;

  _WheelPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = 2 * pi / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final startAngle = i * sliceAngle - pi / 2;

      // Slice fill
      final paint = Paint()
        ..color = slices[i].color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      // Radial depth overlay
      final overlayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        overlayPaint,
      );

      // Gold divider line
      final dividerPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        ),
        dividerPaint,
      );

      // Symbol text/emoji
      final textAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      final isSevenSlice = slices[i].display == '77';
      if (!isSevenSlice) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: slices[i].display,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(textAngle + pi / 2);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(3, 0)
      ..lineTo(size.width - 3, 0)
      ..close();

    // Shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Gold gradient body
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE066), Color(0xFFDAA520)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8860B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Red gem at top
    canvas.drawCircle(
      Offset(size.width / 2, 6),
      4.5,
      Paint()..color = const Color(0xFFFF2255),
    );
    // Gem highlight
    canvas.drawCircle(
      Offset(size.width / 2 - 1.2, 4.8),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
