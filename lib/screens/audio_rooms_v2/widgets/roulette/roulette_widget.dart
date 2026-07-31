import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_models.dart';

class RouletteWidget extends StatefulWidget {
  final RouletteController controller;

  const RouletteWidget({super.key, required this.controller});

  @override
  State<RouletteWidget> createState() => _RouletteWidgetState();
}

class _RouletteWidgetState extends State<RouletteWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  double _lastStopAngle = 0;
  String _currentSpinId = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerSpin(RouletteState state) {
    if (state.id != _currentSpinId || !_animationController.isAnimating) {
      _currentSpinId = state.id;
      final int optionsCount = state.options.length;
      if (optionsCount == 0) return;

      final double sliceAngle = 2 * math.pi / optionsCount;
      // Calculate target angle to make the winning slice stop at the top (1.5 * pi)
      final double targetAngle = (optionsCount - state.resultIndex) * sliceAngle - (sliceAngle / 2);
      
      // Spin at least 5 full rotations + the target angle
      final double totalRotation = (math.pi * 2 * 5) + targetAngle;

      _animation = Tween<double>(
        begin: _lastStopAngle,
        end: totalRotation,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCirc,
      ));

      _animationController.forward(from: 0).then((_) {
        _lastStopAngle = totalRotation % (math.pi * 2);
      });
    }
  }

  void _showCloseConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Close Roulette', style: TextStyle(color: Colors.white)),
          content: const Text('Do you want to close the roulette?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.controller.closeRoulette();
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = widget.controller.gameState.value;
      if (!state.isActive) {
        return const SizedBox.shrink();
      }

      if (state.status == RouletteStatus.spinning && state.id != _currentSpinId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerSpin(state);
        });
      }

      return Positioned.fill(
        child: Container(
          color: Colors.black87.withValues(alpha: 0.6),
          child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // 1. The static outer ring PNG
                  Image.asset(
                    'assets/images/roulette_ring.png',
                    width: 320,
                    height: 320,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(), // Fallback if image not yet placed
                  ),
                  // 2. The spinning wheel slices
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animation.value,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: WheelPainter(
                            options: state.options,
                            primaryColor: const Color(0xFFF06292),
                            secondaryColor: Colors.white,
                            textColorPrimary: Colors.white,
                            textColorSecondary: Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
                  // 3. Center GO button
                  GestureDetector(
                    onTap: () {
                      if (widget.controller.isHost && state.status != RouletteStatus.spinning) {
                        widget.controller.startRoulette(state.options);
                      }
                    },
                    child: Image.asset(
                      'assets/images/roulette_go.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback UI if image not yet placed
                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'GO',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                            ),
                            // Fallback pointer
                            Positioned(
                              top: -15,
                              child: CustomPaint(
                                size: const Size(30, 40),
                                painter: PointerPainter(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Pointer is now part of the GO image. No need for separate PointerPainter here unless fallback is used.
                ],
              ),
              const SizedBox(height: 40),
              if (widget.controller.isHost)
                GestureDetector(
                  onTap: _showCloseConfirmDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      );
    });
  }
}

class WheelPainter extends CustomPainter {
  final List<String> options;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;

  WheelPainter({
    required this.options,
    this.primaryColor = const Color(0xFFF06292),
    this.secondaryColor = Colors.white,
    this.textColorPrimary = Colors.white,
    this.textColorSecondary = Colors.black87,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) return;

    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double sweepAngle = 2 * math.pi / options.length;

    for (int i = 0; i < options.length; i++) {
      final paint = Paint()
        ..color = i % 2 == 0 ? primaryColor : secondaryColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle - (math.pi / 2),
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle - (math.pi / 2),
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw Text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweepAngle + (sweepAngle / 2) - (math.pi / 2));
      
      final textSpan = TextSpan(
        text: options[i].length > 10 ? '${options[i].substring(0, 8)}..' : options[i],
        style: TextStyle(
          color: i % 2 == 0 ? textColorPrimary : textColorSecondary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius * 0.45, -textPainter.height / 2),
      );
      canvas.restore();
    }
    
    // Outer border
    final outerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, outerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) {
    return oldDelegate.options != options;
  }
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height) // Bottom tip
      ..lineTo(0, 0) // Top left
      ..lineTo(size.width, 0) // Top right
      ..close();

    canvas.drawPath(path, paint);
    
    final shadowPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
