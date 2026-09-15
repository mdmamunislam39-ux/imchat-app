import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/gift_combo_controller.dart';

/// Floating circular Combo Button widget displayed at the bottom right corner
class GiftComboButton extends StatefulWidget {
  const GiftComboButton({super.key});

  @override
  State<GiftComboButton> createState() => _GiftComboButtonState();
}

class _GiftComboButtonState extends State<GiftComboButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.82), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.82, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTap() {
    _animController.forward(from: 0.0);
    GiftComboController.instance.sendComboHit();
  }

  @override
  Widget build(BuildContext context) {
    final controller = GiftComboController.instance;

    return Obx(() {
      if (!controller.isComboButtonVisible.value) {
        return const SizedBox.shrink();
      }

      final activeGift = controller.activeGift.value;
      final comboCount = controller.comboCount.value;

      return AnimatedScale(
        scale: controller.isComboButtonVisible.value ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.elasticOut,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: _onTap,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Countdown timer ring (isolated Obx so only progress updates rebuild this widget)
                  Obx(() => SizedBox(
                    width: 74,
                    height: 74,
                    child: CircularProgressIndicator(
                      value: controller.comboProgress.value,
                      strokeWidth: 3.5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                    ),
                  )),

                  // Outer glowing circle
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00C6FF),
                          Color(0xFF0072FF),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C6FF).withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Gift image at bottom-left corner inside button
                        if (activeGift?.pngUrl != null && activeGift!.pngUrl!.isNotEmpty)
                          Positioned(
                            left: 4,
                            bottom: 6,
                            child: CachedNetworkImage(
                              imageUrl: activeGift.pngUrl!,
                              width: 26,
                              height: 26,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.card_giftcard,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          )
                        else
                          const Positioned(
                            left: 4,
                            bottom: 6,
                            child: Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                        // Text content: "Combo" & "Long press"
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Combo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Long press',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Top-Right Combo multiplier badge (x1, x2, x10...)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0072FF), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'x$comboCount',
                        style: const TextStyle(
                          color: Color(0xFF0072FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
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
  }
}
