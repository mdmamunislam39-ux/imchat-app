import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Exact Frosted Glass Orb container matching the classic golden screenshot:
/// - Translucent dark-tinted frosted glass interior
/// - Glowing champagne-gold bottom arc rim
/// - Crisp white top highlight rim
/// - Secondary inner crescent reflection ring giving 3D bubble / crystal lens refraction
class GoldenGlassOrbWidget extends StatelessWidget {
  final double size;
  final bool isLocked;
  final Widget? child;

  const GoldenGlassOrbWidget({
    super.key,
    this.size = 52.0,
    this.isLocked = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            key: ValueKey('golden_glass_orb_${size}_$isLocked'),
            size: Size(size, size),
            painter: _GoldenGlassOrbPainter(isLocked: isLocked),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _GoldenGlassOrbPainter extends CustomPainter {
  final bool isLocked;
  _GoldenGlassOrbPainter({required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Dark tinted glass fill (subtle blue-black frost)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.12),
          const Color(0xFF222B48).withValues(alpha: 0.28),
          const Color(0xFF0F1528).withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, fillPaint);

    // 2. Soft golden glow on bottom arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00E8B062),
          Color(0x00E8B062),
          Color(0xB0F5C87E),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, glowPaint);

    // 3. Outer rim with white top highlight and warm golden bottom curve
    final outerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xCCFFFFFF),
          Color(0x55FFFFFF),
          Color(0x90ECC27B),
          Color(0xFFFFD68D),
          Color(0xFFFFAA4E),
        ],
        stops: [0.0, 0.28, 0.65, 0.88, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, outerRimPaint);

    // 4. Inner refraction ring
    final innerRadius = radius - 3.2;
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..shader = const LinearGradient(
        begin: Alignment(-0.6, -0.6),
        end: Alignment(0.6, 0.6),
        colors: [
          Color(0x99FFFFFF),
          Color(0x18FFFFFF),
          Color(0x15FFD68D),
          Color(0x75F7C878),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerRimPaint);
  }

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _GoldenGlassOrbPainter) return true;
    return oldDelegate.isLocked != isLocked;
  }
}

/// Exact Neon Royal Purple & Glowing Golden Glass Orb matching the new screenshot:
/// - Vivid glowing gold/amber neon ring border
/// - Deep royal violet & electric purple crystal interior
/// - Inner magenta/violet neon rim
/// - Top-left bright crescent glare / lens flare
/// - Sparkle star accents
class NeonPurpleGlassOrbWidget extends StatelessWidget {
  final double size;
  final bool isLocked;
  final Widget? child;

  const NeonPurpleGlassOrbWidget({
    super.key,
    this.size = 52.0,
    this.isLocked = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            key: ValueKey('neon_purple_orb_${size}_$isLocked'),
            size: Size(size, size),
            painter: _NeonPurpleGlassOrbPainter(isLocked: isLocked),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _NeonPurpleGlassOrbPainter extends CustomPainter {
  final bool isLocked;
  _NeonPurpleGlassOrbPainter({required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Intense outer magenta / violet neon halo glow
    final outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..shader = const RadialGradient(
        colors: [
          Color(0xCCFF00B8), // hot magenta neon glow
          Color(0x887700FF), // electric purple halo
          Color(0x00000000),
        ],
        stops: [0.65, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 4.0));
    canvas.drawCircle(center, radius, outerGlowPaint);

    // 2. Crystal Glass Fill: Deep Royal Violet / Electric Purple Gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: [
          const Color(0xFF9C27B0).withValues(alpha: 0.95), // bright electric violet center
          const Color(0xFF4A0072).withValues(alpha: 0.92), // deep royal purple mid
          const Color(0xFF1E003A).withValues(alpha: 0.98), // dark cosmic purple edge
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius - 1.0, fillPaint);

    // 3. Inner neon magenta / violet circular ring
    final innerNeonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF4081), // bright pink highlight
          Color(0xFFE040FB), // electric magenta
          Color(0xFF7C4DFF), // deep purple
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 2.8));
    canvas.drawCircle(center, radius - 2.8, innerNeonPaint);

    // 4. Glowing Gold Neon Ring (Main Outer Border)
    final goldNeonRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Color(0xFFFFEA00), // vivid neon yellow
          Color(0xFFFF9100), // glowing orange amber
          Color(0xFFFFD700), // bright gold
          Color(0xFFFF6D00), // deep amber
          Color(0xFFFFEA00), // loop back
        ],
        stops: [0.0, 0.35, 0.65, 0.85, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, goldNeonRingPaint);

