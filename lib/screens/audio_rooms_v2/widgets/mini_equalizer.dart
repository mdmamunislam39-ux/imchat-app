import 'dart:math';
import 'package:flutter/material.dart';

class MiniEqualizer extends StatefulWidget {
  final Color color;
  final double size;

  const MiniEqualizer({
    super.key,
    this.color = Colors.pinkAccent,
    this.size = 14.0,
  });

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int _barCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
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
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barCount, (index) {
              // Different speeds and phases for random-looking effect
              final speedMultiplier = index == 1 ? 1.5 : 1.0;
              final phase = index * 2.0;
              final value = (sin(_controller.value * pi * 2 * speedMultiplier + phase) + 1) / 2; 
              
              // Map 0..1 to 0.3..1.0 of the total height
              final heightPercent = 0.3 + (value * 0.7);
              
              return Container(
                width: widget.size / _barCount * 0.6,
                height: widget.size * heightPercent,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
