import 'package:flutter/material.dart';

import '../../data/models/round_history_model.dart';

/// Compact vertical history sidebar with circular icons.
class RoundHistory extends StatelessWidget {
  final List<RoundHistoryModel> history;

  const RoundHistory({super.key, required this.history});

  static const Map<String, String> _symbolEmoji = {
    'watermelon': '🍉',
    'plum': '🍇',
    'sevens': '7️⃣7️⃣',
  };

  static const Map<String, Color> _symbolColor = {
    'watermelon': Color(0xFFE8345A),
    'plum': Color(0xFF7B2D8E),
    'sevens': Color(0xFFDAA520),
  };

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: history.take(8).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final color = _symbolColor[item.result] ?? Colors.grey;
          final isNewest = index == 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Container(
              width: isNewest ? 34 : 30,
              height: isNewest ? 34 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: isNewest ? 0.4 : 0.25),
                border: Border.all(
                  color: color.withValues(alpha: isNewest ? 0.8 : 0.4),
                  width: isNewest ? 2 : 1,
                ),
                boxShadow: isNewest
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: item.result == 'sevens'
                   ? Image.asset('assets/images/77_icon.webp', width: isNewest ? 20 : 16)
                   : Text(
                  _symbolEmoji[item.result] ?? '?',
                  style: TextStyle(fontSize: isNewest ? 16 : 14),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
