// Empty state for the admin Kegiatan Kelas hub (Frame E).
//
// Three variants share the same chrome:
//   * Pristine — "Mode pemantauan" pill, monitor-flavored copy. No
//     Add CTA (admin doesn't author activities).
//   * Filter-empty — "Bersihkan filter" outlined button.
//   * Read-only AY — lock disc + "Hanya baca" pill.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class AdminActivityEmptyState extends StatelessWidget {
  const AdminActivityEmptyState({
    super.key,
    required this.isReadOnly,
    required this.hasFilters,
    this.onClearFilters,
  });

  /// True when the admin is browsing a past academic year.
  final bool isReadOnly;

  /// True when at least one chip filter is active. Overrides pristine
  /// even on a fresh year.
  final bool hasFilters;

  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconBg;
    final Color iconFg;
    final String title;
    final String desc;
    final Widget cta;

    if (isReadOnly) {
      icon = Icons.lock_outline_rounded;
      iconBg = ColorUtils.slate100;
      iconFg = ColorUtils.slate600;
      title = kClaActNoActivitiesThisYear.tr;
      desc = kClaActReadOnlyYearDesc.tr;
      cta = _Pill(icon: Icons.lock_outline_rounded, label: kClaActReadOnly.tr);
    } else if (hasFilters) {
      icon = Icons.filter_alt_off_rounded;
      iconBg = const Color(0xFFFEF3C7);
      iconFg = const Color(0xFFB45309);
      title = kClaActNoResults.tr;
      desc = kClaActReduceFilters.tr;
      cta = OutlinedButton.icon(
        onPressed: onClearFilters,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(kClaActClearFilters.tr),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorUtils.brandCobalt,
          side: BorderSide(color: ColorUtils.slate200),
          minimumSize: const Size.fromHeight(40),
        ),
      );
    } else {
      icon = Icons.event_note_rounded;
      iconBg = ColorUtils.brandCobalt.withValues(alpha: 0.08);
      iconFg = ColorUtils.brandCobalt;
      title = kClaActNoActivities.tr;
      desc = kClaActNoActivitiesDesc.tr;
      cta = _Pill(
        icon: Icons.visibility_outlined,
        label: kClaActMonitoringMode.tr,
        bgColor: const Color(0xFFDBEAFE),
        fgColor: const Color(0xFF1D4ED8),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: iconFg),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandDarkBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          cta,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.bgColor,
    this.fgColor,
  });
  final IconData icon;
  final String label;
  final Color? bgColor;
  final Color? fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? ColorUtils.slate100,
        borderRadius: BorderRadius.circular(999),
        border: bgColor == null ? Border.all(color: ColorUtils.slate200) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor ?? ColorUtils.slate600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fgColor ?? ColorUtils.slate700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
