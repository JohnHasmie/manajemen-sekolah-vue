// Small status chips shared across the parent rekomendasi surfaces —
// Frame B of `_design/parent_rekomendasi_redesign.html`.
//
//   • [ParentRecStatusFilterChip] — the azure-pill status filter row
//     (Semua / Belum Dibaca / Aktif / Selesai) above the rec list.
//   • [ParentRecStatusPill] — the tiny tinted label pill used on the
//     per-child hero (BELUM DIBACA / PRIORITAS TINGGI / SELESAI) and
//     on each rec card (priority + subject + completed badges).
//
// Extracted verbatim from `parent_recommendation_screen.dart` during
// the Phase 2 readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRecStatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color azure;
  final VoidCallback onTap;

  const ParentRecStatusFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.azure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? azure : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? azure : ColorUtils.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : ColorUtils.slate600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentRecStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const ParentRecStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Compute the 1–2 character initials shown in the azure avatar
/// circles on the hub cards / rec cards. Single-word names take their
/// first letter; multi-word names take first + last. Kept here so the
/// extracted parent-rec widgets can share one implementation.
String parentRecInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
