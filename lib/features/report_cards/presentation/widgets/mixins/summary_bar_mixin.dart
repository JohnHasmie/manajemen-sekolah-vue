import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building the summary statistics bar section.
mixin SummaryBarMixin {
  /// Abstract getter for build context (provided by State).
  BuildContext get context;

  /// Build the summary bar showing Total, Selesai, Draft, Belum.
  Widget buildSummaryBar(int total, int filled, int drafts, int notFilled) {
    final completed = filled - drafts;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: '$total',
            color: ColorUtils.slate600,
          ),
          const SizedBox(width: 6),
          _StatChip(
            label: 'Selesai',
            value: '$completed',
            color: ColorUtils.success600,
          ),
          const SizedBox(width: 6),
          _StatChip(
            label: 'Draft',
            value: '$drafts',
            color: ColorUtils.warning600,
          ),
          const SizedBox(width: 6),
          _StatChip(
            label: 'Belum',
            value: '$notFilled',
            color: ColorUtils.error600,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
