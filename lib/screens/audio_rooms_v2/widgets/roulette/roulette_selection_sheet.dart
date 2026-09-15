import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_setup_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_rules_sheet.dart';

class RouletteSelectionSheet extends StatelessWidget {
  final RouletteController controller;

  const RouletteSelectionSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2235), // Dark bluish background similar to image
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + 20
            : MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
              const Text(
                'Roulette',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.blueAccent, blurRadius: 10),
                  ]
                ),
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const RouletteRulesSheet(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRouletteOption(
                context,
                title: 'Number Roulette',
                options: List.generate(9, (index) => (index + 1).toString()),
                primaryColor: const Color(0xFF42A5F5), // Blue
                secondaryColor: Colors.white,
                textColorPrimary: Colors.white,
                textColorSecondary: Colors.blue,
                onStart: () {
                  controller.startRoulette(List.generate(9, (index) => (index + 1).toString()));
                  Navigator.of(context).pop();
                },
              ),
              Obx(() => _buildRouletteOption(
                context,
                title: 'Custom Roulette',
                options: controller.customOptions.length >= 2
                    ? controller.customOptions.toList()
                    : ['www', 'test', 'hi', 'hello'], // Placeholder preview if not set
                primaryColor: const Color(0xFFF06292), // Pink
                secondaryColor: Colors.white,
                textColorPrimary: Colors.white,
                textColorSecondary: const Color(0xFFF06292),
                onEdit: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => RouletteSetupSheet(controller: controller),
                  );
                },
                onStart: () {
                  if (controller.customOptions.length >= 2) {
                    controller.startRoulette(controller.customOptions.toList());
                    Navigator.of(context).pop();
                  } else {
                    // Go to edit if they haven't setup custom options yet
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => RouletteSetupSheet(controller: controller),
                    );
                  }
                },
              )),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildRouletteOption(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Color primaryColor,
    required Color secondaryColor,
    required Color textColorPrimary,
    required Color textColorSecondary,
    VoidCallback? onEdit,
    required VoidCallback onStart,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primaryColor.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: CustomPaint(
                  size: const Size(140, 140),
                  painter: WheelPainter(
                    options: options,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    textColorPrimary: textColorPrimary,
                    textColorSecondary: textColorSecondary,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Colors.yellow, Colors.orange],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                ),
                child: const Center(
                  child: Text('GO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              Positioned(
                top: -5,
                child: CustomPaint(
                  size: const Size(15, 20),
                  painter: PointerPainter(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 15),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null) ...[
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
            ],
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
