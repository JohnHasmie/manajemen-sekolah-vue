// Parent billing screen — Phase 3 brand-aligned redesign.
//
// Replaces the bespoke gradient hero (with inline search + filter +
// refresh icons) with the canonical Phase-3 stack:
//
//   • BrandPageHeader (role 'wali') — title/kicker, BrandRealtimePill,
//     ChildSelectorChipRow as the childSelector slot, and a
//     BrandFilterChipStrip in the bottomSlot showing the active
//     Periode + Status filters (matches Nilai's chip-only pattern, per
//     the user's brief).
//   • Body wrapped in RefreshIndicator → BillingList.
//
// The previous inline search input is gone (parents tap chips, not
// type bill names). The status + period filters are still authored
// via the existing FinanceFilterSheet — tapping any chip in the
// strip opens it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/billing_list.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_filter_sheet.dart';

class ParentBillingScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const ParentBillingScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<ParentBillingScreen> createState() =>
      _ParentBillingScreenState();
}

class _ParentBillingScreenState extends ConsumerState<ParentBillingScreen> {
  void _showFilterSheet(LanguageProvider lp) {
    final state = ref.read(parentFinanceProvider).value;
    if (state == null) return;

    // Route through the canonical `FinanceFilterSheet.show()` static helper
    // — mirrors the `App*BottomSheet.show()` pattern so callers don't
    // re-derive `isScrollControlled` / barrier behaviour every time.
    FinanceFilterSheet.show(
      context: context,
      currentStatus: state.statusFilter,
      currentPeriod: state.periodFilter,
      languageProvider: lp,
      primaryColor: ColorUtils.brandAzureDeep,
      onApply: (status, period) {
        ref
            .read(parentFinanceProvider.notifier)
            .updateFilters(status: status, period: period);
      },
    );
  }

  // ---------- Filter chip helpers --------------------------------------

  String? _periodChipValue(LanguageProvider lp, String? period) {
    if (period == null) return null;
    // Backend canonical: `monthly` / `yearly` / `once`. Accept legacy
    // Indonesian aliases (`bulanan` / `tahunan`) for back-compat.
    return lp.getTranslatedText(switch (period) {
      'monthly' || 'bulanan' => {'en': 'Monthly', 'id': 'Bulanan'},
      'yearly' || 'tahunan' => {'en': 'Yearly', 'id': 'Tahunan'},
      'once' || 'sekali' => {'en': 'Once', 'id': 'Sekali bayar'},
      _ => {'en': period, 'id': period},
    });
  }

  String? _statusChipValue(LanguageProvider lp, String? status) {
    if (status == null) return null;
    return lp.getTranslatedText(switch (status) {
      'unpaid' => {'en': 'Unpaid', 'id': 'Belum lunas'},
      'pending' => {'en': 'Pending', 'id': 'Menunggu'},
      'verified' => {'en': 'Verified', 'id': 'Lunas'},
      _ => {'en': status, 'id': status},
    });
  }

  int _activeFilterCount(String? status, String? period) {
    var n = 0;
    if (status != null) n++;
    if (period != null) n++;
    return n;
  }

  // ---------- Build -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final financeAsync = ref.watch(parentFinanceProvider);

    final header = financeAsync.when(
      data: (state) => _buildHeader(
        languageProvider,
        state.students,
        state.selectedStudent?.id,
        state.statusFilter,
        state.periodFilter,
      ),
      loading: () => _buildHeader(languageProvider, const [], null, null, null),
      error: (_, __) =>
          _buildHeader(languageProvider, const [], null, null, null),
    );

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'wali',
        onRefresh: () async {
          await ref.read(parentFinanceProvider.notifier).forceRefresh();
          if (mounted) setState(() {});
        },
        header: header,
        kpiCard: BillingKpiOverlay(languageProvider: languageProvider),
        bodyChildren: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BillingList(languageProvider: languageProvider),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(
    LanguageProvider lp,
    List<dynamic> students,
    String? selectedStudentId,
    String? statusFilter,
    String? periodFilter,
  ) {
    final summaries = students
        .map<ChildSummary>((s) {
          final id = s.id?.toString() ?? '';
          final name = (s.name as String?) ?? '';
          final klass = (s.className as String?) ?? '';
          return ChildSummary(
            id: id,
            shortName: name.isEmpty ? '?' : name,
            klass: klass.isEmpty ? '-' : 'Kelas $klass',
          );
        })
        .toList(growable: false);

    final activeCount = _activeFilterCount(statusFilter, periodFilter);

    return BrandPageHeader(
      role: 'wali',
      // Match the BrandPageLayout overlap so the KPI's overlap zone
      // tucks into empty navy below the chips instead of covering
      // them. (BrandPageLayout positions the body at
      // `top: headerH - kpiOverlapHeight`, so the header needs that
      // many dp of gradient below the chip strip.)
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      showBackButton: widget.showBackButton ? true : null,
      onBackPressed: widget.showBackButton
          ? () => AppNavigator.pop(context)
          : null,
      subtitle: lp.getTranslatedText({
        'en': 'Finance · Child',
        'id': 'Keuangan · Anak',
      }),
      title: lp.getTranslatedText({'en': 'Billing', 'id': 'Tagihan'}),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => _showFilterSheet(lp),
          badgeCount: activeCount > 0 ? activeCount : null,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      // Compact v2 — inline 6dp dot beside the title instead of the
      // full-row `BrandRealtimePill`. The last-sync timestamp is no longer
      // surfaced visually here; if the user wants it back we can promote the
      // dot to a tiny pill.
      isRealtimeFresh: true,
      childSelector: summaries.length < 2
          ? null
          : ChildSelectorChipRow(
              children: summaries,
              selectedChildId: selectedStudentId ?? summaries.first.id,
              onSelected: (id) {
                final picked = students.cast<dynamic>().firstWhere(
                  (s) => s.id?.toString() == id,
                  orElse: () => null,
                );
                if (picked != null) {
                  ref
                      .read(parentFinanceProvider.notifier)
                      .selectStudent(picked);
                }
              },
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lp.getTranslatedText({'en': 'Period', 'id': 'Periode'}),
            value: _periodChipValue(lp, periodFilter),
            onTap: () => _showFilterSheet(lp),
            width: 172,
          ),
          BrandFilterChip(
            label: lp.getTranslatedText({'en': 'Status', 'id': 'Status'}),
            value: _statusChipValue(lp, statusFilter),
            onTap: () => _showFilterSheet(lp),
          ),
        ],
      ),
    );
  }
}
