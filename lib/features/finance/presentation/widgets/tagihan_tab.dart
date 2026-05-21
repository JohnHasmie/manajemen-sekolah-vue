// Tagihan tab body — Tingkat → Kelas grouped layout (A1 mockup).
//
// Matches `_design/admin_keuangan_redesign.html` Frame A1 exactly:
//   • Tingkat header row (badge + name + meta + outstanding pill)
//   • Per-kelas rows (icon + class name + siswa/belum pill + total +
//     dominant jenis hint + chevron)
//   • One row per CLASS, not per (jenis × class × year) bucket — so
//     SPP 8A and Kegiatan 8A collapse into a single "8A" row whose
//     numbers aggregate every bill the class has open.
//
// Tap a class row → push [ClassFinanceReportScreen] directly. The
// jenis × bulan breakdown is what the per-kelas matrix is for; the
// hub list intentionally surfaces the *class* as the navigation
// primitive because that's the level admins reason about ("which
// classes are behind on payments this month").

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/features/finance/domain/models/bill_group.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';

class TagihanTab extends StatelessWidget {
  /// Aggregated bucket list from `GET /finance/bill-groups`. We
  /// re-aggregate by class on this side so each row in the UI is
  /// "one class, summed over all its bills".
  final List<BillGroup> billGroups;

  /// Active status filter key — `'all'` / `'unpaid'` / `'overdue'`.
  /// Sourced from the consolidated [TagihanFilterResult.status].
  final String activeFilterKey;

  /// Optional tap handlers — kept for back-compat with the older flow
  /// that pushed AdminBillGroupDetailScreen. The A1 redesign skips
  /// that intermediate screen, so these are unused in the new path.
  // ignore: unused_element_parameter
  final void Function(Map<String, dynamic> bill)? onTagih;
  // ignore: unused_element_parameter
  final void Function(Map<String, dynamic> bill)? onTap;

  /// Pull-to-refresh callback.
  final Future<void> Function() onRefresh;

  /// Active academic year id — forwarded to ClassFinanceReportScreen
  /// so its per-student fetch scopes to the same AY the row is for.
  final String? academicYearId;

