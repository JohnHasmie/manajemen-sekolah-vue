// A single stat cell displayed in the 4-column stats row inside the dashboard hero banner.
// Like a Vue sub-component `<HeroStatCell icon value label />` rendered inside the hero card.
// Receives all data as constructor params — pure StatelessWidget, no state or providers needed.

import 'package:flutter/material.dart';

/// Renders one column of the 4-up stat grid inside the hero gradient banner.
///
/// Each cell shows a glass-morphism icon box, a large numeric value, and a
/// small label underneath.  Comparable to a KPI tile in a Laravel Blade
/// admin dashboard, but rendered inline inside a gradient container.
///
/// Example usage:
/// ```dart
/// Expanded(child: HeroStatCell(icon: Icons.people_outline, value: '120', label: 'Students'))
/// ```
class HeroStatCell extends StatelessWidget {
  /// Icon to show in the frosted-glass container.
  final IconData icon;

  /// Numeric value (already formatted as a string, e.g. "120").
  final String value;

  /// Short label below the value, e.g. "Students" / "Siswa".
  final String label;

  const HeroStatCell({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with glass morphism effect — white semi-transparent box on the gradient background
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(height: 6),
        // Big number
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 1),
        // Short label
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