    // 5. Secondary thin outer gold halo
    final goldOuterStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7);
    canvas.drawCircle(center, radius + 1.2, goldOuterStroke);

    // 6. Top-left Crescent Glass Glare (Specular Highlight)
    final glarePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xCCFFFFFF), // crisp white specular shine
          Color(0x77FF80AB), // translucent pink
          Color(0x00FF80AB),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4.5),
      math.pi * 1.0, // starts around 9 o'clock
      math.pi * 0.45, // curves around top-left
      false,
      glarePaint,
    );

    // 7. Corner Sparkle Stars (4-point sparkle at top-left and bottom-right)
    _drawSparkle(canvas, Offset(center.dx - radius * 0.65, center.dy - radius * 0.68), 3.0);
    _drawSparkle(canvas, Offset(center.dx + radius * 0.72, center.dy + radius * 0.65), 2.5);
  }

  void _drawSparkle(Canvas canvas, Offset pos, double size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    final glow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawCircle(pos, size * 0.8, glow);
    canvas.drawCircle(pos, size * 0.35, paint);

    // 4-point cross star
    final starPath = Path();
    starPath.moveTo(pos.dx, pos.dy - size);
    starPath.lineTo(pos.dx, pos.dy + size);
    starPath.moveTo(pos.dx - size, pos.dy);
    starPath.lineTo(pos.dx + size, pos.dy);

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(starPath, linePaint);
  }

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _NeonPurpleGlassOrbPainter) return true;
    return oldDelegate.isLocked != isLocked;
  }
}

/// Exact Golden Armchair / Sofa matching the user's screenshots:
/// - Upper backrest cushion with lighter golden-cream fill
/// - Lower plump armrests, seat cushion & small legs with warm golden-amber gradient
/// - When [isNeonPurple] is true: adds intense magenta/purple backlight neon glow
class GoldenSofaIcon extends StatelessWidget {
  final double width;
  final double height;
  final bool isNeonPurple;

  const GoldenSofaIcon({
    super.key,
    this.width = 28.0,
    this.height = 25.0,
    this.isNeonPurple = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        key: ValueKey('golden_sofa_${width}_${height}_$isNeonPurple'),
        size: Size(width, height),
        painter: _GoldenSofaPainter(isNeonPurple: isNeonPurple),
      ),
    );
  }
}

class _GoldenSofaPainter extends CustomPainter {
  final bool isNeonPurple;
  const _GoldenSofaPainter({this.isNeonPurple = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sx = w / 28.0;
    final sy = h / 25.0;

    canvas.save();
    canvas.scale(sx, sy);

    // Neon backlight glow (magenta / purple halo around the golden sofa)
    if (isNeonPurple) {
      final neonGlowPaint = Paint()
        ..color = const Color(0xFFFF00D4).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      // Draw combined glow shape
      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.5, 3.0, 25.0, 20.0),
        const Radius.circular(8.0),
      );
      canvas.drawRRect(glowRect, neonGlowPaint);
    } else {
      final shadowPaint = Paint()
        ..color = const Color(0x60F4BA5A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 3.5, 23.0, 19.0),
        const Radius.circular(7.0),
      );
      canvas.drawRRect(glowRect, shadowPaint);
    }

    // 1. Draw Upper Backrest Cushion
    final backrestPath = Path();
    backrestPath.moveTo(6.5, 9.0);
    backrestPath.cubicTo(6.5, 4.0, 10.0, 2.0, 14.0, 2.0);
    backrestPath.cubicTo(18.0, 2.0, 21.5, 4.0, 21.5, 9.0);
    backrestPath.cubicTo(21.5, 11.0, 18.5, 11.5, 14.0, 11.5);
    backrestPath.cubicTo(9.5, 11.5, 6.5, 11.0, 6.5, 9.0);
    backrestPath.close();

    final backrestPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNeonPurple
            ? const [
                Color(0xFFFFFF88), // neon bright lemon-gold top
                Color(0xFFFFD700), // rich golden yellow
              ]
            : const [
                Color(0xFFFFF9EA),
                Color(0xFFFDE4B0),
              ],
      ).createShader(const Rect.fromLTWH(6.5, 2.0, 15.0, 9.5));
    canvas.drawPath(backrestPath, backrestPaint);

    // 2. Draw Lower Sofa (Plump Armrests + Seat Cushion + Legs)
    final bodyPath = Path();
    // Left leg
    bodyPath.moveTo(6.0, 21.0);
    bodyPath.lineTo(6.0, 23.5);
    bodyPath.arcToPoint(const Offset(8.0, 23.5), radius: const Radius.circular(1.0));
    bodyPath.lineTo(8.0, 21.0);
    // Bottom rail
    bodyPath.lineTo(20.0, 21.0);
    // Right leg
    bodyPath.lineTo(20.0, 23.5);
    bodyPath.arcToPoint(const Offset(22.0, 23.5), radius: const Radius.circular(1.0));
    bodyPath.lineTo(22.0, 21.0);
    // Right armrest
    bodyPath.cubicTo(25.5, 21.0, 26.5, 18.0, 26.5, 15.0);
    bodyPath.cubicTo(26.5, 10.5, 23.5, 10.0, 21.5, 12.0);
    // Seat cushion
    bodyPath.cubicTo(18.5, 13.5, 14.0, 13.8, 14.0, 13.8);
    bodyPath.cubicTo(14.0, 13.8, 9.5, 13.5, 6.5, 12.0);
    // Left armrest
    bodyPath.cubicTo(4.5, 10.0, 1.5, 10.5, 1.5, 15.0);
    bodyPath.cubicTo(1.5, 18.0, 2.5, 21.0, 6.0, 21.0);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNeonPurple
            ? const [
                Color(0xFFFFEA00), // intense neon gold top
                Color(0xFFFF9100), // rich glowing orange amber bottom
              ]
            : const [
                Color(0xFFFFF0CA),
                Color(0xFFFDC96F),
                Color(0xFFF4B344),
              ],
        stops: isNeonPurple ? const [0.0, 1.0] : const [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(1.5, 10.0, 25.0, 13.5));
    canvas.drawPath(bodyPath, bodyPaint);

    // Seam highlight between backrest and cushion
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = isNeonPurple ? const Color(0x55600030) : const Color(0x356A420A);
    final seamPath = Path();
    seamPath.moveTo(7.5, 12.2);
    seamPath.cubicTo(10.5, 13.4, 17.5, 13.4, 20.5, 12.2);
    canvas.drawPath(seamPath, seamPaint);

    canvas.restore();
  }

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _GoldenSofaPainter) return true;
    return oldDelegate.isNeonPurple != isNeonPurple;
  }
}

