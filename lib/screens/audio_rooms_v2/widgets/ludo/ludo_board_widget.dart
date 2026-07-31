import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_path.dart';

class LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / 15;
    
    final Paint linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final Paint redPaint = Paint()..color = const Color(0xFFF44336);
    final Paint greenPaint = Paint()..color = const Color(0xFF4CAF50);
    final Paint yellowPaint = Paint()..color = const Color(0xFFFFEB3B);
    final Paint bluePaint = Paint()..color = const Color(0xFF2196F3);
    final Paint whitePaint = Paint()..color = Colors.white;
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 1. Draw 4 Home Bases (6x6 each)
    _drawHome(canvas, 0, 0, cellSize, greenPaint, whitePaint, borderPaint);
    _drawHome(canvas, 9 * cellSize, 0, cellSize, yellowPaint, whitePaint, borderPaint);
    _drawHome(canvas, 0, 9 * cellSize, cellSize, redPaint, whitePaint, borderPaint);
    _drawHome(canvas, 9 * cellSize, 9 * cellSize, cellSize, bluePaint, whitePaint, borderPaint);

    // 2. Draw Paths (Tracks)
    _drawTrack(canvas, 6 * cellSize, 0, cellSize, 3, 6, yellowPaint, linePaint, true, false);
    _drawTrack(canvas, 6 * cellSize, 9 * cellSize, cellSize, 3, 6, redPaint, linePaint, true, true);
    _drawTrack(canvas, 0, 6 * cellSize, cellSize, 6, 3, greenPaint, linePaint, false, false);
    _drawTrack(canvas, 9 * cellSize, 6 * cellSize, cellSize, 6, 3, bluePaint, linePaint, false, true);

    // 3. Center Triangle
    _drawCenter(canvas, size, redPaint, greenPaint, yellowPaint, bluePaint);
  }

  void _drawHome(Canvas canvas, double x, double y, double cellSize, Paint homeColor, Paint innerColor, Paint border) {
    final Rect outerRect = Rect.fromLTWH(x, y, cellSize * 6, cellSize * 6);
    canvas.drawRect(outerRect, homeColor);
    canvas.drawRect(outerRect, border);

    final Rect innerRect = Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 4, cellSize * 4);
    canvas.drawRect(innerRect, innerColor);
    canvas.drawRect(innerRect, border);

    // Tokens will be drawn as widgets, so we only draw the 4 circles as placeholders
    final double radius = cellSize * 0.6;
    final Paint tokenPaint = Paint()..color = homeColor.color.withValues(alpha: 0.3);
    
    canvas.drawCircle(Offset(x + cellSize * 2, y + cellSize * 2), radius, tokenPaint);
    canvas.drawCircle(Offset(x + cellSize * 4, y + cellSize * 2), radius, tokenPaint);
    canvas.drawCircle(Offset(x + cellSize * 2, y + cellSize * 4), radius, tokenPaint);
    canvas.drawCircle(Offset(x + cellSize * 4, y + cellSize * 4), radius, tokenPaint);
  }

  void _drawTrack(Canvas canvas, double startX, double startY, double cellSize, int cols, int rows, Paint primaryPaint, Paint linePaint, bool isVertical, bool isBottomOrRight) {
    final Paint whitePaint = Paint()..color = Colors.white;
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = startX + c * cellSize;
        double y = startY + r * cellSize;
        Rect cellRect = Rect.fromLTWH(x, y, cellSize, cellSize);

        Paint cellColor = whitePaint;
        if (isVertical) {
          if (c == 1 && r > 0 && r < 5) cellColor = primaryPaint;
          else if (!isBottomOrRight && c == 2 && r == 1) cellColor = primaryPaint;
          else if (isBottomOrRight && c == 0 && r == 4) cellColor = primaryPaint;
        } else {
          if (r == 1 && c > 0 && c < 5) cellColor = primaryPaint;
          else if (!isBottomOrRight && r == 0 && c == 1) cellColor = primaryPaint;
          else if (isBottomOrRight && r == 2 && c == 4) cellColor = primaryPaint;
        }

        canvas.drawRect(cellRect, cellColor);
        canvas.drawRect(cellRect, linePaint);
        
        if (cellColor == primaryPaint && (isVertical ? c != 1 : r != 1)) {
           final Paint starPaint = Paint()..color = Colors.black45;
           canvas.drawCircle(Offset(x + cellSize/2, y + cellSize/2), cellSize*0.3, starPaint);
        }
      }
    }
  }

  void _drawCenter(Canvas canvas, Size size, Paint red, Paint green, Paint yellow, Paint blue) {
    final double cellSize = size.width / 15;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    
    final Path topPath = Path()..moveTo(6 * cellSize, 6 * cellSize)..lineTo(9 * cellSize, 6 * cellSize)..lineTo(cx, cy)..close();
    canvas.drawPath(topPath, yellow);

    final Path rightPath = Path()..moveTo(9 * cellSize, 6 * cellSize)..lineTo(9 * cellSize, 9 * cellSize)..lineTo(cx, cy)..close();
    canvas.drawPath(rightPath, blue);

    final Path bottomPath = Path()..moveTo(6 * cellSize, 9 * cellSize)..lineTo(9 * cellSize, 9 * cellSize)..lineTo(cx, cy)..close();
    canvas.drawPath(bottomPath, red);

    final Path leftPath = Path()..moveTo(6 * cellSize, 6 * cellSize)..lineTo(6 * cellSize, 9 * cellSize)..lineTo(cx, cy)..close();
    canvas.drawPath(leftPath, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LudoBoardWidget extends StatelessWidget {
  final LudoController controller;
  final String currentUserId;

  const LudoBoardWidget({
    super.key,
    required this.controller,
    required this.currentUserId,
  }) ;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boardSize = constraints.maxWidth;
          final double cellSize = boardSize / 15;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.brown, width: 8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Base Board
                CustomPaint(
                  size: Size.square(boardSize),
                  painter: LudoBoardPainter(),
                ),

                // Tokens Overlay
                Obx(() {
                  final tokens = controller.gameState.value.tokens;
                  return Stack(
                    children: tokens.map((token) {
                      Offset pos = LudoPath.getPosition(token.color, token.position);
                      
                      // If in base, use specific base positions
                      if (token.position == -1) {
                        pos = LudoPath.basePositions[token.color]![token.index];
                      }

                      // Check if multiple tokens on same spot
                      int sameSpotCount = 0;
                      int mySpotIndex = 0;
                      for (var t in tokens) {
                        if (t.position == token.position && t.position != -1) {
                          if (t.id == token.id) {
                            mySpotIndex = sameSpotCount;
                          }
                          sameSpotCount++;
                        }
                      }

                      double offsetX = 0;
                      double offsetY = 0;
                      if (sameSpotCount > 1 && token.position != -1 && token.position != 57) {
                        // Offset slightly to prevent overlap
                        offsetX = (mySpotIndex % 2 == 0 ? -1 : 1) * (cellSize * 0.15);
                        offsetY = (mySpotIndex > 1 ? 1 : -1) * (cellSize * 0.15);
                      }

                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        left: (pos.dx * cellSize) + (cellSize * 0.1) + offsetX,
                        top: (pos.dy * cellSize) + (cellSize * 0.1) + offsetY,
                        width: cellSize * 0.8,
                        height: cellSize * 0.8,
                        child: GestureDetector(
                          onTap: () {
                            if (controller.gameState.value.currentTurn == token.color &&
                                controller.gameState.value.players[token.color] == currentUserId) {
                              controller.moveToken(currentUserId, token);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getColor(token.color),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 2,
                                  offset: const Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getColor(LudoColor color) {
    switch (color) {
      case LudoColor.red: return const Color(0xFFF44336);
      case LudoColor.green: return const Color(0xFF4CAF50);
      case LudoColor.yellow: return const Color(0xFFFFEB3B);
      case LudoColor.blue: return const Color(0xFF2196F3);
      default: return Colors.grey;
    }
  }
}
