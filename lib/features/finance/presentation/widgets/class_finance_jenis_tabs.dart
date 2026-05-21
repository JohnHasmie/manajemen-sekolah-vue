// Payment-type tab strip for the per-kelas Laporan Keuangan matrix.
//
// Drops the all-jenis × all-bulan grid (which was almost entirely
// empty in practice) in favour of a "one jenis at a time" view: tap
// "SPP" to see only the SPP columns, tap "Uang Pangkal" to swap in
// that jenis's columns. The matrix already supports this — it filters
// by [ClassFinanceTable.selectedPaymentTypeId] — so the only new
// surface is this strip.
//
// Built without any new shared component because the strip needs
// per-tab count badges that the generic [BrandFilterChipStrip]
// doesn't expose. Visually it matches the type-tabs in
// `_design/admin_keuangan_redesign.html` (Frame C1).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

class ClassFinanceJenisTabs extends StatelessWidget {
  /// All payment-type buckets surfaced by [ClassFinanceDataMixin] for
  /// the current class. Empty list collapses the strip.
  final List<MonthGroup> monthGroups;

  /// Currently selected payment-type id. `null` means "Semua jenis"
  /// (matches the matrix's default — every jenis renders side by side).
  final String? selectedPaymentTypeId;

  /// Tap handler — receives the new selection (or `null` for "Semua").
  final ValueChanged<String?> onChanged;

  /// Brand accent (admin navy).
  final Color primaryColor;

  const ClassFinanceJenisTabs({
    super.key,
    required this.monthGroups,
    required this.selectedPaymentTypeId,
    required this.onChanged,
    required this.primaryColor,
  });

  /// Distinct payment-type list with how many months each one spans.
  /// We walk monthGroups once, accumulating per-jenis month counts so
  /// the badge after each label tells the admin "5 bln" / "1 bln" at
  /// a glance.
  Map<String, _JenisStat> _buildStats() {
    final stats = <String, _JenisStat>{};
    for (final m in monthGroups) {
      for (final p in m.paymentTypes) {
        final s = stats[p.id] ??= _JenisStat(name: p.name);
        s.monthCount += 1;
      }
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _buildStats();
    if (stats.isEmpty) return const SizedBox.shrink();

    // "Semua" leading tab lets the admin see the full month/jenis
    // matrix when they want a cross-jenis view; the per-jenis tabs
    // collapse to a clean 5-6 month row. Auto-selection still picks
    // the first jenis on first paint (so the C1 look is the default),
    // but the user can switch to "Semua" any time.
    final entries = stats.entries.toList();
    final totalMonths = stats.values.fold<int>(0, (a, b) => a + b.monthCount);
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: entries.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Tab(
              label: 'Semua',
              badge: totalMonths > 0 ? '$totalMonths bln' : null,
              selected: selectedPaymentTypeId == null,
              primaryColor: primaryColor,
              onTap: () => onChanged(null),
            );
          }
          final entry = entries[i - 1];
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _Tab(
              label: entry.value.name,
              badge: '${entry.value.monthCount} bln',
              selected: selectedPaymentTypeId == entry.key,
              primaryColor: primaryColor,
              onTap: () => onChanged(entry.key),
            ),
          );
        },
      ),
    );
  }
}

class _JenisStat {
  final String name;
  int monthCount = 0;
  _JenisStat({required this.name});
}

class _Tab extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? primaryColor : Colors.white;
    final fg = selected ? Colors.white : ColorUtils.slate700;
    final badgeBg = selected
        ? Colors.white.withValues(alpha: 0.22)
        : ColorUtils.slate100;
    final badgeFg = selected ? Colors.white : ColorUtils.slate700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.transparent : ColorUtils.slate200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
