import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_models.dart';

class CarromBoardPainter extends CustomPainter {
  final List<CarromPiece> pieces;
  final String activeTurn;
  final double strikerPos; // 0.25 to 0.75
  final bool isSimulating;
  final bool isMyTurn;
  final double aimX;
  final double aimY;
  final double aimPower;
  final Offset? dragStart;
  final Offset? dragCurrent;

  CarromBoardPainter({
    required this.pieces,
    required this.activeTurn,
    required this.strikerPos,
    required this.isSimulating,
    required this.isMyTurn,
    this.aimX = 0.0,
    this.aimY = 0.0,
    this.aimPower = 0.0,
    this.dragStart,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Note: felt, mahogany wood borders, pockets, concentric rings, guidelines, and baselines
    // are rendered directly by assets/images/carrom_board.svg behind the CustomPaint canvas.

    // 6. Draw Aiming Slingshot Vector with Real Aim Filter (If currently dragging)
    if (isMyTurn && !isSimulating && aimPower > 0.01) {
      // Striker starting position on baseline in global coordinates
      Offset strikerCenter = _getStrikerSpawnPos(activeTurn, strikerPos, w, h);

      // Dynamic smooth color: Emerald Green (Slow) -> Warm Gold (Medium) -> Coral Red (High)
      Color aimColor;
      if (aimPower < 0.35) {
        aimColor = const Color(0xFF00E676); // Emerald Green
      } else if (aimPower < 0.70) {
        aimColor = const Color(0xFFFFD700); // Warm Gold
      } else {
        aimColor = const Color(0xFFFF5252); // Coral Red
      }

      // 1. Draw Main Aim Line
      final Paint aimLinePaint = Paint()
        ..color = aimColor
        ..strokeWidth = 2.4 + (aimPower * 1.6)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      double lineLength = w * (0.14 + 0.38 * aimPower);
      Offset aimTarget = strikerCenter + Offset(aimX * lineLength, aimY * lineLength);
      canvas.drawLine(strikerCenter, aimTarget, aimLinePaint);

      // 2. Draw Real Aim Trajectory Dotted Extension
      final Paint dotPaint = Paint()
        ..color = aimColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      double dotGap = w * 0.038;
      for (int d = 1; d <= 4; d++) {
        Offset dotPos = aimTarget + Offset(aimX * dotGap * d, aimY * dotGap * d);
        canvas.drawCircle(dotPos, (2.6 - (d * 0.45)).clamp(1.0, 3.0), dotPaint);
      }

      // 3. Draw Target Crosshair/Pointer Circle
      canvas.drawCircle(aimTarget, w * (0.014 + 0.006 * aimPower), Paint()..color = aimColor.withValues(alpha: 0.9));
      canvas.drawCircle(
        aimTarget,
        w * (0.022 + 0.008 * aimPower),
        Paint()
          ..color = aimColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // 4. Draw Power Indicator Ring around Striker
      final Paint powerRingPaint = Paint()
        ..color = aimColor.withValues(alpha: 0.5)
        ..strokeWidth = 2.0 + (aimPower * 1.8)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(strikerCenter, w * 0.032 + (aimPower * 16), powerRingPaint);
    }

    // 7. Draw Pieces
    for (var piece in pieces) {
      if (piece.isPocketed) continue;

      final double px = piece.x * w;
      final double py = piece.y * h;
      final double pr = piece.radius * w;

      if (piece.color == CarromColor.striker) {
        // Render Striker (Glossy cyan/blue glass disc with gold rims)
        final Paint strikerFelt = Paint()..color = const Color(0xFF00ADB5);
        final Paint strikerRim = Paint()
          ..color = const Color(0xFFD4AF37)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        canvas.drawCircle(Offset(px, py), pr, strikerFelt);
        canvas.drawCircle(Offset(px, py), pr, strikerRim);
        // Gloss highlight
        canvas.drawCircle(
          Offset(px - pr * 0.3, py - pr * 0.3),
          pr * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
        // Center jewel
        canvas.drawCircle(Offset(px, py), pr * 0.3, Paint()..color = const Color(0xFFD4AF37));
      } else if (piece.color == CarromColor.white) {
        // Light wood coin from the vector design (E8A55B / B26428)
        canvas.drawCircle(Offset(px, py), pr, Paint()..color = const Color(0xFFE8A55B));
        canvas.drawCircle(
          Offset(px, py),
          pr,
          Paint()
            ..color = const Color(0xFFB26428)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
        );
        // Inner design rings
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.6,
          Paint()
            ..color = const Color(0xFFB26428).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.3,
          Paint()
            ..color = const Color(0xFFB26428).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      } else if (piece.color == CarromColor.black) {
        // Dark wood/charcoal disk from vector design (444344 / 1B1A1C)
        canvas.drawCircle(Offset(px, py), pr, Paint()..color = const Color(0xFF444344));
        canvas.drawCircle(
          Offset(px, py),
          pr,
          Paint()
            ..color = const Color(0xFF1B1A1C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Inner design rings
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.6,
          Paint()
            ..color = const Color(0xFF1B1A1C).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.3,
          Paint()
            ..color = const Color(0xFF1B1A1C).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      } else if (piece.color == CarromColor.red) {
        // Red Queen from vector design (DF1E2C / 7F1424)
        canvas.drawCircle(Offset(px, py), pr, Paint()..color = const Color(0xFFDF1E2C));
        canvas.drawCircle(
          Offset(px, py),
          pr,
          Paint()
            ..color = const Color(0xFF7F1424)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.6,
          Paint()
            ..color = const Color(0xFF7F1424).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          Offset(px, py),
          pr * 0.3,
          Paint()
            ..color = const Color(0xFF7F1424).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // 8. If striker is not simulating yet, draw it on the active player's baseline
    if (!isSimulating && !pieces.any((p) => p.color == CarromColor.striker)) {
      Offset strikerCenter = _getStrikerSpawnPos(activeTurn, strikerPos, w, h);
      final double pr = w * 0.032; // Striker size

      final Paint strikerFelt = Paint()
        ..color = isMyTurn ? const Color(0xFF00ADB5) : Colors.grey.shade600;
      final Paint strikerRim = Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(strikerCenter, pr, strikerFelt);
      canvas.drawCircle(strikerCenter, pr, strikerRim);
      canvas.drawCircle(
        strikerCenter + Offset(-pr * 0.3, -pr * 0.3),
        pr * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
      canvas.drawCircle(strikerCenter, pr * 0.3, Paint()..color = const Color(0xFFD4AF37));
    }
  }

  Offset _getStrikerSpawnPos(String turn, double val, double w, double h) {
    switch (turn) {
      case 'bottom':
        return Offset(val * w, 0.815 * h);
      case 'top':
        return Offset((1.0 - val) * w, 0.185 * h);
      case 'left':
        return Offset(0.185 * w, val * h);
      case 'right':
        return Offset(0.815 * w, (1.0 - val) * h);
      default:
        return Offset(0.5 * w, 0.815 * h);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CarromBoardWidget extends StatefulWidget {
  final CarromController controller;
  final String currentUserId;

  const CarromBoardWidget({
    super.key,
    required this.controller,
    required this.currentUserId,
  });

  @override
  State<CarromBoardWidget> createState() => _CarromBoardWidgetState();
}

class _CarromBoardWidgetState extends State<CarromBoardWidget> {
  Offset? _dragStart;
  Offset? _dragCurrent;

  String? _findMySeat(Map<String, String?> players) {
    for (var entry in players.entries) {
      if (entry.value == widget.currentUserId) {
        return entry.key;
      }
    }
    return null;
  }

  int _getPerspectiveQuarterTurns(String? mySeat) {
    switch (mySeat) {
      case 'bottom':
        return 0;
      case 'right':
        return 1;
      case 'top':
        return 2;
      case 'left':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double boardSize = constraints.maxWidth;

        return Obx(() {
          final state = widget.controller.gameState.value;
          final isSimulating = widget.controller.isSimulating.value;
          final turnSeat = state.currentTurn;
          final String? turnUserId = state.players[turnSeat];
          final bool isMyTurn = turnUserId == widget.currentUserId;
          final String? mySeat = _findMySeat(state.players);
          final int perspectiveTurns = _getPerspectiveQuarterTurns(mySeat);

          return RotatedBox(
            quarterTurns: perspectiveTurns,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                if (!isMyTurn || isSimulating) return;

                final localPos = details.localPosition;
                final Offset strikerPosScreen = Offset(
                  widget.controller.strikerPosition.value * boardSize,
                  0.815 * boardSize,
                );

                setState(() {
                  _dragStart = strikerPosScreen;
                  _dragCurrent = localPos;
                });
              },
              onPanUpdate: (details) {
                if (!isMyTurn || isSimulating || _dragStart == null) return;

                final localPos = details.localPosition;

                setState(() {
                  _dragCurrent = localPos;
                });

                double dx = _dragCurrent!.dx - _dragStart!.dx;
                double dy = _dragCurrent!.dy - _dragStart!.dy;
                double dist = sqrt(dx * dx + dy * dy);

                double maxDrag = boardSize * 0.42;
                double power = min(dist / maxDrag, 1.0);

                double aimXScreen = 0.0;
                double aimYScreen = 0.0;
                if (dist > 3) {
                  // If dragging finger forward/upward (dy < 0), point forward.
                  // If pulling finger backward/downward (dy > 0), point forward (slingshot mode).
                  if (dy <= 0) {
                    aimXScreen = dx / dist;
                    aimYScreen = dy / dist;
                  } else {
                    aimXScreen = -dx / dist;
                    aimYScreen = -dy / dist;
                  }
                }

                // Transform screen aiming vector to global board coordinates
                double globalAimX = 0.0;
                double globalAimY = 0.0;
                switch (perspectiveTurns) {
                  case 0: // bottom seat
                    globalAimX = aimXScreen;
                    globalAimY = aimYScreen;
                    break;
                  case 2: // top seat (180° rotation)
                    globalAimX = -aimXScreen;
                    globalAimY = -aimYScreen;
                    break;
                  case 3: // left seat (270° CW rotation)
                    globalAimX = -aimYScreen;
                    globalAimY = aimXScreen;
                    break;
                  case 1: // right seat (90° CW rotation)
                    globalAimX = aimYScreen;
                    globalAimY = -aimXScreen;
                    break;
                }

                widget.controller.aimX.value = globalAimX;
                widget.controller.aimY.value = globalAimY;
                widget.controller.aimPower.value = power;
              },
              onPanEnd: (details) {
                if (!isMyTurn || isSimulating || _dragStart == null) return;

                if (widget.controller.aimPower.value > 0.05) {
                  widget.controller.fireShot();
                }

                setState(() {
                  _dragStart = null;
                  _dragCurrent = null;
                });
                widget.controller.aimPower.value = 0.0;
              },
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      SvgPicture.asset(
                        'assets/images/carrom_board.svg',
                        width: boardSize,
                        height: boardSize,
                        fit: BoxFit.fill,
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CarromBoardPainter(
                            pieces: widget.controller.localPieces.toList(),
                            activeTurn: turnSeat,
                            strikerPos: widget.controller.strikerPosition.value,
                            isSimulating: isSimulating,
                            isMyTurn: isMyTurn,
                            aimX: widget.controller.aimX.value,
                            aimY: widget.controller.aimY.value,
                            aimPower: widget.controller.aimPower.value,
                            dragStart: _dragStart,
                            dragCurrent: _dragCurrent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
