import 'package:flutter/material.dart';

/// Poker-chip style denomination selector.
class ChipSelector extends StatelessWidget {
  final int selectedAmount;
  final ValueChanged<int> onSelected;

  const ChipSelector({
    super.key,
    required this.selectedAmount,
    required this.onSelected,
  });

  static const List<int> chipAmounts = [500, 1000, 10000, 100000];

  static const List<List<Color>> _chipGradients = [
    [Color(0xFF4CAF50), Color(0xFF2E7D32)], // 500 — green
    [Color(0xFF2196F3), Color(0xFF1565C0)], // 1K — blue
    [Color(0xFFFF9800), Color(0xFFE65100)], // 10K — orange
    [Color(0xFFE91E63), Color(0xFFAD1457)], // 100K — pink
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chipAmounts.length, (i) {
        final amount = chipAmounts[i];
        final isSelected = amount == selectedAmount;
        final colors = _chipGradients[i];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onSelected(amount),
            child: AnimatedScale(
              scale: isSelected ? 1.15 : 0.9,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSelected
                        ? colors
                        : [
                            colors[0].withValues(alpha: 0.3),
                            colors[1].withValues(alpha: 0.3),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.6),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _formatChip(amount),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  String _formatChip(int amount) {
    if (amount >= 1000) return '${amount ~/ 1000}K';
    return amount.toString();
  }
}
