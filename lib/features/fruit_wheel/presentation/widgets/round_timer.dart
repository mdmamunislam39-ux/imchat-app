import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoundTimer extends StatefulWidget {
  final int phaseEndTime;
  final String phase;
  final int roundNumber;

  const RoundTimer({
    super.key,
    required this.phaseEndTime,
    required this.phase,
    required this.roundNumber,
  });

  @override
  State<RoundTimer> createState() => _RoundTimerState();
}

class _RoundTimerState extends State<RoundTimer> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(RoundTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phaseEndTime != widget.phaseEndTime) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final remaining =
        widget.phaseEndTime - DateTime.now().millisecondsSinceEpoch;
    final newRemaining = remaining > 0 ? (remaining / 1000).ceil() : 0;

    // Haptic pulse for last 3 seconds of betting
    if (widget.phase == 'betting' &&
        newRemaining != _remainingSeconds &&
        newRemaining <= 3 &&
        newRemaining > 0) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _remainingSeconds = newRemaining;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color get _phaseColor {
    switch (widget.phase) {
      case 'betting':
        return _remainingSeconds <= 5
            ? const Color(0xFFFF4444)
            : const Color(0xFF4CAF50);
      case 'spinning':
        return const Color(0xFFFFD700);
      case 'result':
        return const Color(0xFFFF6B8A);
      case 'cooldown':
        return Colors.white38;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _phaseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _phaseColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Round number with gold accent
          Text(
            '#${widget.roundNumber}',
            style: TextStyle(
              color: const Color(0xFFDAA520).withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 1,
              height: 14,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),


          // Timer countdown (betting phase only)
          if (widget.phase == 'betting') ...[
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _phaseColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_remainingSeconds}s',
                style: TextStyle(
                  color: _phaseColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
