// Tagihan tab body — Mockup #13 (Phase Final), aggregated revision.
//
// Backed by `GET /finance/bill-groups` instead of `/bills`: the admin
// hub no longer downloads every individual bill just to group them
// client-side. The server returns one row per (jenis × kelas × tahun)
// bucket already, so this widget just filters/sorts what arrives.
//
// Per-student detail still lives in [AdminBillGroupDetailScreen]
// which fetches its own filtered bill list lazily when the admin
// taps a group card.
//
// Filter inputs (status / jenis / bulan) come from the page header's
// BrandFilterChips. Status filtering is applied here against the
// group's count breakdown; jenis + bulan are forwarded to the
// server-side fetch so the response is already narrowed by the
// time it reaches us — those local fields just gate empty-state
// copy.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/features/finance/domain/models/bill_group.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_bill_group_detail_screen.dart';

class TagihanTab extends StatelessWidget {
  /// Aggregated bucket list from `GET /finance/bill-groups`. Each
  /// entry is one (payment_type × class × academic_year) row.
  final List<BillGroup> billGroups;

  /// Active status filter key — one of `'all'`, `'unpaid'`, `'overdue'`.
  /// Driven from the header's "Status" chip.
  final String activeFilterKey;

  /// Tap handler for the right-aligned "Tagih" button on each
  /// per-bill row inside the detail screen. Carries the raw bill
  /// map so the caller can fan out to its existing reminder /
  /// verification flow.
  final void Function(Map<String, dynamic> bill)? onTagih;

  /// Optional bill-level tap forwarded to [AdminBillGroupDetailScreen].
  final void Function(Map<String, dynamic> bill)? onTap;

  /// Tap handler for the navy-tinted [ClassReportDrillCard] pinned at
  /// the bottom of the list.
  final VoidCallback onClassReportTap;

  /// Pull-to-refresh callback.
  final Future<void> Function() onRefresh;

  /// Active academic year id — forwarded to the detail screen so its
  /// own bill fetch is scoped to the same year as the group card the
  /// user tapped.
  final String? academicYearId;

  const TagihanTab({
    super.key,
    required this.billGroups,
    required this.activeFilterKey,
    required this.onClassReportTap,
    required this.onRefresh,
    this.academicYearId,
    this.onTagih,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _applyFilter(billGroups);

    // Body is filter-chrome free — status / jenis / bulan all live in
    // the page header. The body is just the grouped rows + the drill
    // card pinned at the bottom.
    final emptyOffset = groups.isEmpty ? 1 : 0;
    final itemCount = groups.length + emptyOffset + 1;

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      role: 'admin',
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Empty state slot (shown only when filtered list is empty)
          if (groups.isEmpty && index == 0) {
            return _EmptyTagihan(activeKey: activeFilterKey);
          }

          // Grouped rows (one per jenis × kelas × tahun).
          final rowIndex = index - emptyOffset;
          if (rowIndex >= 0 && rowIndex < groups.length) {
            final group = groups[rowIndex];
            return BillGroupRow(
              data: BillGroupRowData(
                title: group.title,
                totalCount: group.totalCount,
                paidCount: group.paidCount,
                unpaidCount: group.unpaidCount,
                overdueCount: group.overdueCount,
                totalAmount: group.totalAmount,
                paidAmount: group.paidAmount,
              ),
              onTap: () => AdminBillGroupDetailScreen.show(
                context: context,
                title: group.title,
                paymentTypeId: group.paymentTypeId,
                classId: group.classId,
                // Prefer the bucket's own AY (resolved server-side
                // by the LATERAL JOIN); fall back to the hub's
                // globally-picked AY only when the bucket has none
                // (e.g. legacy bills with NULL AY whose pivot was
                // also missing an AY).
                academicYearId: group.academicYearId ?? academicYearId,
                onTagih: onTagih,
                onTapBill: onTap,
              ),
            );
          }

          // Drill card pinned at bottom
          return ClassReportDrillCard(onTap: onClassReportTap);
        },
      ),
    );
  }

  // ── Status filter ─────────────────────────────────────────────────
  //
  // jenis + bulan filtering happens server-side via the same query
  // params passed to /finance/bill-groups, so we only handle the
  // status sub-filter here. The header's "Status" chip cycles through
  // all / unpaid / overdue without round-tripping.

  List<BillGroup> _applyFilter(List<BillGroup> groups) {
    switch (activeFilterKey) {
      case 'unpaid':
        return groups
            .where((g) => g.unpaidCount + g.overdueCount > 0)
            .toList();
      case 'overdue':
        return groups.where((g) => g.overdueCount > 0).toList();
      default:
        return groups;
    }
  }
}

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
                  ? const Color(0xFF10B981)
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