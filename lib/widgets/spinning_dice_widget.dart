import 'dart:math';
import 'package:flutter/material.dart';

class SpinningDiceWidget extends StatefulWidget {
  final int targetNumber;
  final double size;

  const SpinningDiceWidget({
    super.key,
    required this.targetNumber,
    this.size = 40.0,
  });

  @override
  State<SpinningDiceWidget> createState() => _SpinningDiceWidgetState();
}

class _SpinningDiceWidgetState extends State<SpinningDiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentFace = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Spin duration
    );

    _controller.addListener(() {
      // Rapidly change the dice face while spinning
      if (_controller.value < 0.9) {
        // Only change face occasionally to not flicker too fast
        if (DateTime.now().millisecondsSinceEpoch % 100 < 20) {
          setState(() {
            _currentFace = _random.nextInt(6) + 1;
          });
        }
      } else {
        // At the very end, settle on the target number
        setState(() {
          _currentFace = widget.targetNumber;
        });
      }
    });

    _controller.forward();
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
        // Combine rotation with a slight bouncing scale
        final angle = _controller.value * 4 * pi; // Spin 2 full times
        final scale = 1.0 + sin(_controller.value * pi) * 0.5; // Bounce effect
        
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: _buildDiceFace(_currentFace),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiceFace(int number) {
    // Simple custom painter to draw dice dots
    return CustomPaint(
      painter: _DiceFacePainter(number),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int number;
  
  _DiceFacePainter(this.number);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final double radius = size.width * 0.1;
    
    final center = Offset(size.width / 2, size.height / 2);
    final topLeft = Offset(size.width * 0.25, size.height * 0.25);
    final topRight = Offset(size.width * 0.75, size.height * 0.25);
    final bottomLeft = Offset(size.width * 0.25, size.height * 0.75);
    final bottomRight = Offset(size.width * 0.75, size.height * 0.75);
    final middleLeft = Offset(size.width * 0.25, size.height / 2);
    final middleRight = Offset(size.width * 0.75, size.height / 2);

    void drawDot(Offset offset) {
      canvas.drawCircle(offset, radius, paint);
    }

    switch (number) {
      case 1:
        drawDot(center);
        break;
      case 2:
        drawDot(topLeft);
        drawDot(bottomRight);
        break;
      case 3:
        drawDot(topLeft);
        drawDot(center);
        drawDot(bottomRight);
        break;
      case 4:
        drawDot(topLeft);
        drawDot(topRight);
        drawDot(bottomLeft);
        drawDot(bottomRight);
        break;
      case 5:
        drawDot(topLeft);
        drawDot(topRight);
        drawDot(center);
        drawDot(bottomLeft);
        drawDot(bottomRight);
        break;
      case 6:
        drawDot(topLeft);
        drawDot(middleLeft);
        drawDot(bottomLeft);
        drawDot(topRight);
        drawDot(middleRight);
        drawDot(bottomRight);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StaticDiceWidget extends StatelessWidget {
  final int number;
  final double size;

  const StaticDiceWidget({
    super.key,
    required this.number,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DiceFacePainter(number),
      ),
    );
  }
}

