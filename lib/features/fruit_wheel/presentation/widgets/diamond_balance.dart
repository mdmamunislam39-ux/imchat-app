import 'package:flutter/material.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class DiamondBalance extends StatefulWidget {
  final int diamonds;

  const DiamondBalance({super.key, required this.diamonds});

  @override
  State<DiamondBalance> createState() => _DiamondBalanceState();
}

class _DiamondBalanceState extends State<DiamondBalance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _animateFrom = 0;
  int _displayedDiamonds = 0;

  @override
  void initState() {
    super.initState();
    _animateFrom = widget.diamonds;
    _displayedDiamonds = widget.diamonds;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _animation.addListener(_onAnimate);
  }

  void _onAnimate() {
    final from = _animateFrom;
    final to = widget.diamonds;
    setState(() {
      _displayedDiamonds = (from + (to - from) * _animation.value).round();
    });
  }

  @override
  void didUpdateWidget(DiamondBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diamonds != widget.diamonds) {
      // Always animate from the currently displayed value to the new target
      _animateFrom = _displayedDiamonds;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_onAnimate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDAA520).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DynamicDiamondIcon(width: 16, height: 16),
          const SizedBox(width: 6),
          Text(
            _formatAmount(_displayedDiamonds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount.abs() % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toString();
  }
}