/// Exact Golden Padlock with Keyhole matching the user's screenshots:
/// - Rounded arched shackle
/// - Plump rounded rectangular padlock body
/// - Keyhole in center
/// - When [isNeonPurple] is true: intense magenta/purple backlight neon glow
class GoldenLockIcon extends StatelessWidget {
  final double width;
  final double height;
  final bool isNeonPurple;

  const GoldenLockIcon({
    super.key,
    this.width = 24.0,
    this.height = 27.0,
    this.isNeonPurple = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        key: ValueKey('golden_lock_${width}_${height}_$isNeonPurple'),
        size: Size(width, height),
        painter: _GoldenLockPainter(isNeonPurple: isNeonPurple),
      ),
    );
  }
}

class _GoldenLockPainter extends CustomPainter {
  final bool isNeonPurple;
  const _GoldenLockPainter({this.isNeonPurple = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sx = w / 24.0;
    final sy = h / 27.0;

    canvas.save();
    canvas.scale(sx, sy);

    if (isNeonPurple) {
      final neonGlowPaint = Paint()
        ..color = const Color(0xFFFF00D4).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.0, 1.5, 20.0, 24.0),
        const Radius.circular(8.0),
      );
      canvas.drawRRect(glowRect, neonGlowPaint);
    } else {
      final shadowPaint = Paint()
        ..color = const Color(0x60F4BA5A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.0, 1.5, 20.0, 24.0),
        const Radius.circular(8.0),
      );
      canvas.drawRRect(glowRect, shadowPaint);
    }

    // 1. Shackle (top loop)
    final shacklePath = Path();
    shacklePath.moveTo(6.0, 12.0);
    shacklePath.lineTo(6.0, 7.5);
    shacklePath.cubicTo(6.0, 2.5, 8.5, 1.5, 12.0, 1.5);
    shacklePath.cubicTo(15.5, 1.5, 18.0, 2.5, 18.0, 7.5);
    shacklePath.lineTo(18.0, 12.0);
    shacklePath.lineTo(14.5, 12.0);
    shacklePath.lineTo(14.5, 7.5);
    shacklePath.cubicTo(14.5, 4.8, 13.5, 4.5, 12.0, 4.5);
    shacklePath.cubicTo(10.5, 4.5, 9.5, 4.8, 9.5, 7.5);
    shacklePath.lineTo(9.5, 12.0);
    shacklePath.close();

    final shacklePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNeonPurple
            ? const [
                Color(0xFFFFFF88),
                Color(0xFFFFD700),
              ]
            : const [
                Color(0xFFFFF9EC),
                Color(0xFFFDE1A3),
              ],
      ).createShader(const Rect.fromLTWH(6.0, 1.5, 12.0, 10.5));
    canvas.drawPath(shacklePath, shacklePaint);

    // 2. Lock Body (plump rounded rectangle)
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.5, 10.5, 19.0, 14.5),
      const Radius.circular(5.0),
    );

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNeonPurple
            ? const [
                Color(0xFFFFEA00),
                Color(0xFFFF9100),
              ]
            : const [
                Color(0xFFFFF7DC),
                Color(0xFFFDCB72),
                Color(0xFFF4B344),
              ],
        stops: isNeonPurple ? const [0.0, 1.0] : const [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(2.5, 10.5, 19.0, 14.5));
    canvas.drawRRect(bodyRect, bodyPaint);

    // 3. Center Keyhole (circle + small slot cutout)
    final keyholePaint = Paint()
      ..color = isNeonPurple ? const Color(0xFF220042) : const Color(0xFF1B233D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(12.0, 16.5), 2.2, keyholePaint);

    final slotPath = Path();
    slotPath.moveTo(11.0, 17.0);
    slotPath.lineTo(10.6, 20.2);
    slotPath.lineTo(13.4, 20.2);
    slotPath.lineTo(13.0, 17.0);
    slotPath.close();
    canvas.drawPath(slotPath, keyholePaint);

    canvas.restore();
  }

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _GoldenLockPainter) return true;
    return oldDelegate.isNeonPurple != isNeonPurple;
  }
}

