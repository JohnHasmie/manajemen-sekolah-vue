// Shared list-row tile for dashboard "hub" tabs.
//
// One implementation, three role consumers — admin People / Academic,
// teacher Mengajar / Nilai / Lainnya, parent Akademik. Anchored to the
// parent Akademik Hub mockup (`Parent_Phase3_AkademikHub_Mockup_v2.svg`)
// so every role's hub tab carries the same visual identity:
//
//   * 64 px tall card with white fill and slate-200 hairline border
//   * 44 × 44 rounded icon tile, tinted background (10% accent) +
//     full-strength accent foreground
//   * 14 pt bold title, slate-900
//   * 11 pt single-line subtitle, slate-600 (optional)
//   * Right chevron, slate-400
//
// The accent color comes from `DashboardModules.<X>.color` per row, so
// the tile reads as the module's identity (green Nilai, blue Raport,
// amber Kegiatan Kelas, etc.) rather than the role's brand accent.
//
// Usage:
// ```dart
// DashboardListTile(
//   title: 'Mata Pelajaran',
//   subtitle: 'Daftar mapel yang diajarkan',
//   icon: DashboardModules.mataPelajaran.icon,
//   color: DashboardModules.mataPelajaran.color,
//   onTap: _openSubjects,
// )
// ```

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class DashboardListTile extends StatelessWidget {
  /// Title shown at the top — bold slate-900.
  final String title;

  /// Optional subtitle below the title — single line, ellipsis-clipped.
  final String? subtitle;

  /// Outlined Material icon rendered inside the accent-tinted tile.
  final IconData icon;

  /// Accent color for the icon background (10% alpha) and foreground.
  /// Pull from `DashboardModules.<X>.color` to keep cross-role identity.
  final Color color;

  /// Tap handler.
  final VoidCallback onTap;

  const DashboardListTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200, width: 0.75),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
