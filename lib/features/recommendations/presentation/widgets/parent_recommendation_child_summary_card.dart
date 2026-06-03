// Frame A child summary card for the parent rekomendasi hub —
// one row per child showing a 3-stat grid (TOTAL / AKTIF / SELESAI),
// a gradient progress bar, and the dual Riwayat / Lihat Rekomendasi
// CTA. Renders an azure left-rail + "n BARU" badge when the child has
// unread recommendations.
//
// Extracted verbatim from `parent_recommendation_screen.dart` during
// the Phase 2 readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_status_chips.dart';

class ParentRecChildSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color azure;
  final VoidCallback onTap;

  const ParentRecChildSummaryCard({
    super.key,
    required this.data,
    required this.azure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['student_name']?.toString() ?? 'Siswa';
    final klass = data['class_name']?.toString() ?? '-';
    final total = (data['total_count'] as num?)?.toInt() ?? 0;
    final unread = (data['unread_count'] as num?)?.toInt() ?? 0;
    final completed = (data['completed_count'] as num?)?.toInt() ?? 0;
    final active = (total - completed).clamp(0, total);
    final pct = total == 0 ? 0.0 : completed / total;
    final isUnread = unread > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Stack(
          children: [
            if (isUnread)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: azure,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: azure.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          parentRecInitials(name),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: azure,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              klass,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: azure,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: azure.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '$unread BARU',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '$total',
                          label: 'TOTAL',
                          color: azure,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '$active',
                          label: 'AKTIF',
                          color: ColorUtils.warning600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '$completed',
                          label: 'SELESAI',
                          color: ColorUtils.success600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: ColorUtils.slate100,
                            valueColor: AlwaysStoppedAnimation<Color>(azure),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: azure,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CardButton(
                          icon: Icons.history_rounded,
                          label: 'Riwayat',
                          color: azure,
                          filled: false,
                          onTap: onTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _CardButton(
                          icon: Icons.chevron_right_rounded,
                          label: 'Lihat Rekomendasi',
                          color: azure,
                          filled: true,
                          onTap: onTap,
                          iconLast: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final bool iconLast;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
    this.iconLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.20)),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconLast) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (iconLast) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
