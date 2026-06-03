// ClassReportDrillCard — Mockup #13.
//
// Soft navy-tinted card pinned at the bottom of the Tagihan list.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Soft navy-tinted card pinned at the bottom of the Tagihan list. Tap
/// drills into the per-kelas finance report.
class ClassReportDrillCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const ClassReportDrillCard({
    super.key,
    required this.onTap,
    this.title = 'Laporan per kelas',
    this.subtitle = 'Drill ke ClassFinanceReport untuk breakdown lengkap',
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: navy, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: navy.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: navy, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
