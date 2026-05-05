import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';
import 'package:manajemensekolah/features/finance/data/money_flow_service.dart';

/// Gradient header for the admin finance hub (Mockup #13 applied).
///
/// The header now stacks 4 layers inside the navy gradient:
///   1. Top row — back chevron, title/subtitle, refresh meatball
///   2. Period pill (auto-fills with the current calendar month)
///   3. MoneyFlowStrip — 3 KPI tiles (Masuk / Terutang / Jatuh Tempo)
///   4. FlowBar — single-row stacked bar paid/outstanding/overdue
///
/// Layers 3-4 watch `moneyFlowProvider` and gracefully fall back to
/// skeleton placeholders while the API call resolves. The existing
/// title row stays identical so other admin screens still feel like
/// siblings.
class FinanceHeader extends ConsumerWidget {
  const FinanceHeader({
    required this.languageProvider,
    required this.primaryColor,
    required this.onRefresh,
    this.academicYearId,
    this.onOverdueTap,
    this.selectedMonth,
    this.onPickMonth,
    super.key,
  });

  final dynamic languageProvider;
  final Color primaryColor;
  final VoidCallback onRefresh;

  /// Active academic year — used to scope `moneyFlowProvider`. Null
  /// is fine: the backend falls back to "any AY".
  final String? academicYearId;

  /// Tap handler for the red overdue tile. Wires through to the
  /// screen which usually filters the Tagihan tab to overdue.
  final VoidCallback? onOverdueTap;

  /// Currently-selected month override (`YYYY-MM`). When non-null, the
  /// header period pill displays this instead of the API's default
  /// `periodLabel`, signaling the page is scoped to that month.
  final String? selectedMonth;

  /// Tap handler for the period pill — opens the month picker sheet.
  final VoidCallback? onPickMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.82)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TitleRow(
              languageProvider: languageProvider,
              onBack: () => AppNavigator.pop(context),
              onRefresh: onRefresh,
            ),
            const SizedBox(height: AppSpacing.md),
            _MoneyFlowSection(
              academicYearId: academicYearId,
              onOverdueTap: onOverdueTap,
              selectedMonth: selectedMonth,
              onPickMonth: onPickMonth,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Title row
// =====================================================================

class _TitleRow extends StatelessWidget {
  final dynamic languageProvider;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _TitleRow({
    required this.languageProvider,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          _IconChip(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Operasional',
                    'id': 'Operasional',
                  }),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Keuangan',
                    'id': 'Keuangan',
                  }),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          _IconChip(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// =====================================================================
// Money flow section (period pill + strip + flow bar)
// =====================================================================

class _MoneyFlowSection extends ConsumerWidget {
  final String? academicYearId;
  final VoidCallback? onOverdueTap;
  final String? selectedMonth;
  final VoidCallback? onPickMonth;

  const _MoneyFlowSection({
    required this.academicYearId,
    this.onOverdueTap,
    this.selectedMonth,
    this.onPickMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moneyFlowProvider(academicYearId));

    // Stable widget tree: always Column > [PeriodPill, Sizebox, slot,
    // (Sizebox + FlowBar | Sizebox)]. The previous shape-shifting
    // `async.when` returning either a Column or a Padding triggered
    // `_RenderObjectSemantics.debugCheckForParentData` failures every
    // frame because the parent's parentData on its child slot got
    // marked dirty when the widget type swapped. Keeping a single
    // shape and toggling only the inner slot widget avoids that.

    // The pill label prefers the explicit user override (e.g. user
    // picked "Mei 2026" via `MonthFilterSheet`), then falls back to
    // the API-provided label, then to em-dash placeholder.
    final apiLabel = async.maybeWhen(
      data: (s) => s.periodLabel,
      orElse: () => '—',
    );
    final periodLabel = selectedMonth != null
        ? _monthLabelForKey(selectedMonth!)
        : apiLabel;

    final Widget centerSlot;
    final Widget bottomSlot;

    if (async.hasValue) {
      final summary = async.value!;
      centerSlot = MoneyFlowStrip(
        figures: summary.figures,
        onOverdueTap: summary.hasOverdue ? onOverdueTap : null,
      );
      bottomSlot = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          FlowBar(
            paidPct: summary.paidPct,
            outstandingPct: summary.outstandingPct,
            overduePct: summary.overduePct,
          ),
        ],
      );
    } else if (async.hasError) {
      centerSlot = _MoneyFlowError(
        message: _shortenError(async.error!),
        onRetry: () => ref.invalidate(moneyFlowProvider(academicYearId)),
      );
      bottomSlot = const SizedBox.shrink();
    } else {
      centerSlot = const MoneyFlowSkeleton();
      bottomSlot = const SizedBox.shrink();
    }

    // ExcludeSemantics prevents the parentDataDirty assertion that
    // fires every frame in debug mode when centerSlot swaps between
    // MoneyFlowSkeleton / MoneyFlowStrip / _MoneyFlowError.
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodPill(
            label: periodLabel,
            onTap: onPickMonth,
            isFiltered: selectedMonth != null,
          ),
          const SizedBox(height: AppSpacing.md),
          centerSlot,
          bottomSlot,
        ],
      ),
    );
  }
}

/// Returns a long-form month label (e.g. `"Mei 2026"`) for a `YYYY-MM`
/// key, falling back to the raw key on parse failure.
String _monthLabelForKey(String key) {
  const months = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]) ?? 0;
  if (m < 1 || m > 12) return key;
  return '${months[m]} ${parts[0]}';
}

String _shortenError(Object e) {
  final raw = e.toString();
  if (raw.length <= 140) return raw;
  return '${raw.substring(0, 140)}…';
}

class _MoneyFlowError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MoneyFlowError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Flat single-Column layout (no Row+Expanded+Material nesting). The
    // earlier Row(Icon, Expanded(Column), Material(InkWell)) variant
    // tripped Flutter's parentDataDirty semantics assertion every frame
    // because the Material descendant didn't get clean parent-data when
    // the AsyncValue rebuilt between loading/error states. Keeping the
    // surface flat — a Container with a Column of widgets bound to
    // tight horizontal constraints — sidesteps the issue entirely.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Ringkasan keuangan gagal dimuat',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Coba lagi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF143068),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isFiltered;
  const _PeriodPill({required this.label, this.onTap, this.isFiltered = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isFiltered ? 0.28 : 0.18),
                borderRadius: BorderRadius.circular(11),
                border: isFiltered
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFiltered) ...[
                    const Icon(
                      Icons.filter_alt_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _ColorUtils unused import shield — keeping to avoid analyzer
// warnings if a future helper lands.
// ignore: unused_element
void _ensureColorUtilsImport() {
  ColorUtils.getRoleColor('admin');
}
