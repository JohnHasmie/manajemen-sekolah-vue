// Frame B per-child hero card — the white summary card pinned at the
// top of the per-child rec list. Shows the child's avatar + name +
// "{klass} · {total} rekomendasi" meta, a "{unread} BARU" badge, and a
// wrap of status pills (BELUM DIBACA / PRIORITAS TINGGI / SELESAI).
//
// The owning screen resolves the counts (preferring the summary
// payload, falling back to the live KPI slice) and hands them in, so
// this widget stays purely presentational.
//
// Extracted verbatim from `parent_recommendation_screen.dart` during
// the Phase 2 readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_status_chips.dart';

class ParentRecPerChildHero extends StatelessWidget {
  final String name;
  final String klass;
  final int total;
  final int unread;
  final int highPri;
  final int completed;
  final Color azure;

  const ParentRecPerChildHero({
    super.key,
    required this.name,
    required this.klass,
    required this.total,
    required this.unread,
    required this.highPri,
    required this.completed,
    required this.azure,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: '$klass · '),
                            TextSpan(
                              text: '$total rekomendasi',
                              style: TextStyle(
                                color: azure,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: azure.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: azure.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$unread',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: azure,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BARU',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: azure,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (unread > 0 || highPri > 0 || completed > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (unread > 0)
                    ParentRecStatusPill(
                      label: '$unread BELUM DIBACA',
                      color: azure,
                    ),
                  if (highPri > 0)
                    ParentRecStatusPill(
                      label: '$highPri PRIORITAS TINGGI',
                      color: ColorUtils.warning600,
                    ),
                  if (completed > 0)
                    ParentRecStatusPill(
                      label: '$completed SELESAI',
                      color: ColorUtils.success600,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
