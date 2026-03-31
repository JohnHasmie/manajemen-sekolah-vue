// A circular toggle button used in the attendance editing row to let an admin
// quickly assign a status (Hadir/Sakit/Izin/Alpha) to a student. Selection
// state and tap events are controlled entirely via constructor params/callbacks.
import 'package:flutter/material.dart';

class AttendanceQuickStatusButton extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const AttendanceQuickStatusButton({
    super.key,
    required this.status,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
