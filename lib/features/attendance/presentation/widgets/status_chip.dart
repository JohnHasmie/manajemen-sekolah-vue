// Animated status chip for attendance summary display.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Animated chip matching schedule filter chip style.
/// Shows label, count, and color indicator for attendance status.
class StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final Color primary;

  const StatusChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: isSelected ? color : ColorUtils.slate300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : ColorUtils.slate500,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : ColorUtils.slate400,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