  const TagihanTab({
    super.key,
    required this.billGroups,
    required this.activeFilterKey,
    required this.onRefresh,
    this.academicYearId,
    this.onTagih,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final classRows = _aggregateByClass(billGroups);
    final filtered = _applyStatusFilter(classRows);
    final sections = _segmentByTingkat(filtered);

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      role: 'admin',
      child: filtered.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [_EmptyTagihan(activeKey: activeFilterKey)],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sections.length,
              itemBuilder: (context, idx) {
                final section = sections[idx];
                return _TingkatSection(
                  level: section.level,
                  totalClassCount: section.items.length,
                  totalSiswa: section.items.fold<int>(
                    0,
                    (acc, c) => acc + c.totalSiswa,
                  ),
                  outstanding: section.items.fold<double>(
                    0,
                    (acc, c) => acc + (c.totalAmount - c.paidAmount),
                  ),
                  children: [
                    for (final c in section.items)
                      _ClassRow(
                        summary: c,
                        onTap: () => AppNavigator.push(
                          context,
                          ClassFinanceReportScreen(
                            classId: c.classId,
                            className: c.className,
                            academicYearId: c.academicYearId ?? academicYearId,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  // ── Aggregation ──────────────────────────────────────────────────

  /// Collapse the (jenis × kelas × tahun) bucket list into one
  /// [_ClassSummary] per class. Bills for the same class but
  /// different jenis sum their counts + amounts together; we also
  /// remember the most-common jenis as a hint for the row caption.
  List<_ClassSummary> _aggregateByClass(List<BillGroup> groups) {
    final byClass = <String, _ClassSummary>{};
    for (final g in groups) {
      final id = g.classId;
      final s = byClass.putIfAbsent(
        id,
        () => _ClassSummary(
          classId: id,
          className: g.className,
          gradeLevel: g.gradeLevel,
          academicYearId: g.academicYearId,
          yearLabel: g.yearLabel,
        ),
      );
      s.totalSiswa = s.totalSiswa > g.totalCount ? s.totalSiswa : g.totalCount;
      s.paidCount += g.paidCount;
      s.unpaidCount += g.unpaidCount;
      s.overdueCount += g.overdueCount;
      s.totalAmount += g.totalAmount;
      s.paidAmount += g.paidAmount;
      s.jenisCounts[g.paymentTypeName] =
          (s.jenisCounts[g.paymentTypeName] ?? 0) + 1;
    }
    return byClass.values.toList();
  }

  /// Status sub-filter — applied to the *aggregated* class summary so
  /// "Belum lunas" means at least one outstanding bill across any
  /// jenis (matches the count badge admins see on the parent role).
  List<_ClassSummary> _applyStatusFilter(List<_ClassSummary> rows) {
    switch (activeFilterKey) {
      case 'unpaid':
        return rows.where((r) => r.unpaidCount + r.overdueCount > 0).toList();
      case 'overdue':
        return rows.where((r) => r.overdueCount > 0).toList();
      default:
        return rows;
    }
  }

  /// Split into Tingkat segments using the grade_level surfaced by
  /// the backend on each bill-group row. Null/empty → "Lainnya"
  /// bucket pinned at the bottom.
  List<_TingkatBundle> _segmentByTingkat(List<_ClassSummary> rows) {
    final byLevel = <String, List<_ClassSummary>>{};
    for (final r in rows) {
      final key = (r.gradeLevel?.trim().isNotEmpty ?? false)
          ? r.gradeLevel!.trim()
          : '_other';
      byLevel.putIfAbsent(key, () => []).add(r);
    }
    // Sort classes inside each level by name.
    for (final list in byLevel.values) {
      list.sort((a, b) => a.className.compareTo(b.className));
    }
    final levels = byLevel.keys.toList();
    levels.sort((a, b) {
      if (a == '_other') return 1;
      if (b == '_other') return -1;
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.compareTo(b);
    });
    return [
      for (final l in levels) _TingkatBundle(level: l, items: byLevel[l]!),
    ];
  }
}

// ── Models ────────────────────────────────────────────────────────

class _ClassSummary {
  final String classId;
  final String className;
  final String? gradeLevel;
  final String? academicYearId;
  final String? yearLabel;
  int totalSiswa = 0;
  int paidCount = 0;
  int unpaidCount = 0;
  int overdueCount = 0;
  double totalAmount = 0;
  double paidAmount = 0;
  final Map<String, int> jenisCounts = {};

  _ClassSummary({
    required this.classId,
    required this.className,
    required this.gradeLevel,
    required this.academicYearId,
    required this.yearLabel,
  });

  /// Name of the jenis with the most rows in this class, used for the
  /// per-row caption. Falls back to "Tagihan" when the class is empty.
  String get dominantJenisName {
    if (jenisCounts.isEmpty) return 'Tagihan';
    var top = jenisCounts.entries.first;
    for (final e in jenisCounts.entries) {
      if (e.value > top.value) top = e;
    }
    return top.key;
  }

  int get distinctJenisCount => jenisCounts.length;
  int get outstandingCount => unpaidCount + overdueCount;
}

class _TingkatBundle {
  final String level;
  final List<_ClassSummary> items;
  const _TingkatBundle({required this.level, required this.items});
}

// ── Tingkat section header + body ─────────────────────────────────

class _TingkatSection extends StatelessWidget {
  final String level;
  final int totalClassCount;
  final int totalSiswa;
  final double outstanding;
  final List<Widget> children;

  const _TingkatSection({
    required this.level,
    required this.totalClassCount,
    required this.totalSiswa,
    required this.outstanding,
    required this.children,
  });

  String _shortRp(double v) {
    if (v <= 0) return 'Rp 0';
    if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)}M';
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(0)}jt';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final lvlText = level == '_other' ? 'Lainnya' : 'Tingkat $level';
    final hasOutstanding = outstanding > 0;
    final pillBg = hasOutstanding
        ? ColorUtils.error600.withValues(alpha: 0.10)
        : ColorUtils.success600.withValues(alpha: 0.10);
    final pillFg = hasOutstanding ? ColorUtils.error600 : ColorUtils.success600;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tingkat header — badge + name/meta + outstanding pill.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorUtils.corporateBlue600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    level == '_other' ? '–' : level,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.corporateBlue600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lvlText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$totalClassCount kelas · $totalSiswa siswa',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasOutstanding ? '${_shortRp(outstanding)} belum' : 'Lunas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: pillFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Class rows live inside a single bordered card so the group
          // reads as one unit; rows are visually separated by hairlines.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ── Class row ─────────────────────────────────────────────────────

class _ClassRow extends StatelessWidget {
  final _ClassSummary summary;
  final VoidCallback onTap;

  const _ClassRow({required this.summary, required this.onTap});

  String _shortRp(double v) {
    if (v <= 0) return 'Rp 0';
    if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)}M';
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(0)}jt';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final allLunas = summary.outstandingCount == 0 && summary.paidCount > 0;
    final pillBg = allLunas
        ? ColorUtils.success600.withValues(alpha: 0.10)
        : ColorUtils.error600.withValues(alpha: 0.10);
    final pillFg = allLunas ? ColorUtils.success600 : ColorUtils.error600;
    final pillText = allLunas
        ? '${summary.paidCount} lunas'
        : '${summary.outstandingCount} belum';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: ColorUtils.slate100)),
          ),
          child: Row(
            children: [
              // Class icon — neutral slate tile so the row reads as a
              // primary navigation, not a status alert (the pill +
              // amount carry status).
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.class_outlined,
                  size: 16,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.className,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${summary.totalSiswa} siswa',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pillText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: pillFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _shortRp(summary.totalAmount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    summary.distinctJenisCount > 1
                        ? '${summary.distinctJenisCount} jenis'
                        : summary.dominantJenisName,
                    style: TextStyle(
                      fontSize: 10,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────

class _EmptyTagihan extends StatelessWidget {
  final String activeKey;
  const _EmptyTagihan({required this.activeKey});

  @override
  Widget build(BuildContext context) {
    final copy = switch (activeKey) {
      'overdue' => 'Tidak ada tagihan yang jatuh tempo. Semua aman.',
      'unpaid' => 'Tidak ada tagihan yang belum dibayar untuk periode ini.',
      _ => 'Belum ada tagihan terdata pada periode ini.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Row(
          children: [
            Icon(
              activeKey == 'overdue'
                  ? Icons.check_circle_rounded
                  : Icons.inbox_outlined,
              color: activeKey == 'overdue'
                  ? ColorUtils.success600
                  : ColorUtils.slate400,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                copy,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