/// Exact Golden Home icon for Seat 1 (Host / Owner):
/// - Cute rounded roof & house shape
/// - Rounded doorway with deep crystal glass cutout
/// - When [isNeonPurple] is true: intense magenta/purple backlight neon glow
class GoldenHomeIcon extends StatelessWidget {
  final double width;
  final double height;
  final bool isNeonPurple;

  const GoldenHomeIcon({
    super.key,
    this.width = 26.0,
    this.height = 26.0,
    this.isNeonPurple = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        key: ValueKey('golden_home_${width}_${height}_$isNeonPurple'),
        size: Size(width, height),
        painter: _GoldenHomePainter(isNeonPurple: isNeonPurple),
      ),
    );
  }
}

class _GoldenHomePainter extends CustomPainter {
  final bool isNeonPurple;
  const _GoldenHomePainter({this.isNeonPurple = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sx = w / 26.0;
    final sy = h / 26.0;

    canvas.save();
    canvas.scale(sx, sy);

    if (isNeonPurple) {
      final neonGlowPaint = Paint()
        ..color = const Color(0xFFFF00D4).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.0, 2.0, 22.0, 23.0),
        const Radius.circular(8.0),
      );
      canvas.drawRRect(glowRect, neonGlowPaint);
    } else {
      final shadowPaint = Paint()
        ..color = const Color(0x60F4BA5A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      final glowRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.0, 2.0, 22.0, 23.0),
        const Radius.circular(8.0),
      );
      canvas.drawRRect(glowRect, shadowPaint);
    }

    // House outline
    final housePath = Path();
    housePath.moveTo(13.0, 1.8);
    housePath.cubicTo(13.8, 1.8, 14.5, 2.4, 15.0, 3.0);
    housePath.lineTo(23.5, 10.5);
    housePath.cubicTo(24.5, 11.5, 24.2, 12.5, 23.0, 12.5);
    housePath.lineTo(21.2, 12.5);
    housePath.lineTo(21.2, 22.0);
    housePath.arcToPoint(const Offset(18.5, 24.5), radius: const Radius.circular(2.5));
    housePath.lineTo(7.5, 24.5);
    housePath.arcToPoint(const Offset(4.8, 22.0), radius: const Radius.circular(2.5));
    housePath.lineTo(4.8, 12.5);
    housePath.lineTo(3.0, 12.5);
    housePath.cubicTo(1.8, 12.5, 1.5, 11.5, 2.5, 10.5);
    housePath.lineTo(11.0, 3.0);
    housePath.cubicTo(11.5, 2.4, 12.2, 1.8, 13.0, 1.8);
    housePath.close();

    final housePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNeonPurple
            ? const [
                Color(0xFFFFFF88),
                Color(0xFFFF9100),
              ]
            : const [
                Color(0xFFFFF8DE),
                Color(0xFFFDCB72),
                Color(0xFFF4B344),
              ],
        stops: isNeonPurple ? const [0.0, 1.0] : const [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(2.0, 1.8, 22.0, 22.7));
    canvas.drawPath(housePath, housePaint);

    // Center Doorway cutout
    final doorRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(9.5, 14.5, 7.0, 10.0),
      topLeft: const Radius.circular(3.5),
      topRight: const Radius.circular(3.5),
    );
    final doorPaint = Paint()..color = isNeonPurple ? const Color(0xFF220042) : const Color(0xFF1B233D);
    canvas.drawRRect(doorRect, doorPaint);

    canvas.restore();
  }

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _GoldenHomePainter) return true;
    return oldDelegate.isNeonPurple != isNeonPurple;
  }
}
