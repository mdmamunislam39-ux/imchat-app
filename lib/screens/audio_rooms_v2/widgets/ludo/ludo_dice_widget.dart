import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';
import 'dart:math';
import 'dart:async';

class LudoDiceWidget extends StatefulWidget {
  final LudoController controller;
  final String currentUserId;

  const LudoDiceWidget({
    super.key,
    required this.controller,
    required this.currentUserId,
  }) ;

  @override
  State<LudoDiceWidget> createState() => _LudoDiceWidgetState();
}

class _LudoDiceWidgetState extends State<LudoDiceWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _displayValue = 1;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (_animController.isAnimating) {
          setState(() {
            _displayValue = Random().nextInt(6) + 1;
          });
        }
      });
      
    // Listen to changes in dice roll state from network
    ever(widget.controller.gameState, (LudoGameState state) {
      if (state.isDiceRolled && !_animController.isAnimating) {
        setState(() {
          _displayValue = state.diceValue;
        });
      }
    });

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = widget.controller.gameState.value;
      
      // Determine my color
      LudoColor? myColor;
      for (var entry in state.players.entries) {
        if (entry.value == widget.currentUserId) {
          myColor = entry.key;
          break;
        }
      }

      final isMyTurn = myColor != null && state.currentTurn == myColor;
      
      // Current player's turn color
      final turnColor = _getColor(state.currentTurn);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? "Your Turn!" : "${state.currentTurn.name}'s turn",
            style: TextStyle(
              color: turnColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              if (isMyTurn && !state.isDiceRolled && !_animController.isAnimating) {
                // Play animation locally then roll
                _animController.forward(from: 0).then((_) {
                  widget.controller.rollDice(widget.currentUserId);
                });
              }
            },
            child: RotationTransition(
              turns: _animController,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: turnColor,
                    width: isMyTurn && !state.isDiceRolled ? 4 : 2,
                  ),
                  boxShadow: [
                    if (isMyTurn && !state.isDiceRolled)
                      BoxShadow(
                        color: turnColor.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                  ],
                ),
                alignment: Alignment.center,
                child: _buildDiceFace(_animController.isAnimating ? _displayValue : state.diceValue, turnColor),
              ),
            ),
          ),
          if (state.winner == null && state.lastTurnStartTime > 0) ...[
            const SizedBox(height: 8),
            Text(
              "${max(0, 30 - ((DateTime.now().millisecondsSinceEpoch - state.lastTurnStartTime) ~/ 1000))}s",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ],
        ],
      );
    });
  }

  Color _getColor(LudoColor color) {
    switch (color) {
      case LudoColor.red: return Colors.red;
      case LudoColor.green: return Colors.green;
      case LudoColor.yellow: return Colors.yellow;
      case LudoColor.blue: return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildDiceFace(int value, Color dotColor) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _DiceFacePainter(value, dotColor),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int value;
  final Color color;

  _DiceFacePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final r = w * 0.1; // Dot radius

    // Define positions in a 3x3 grid layout mapping
    final center = Offset(w / 2, h / 2);
    final topLeft = Offset(w * 0.25, h * 0.25);
    final topRight = Offset(w * 0.75, h * 0.25);
    final bottomLeft = Offset(w * 0.25, h * 0.75);
    final bottomRight = Offset(w * 0.75, h * 0.75);
    final centerLeft = Offset(w * 0.25, h * 0.5);
    final centerRight = Offset(w * 0.75, h * 0.5);

    switch (value) {
      case 1:
        canvas.drawCircle(center, r, paint);
        break;
      case 2:
        canvas.drawCircle(topLeft, r, paint);
        canvas.drawCircle(bottomRight, r, paint);
        break;
      case 3:
        canvas.drawCircle(topLeft, r, paint);
        canvas.drawCircle(center, r, paint);
        canvas.drawCircle(bottomRight, r, paint);
        break;
      case 4:
        canvas.drawCircle(topLeft, r, paint);
        canvas.drawCircle(topRight, r, paint);
        canvas.drawCircle(bottomLeft, r, paint);
        canvas.drawCircle(bottomRight, r, paint);
        break;
      case 5:
        canvas.drawCircle(topLeft, r, paint);
        canvas.drawCircle(topRight, r, paint);
        canvas.drawCircle(center, r, paint);
        canvas.drawCircle(bottomLeft, r, paint);
        canvas.drawCircle(bottomRight, r, paint);
        break;
      case 6:
        canvas.drawCircle(topLeft, r, paint);
        canvas.drawCircle(centerLeft, r, paint);
        canvas.drawCircle(bottomLeft, r, paint);
        canvas.drawCircle(topRight, r, paint);
        canvas.drawCircle(centerRight, r, paint);
        canvas.drawCircle(bottomRight, r, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
