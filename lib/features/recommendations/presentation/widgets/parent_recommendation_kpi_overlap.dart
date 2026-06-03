// KPI overlap strip for the parent rekomendasi screen — the 3-cell
// (BELUM DIBACA / AKTIF / SELESAI) white card that overlaps the brand
// header via the screen's `Transform.translate`.
//
// Extracted verbatim from `parent_recommendation_screen.dart` during
// the Phase 2 readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRecKpiOverlap extends StatelessWidget {
  final int unread;
  final int active;
  final int completed;
  final Color azure;

  const ParentRecKpiOverlap({
    super.key,
    required this.unread,
    required this.active,
    required this.completed,
    required this.azure,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _KpiCell(
              value: '$unread',
              label: 'BELUM DIBACA',
              color: azure,
            ),
          ),
          Container(width: 1, height: 28, color: ColorUtils.slate100),
          Expanded(
            child: _KpiCell(
              value: '$active',
              label: 'AKTIF',
              color: ColorUtils.warning600,
            ),
          ),
          Container(width: 1, height: 28, color: ColorUtils.slate100),
          Expanded(
            child: _KpiCell(
              value: '$completed',
              label: 'SELESAI',
              color: ColorUtils.success600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _KpiCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
