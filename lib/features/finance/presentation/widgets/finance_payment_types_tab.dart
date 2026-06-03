// Jenis tab body — v3 redesign (Mockup #13).
//
// The body is filter-chrome-free. The Status / Periode filters live in
// the page header as `BrandFilterChip`s and are applied upstream by
// `_getFilteredPaymentTypes()` on the screen, so this widget just
// renders whatever rows it's handed.
//
//   * Per-row "Generate" mini-button is gone — the Laravel scheduler
//     in `routes/console.php` runs `finance:generate-bills` daily at
//     01:00.
//   * 3-dot PopupMenu is gone. Standard admin gesture is:
//       • tap row  → open detail / edit sheet
//       • long-press → confirm delete

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';

class FinancePaymentTypesTab extends StatelessWidget {
  const FinancePaymentTypesTab({
    required this.filteredPaymentTypes,
    required this.searchController,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.onShowFilterSheet,
    required this.onClearAllFilters,
    required this.buildFilterChips,
    required this.formatCurrency,
    required this.getGoalDescription,
    required this.getTranslatedPeriod,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
    this.languageProvider,
    this.hasActiveHeaderFilter = false,
    super.key,
  });

  final List<dynamic> filteredPaymentTypes;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final Color primaryColor;
  final VoidCallback onShowFilterSheet;
  final VoidCallback onClearAllFilters;
  final List<ActiveFilter> Function() buildFilterChips;
  final String Function(dynamic) formatCurrency;
  final String Function(dynamic) getGoalDescription;
  final String Function(String?) getTranslatedPeriod;

  /// Tap handler — opens the row's detail / edit sheet.
  final Function(int) onEdit;

  /// Long-press handler — opens the destructive confirm sheet.
  final Function(int) onDelete;
  final Future<void> Function()? onRefresh;
  final dynamic languageProvider;

  /// Whether any header chip filter is currently applied — drives the
  /// "Tidak ada hasil" empty-state copy so the user knows it's a
  /// filter result rather than no data at all.
  final bool hasActiveHeaderFilter;

  @override
  Widget build(BuildContext context) {
    final list = filteredPaymentTypes;
    return AppRefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      role: 'admin',
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 1 + (list.isEmpty ? 1 : list.length),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text(
                    'JENIS PEMBAYARAN',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${list.length} TIPE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: ColorUtils.slate400,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasActiveHeaderFilter
                            ? 'Tidak ada jenis pembayaran pada filter ini.'
                            : 'Belum ada jenis pembayaran. '
                                  'Tap + untuk menambah.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final i = index - 1;
          final pt = Map<String, dynamic>.from(list[i] as Map);
          // Resolve original index in the unfiltered list so callbacks
          // still receive the right reference.
          final origIndex = filteredPaymentTypes.indexOf(list[i]);
          return _PaymentTypeRow(
            data: pt,
            navy: primaryColor,
            formatCurrency: formatCurrency,
            getTranslatedPeriod: getTranslatedPeriod,
            onTap: () => onEdit(origIndex),
            onLongPress: () => onDelete(origIndex),
          );
        },
      ),
    );
  }
}

// =====================================================================
// Payment-type row — v3 styling with status edge + period pill
// =====================================================================

class _PaymentTypeRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color navy;
  final String Function(dynamic) formatCurrency;
  final String Function(String?) getTranslatedPeriod;

  /// Single-tap action — opens the row's detail / edit sheet.
  final VoidCallback onTap;

  /// Long-press action — opens the destructive confirmation sheet.
  final VoidCallback onLongPress;

  const _PaymentTypeRow({
    required this.data,
    required this.navy,
    required this.formatCurrency,
    required this.getTranslatedPeriod,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'active').toString().toLowerCase();
    final isActive = status == 'active';
    final name = (data['name'] ?? '-').toString();
    final amount = formatCurrency(data['amount']);
    // Backend rename: `payment_types.periode` → `payment_types.period`.
    final periodRaw = (data['period'] ?? data['periode'] ?? data['type'])
        ?.toString();
    final periodLabel = getTranslatedPeriod(periodRaw);

    final edgeColor = isActive ? const Color(0xFF10B981) : ColorUtils.slate300;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // Soft slate splash so the long-press hold feels "alive" without
          // shouting destructive — the actual destructive intent is
          // surfaced by the confirmation sheet that opens on release.
          highlightColor: ColorUtils.slate100.withValues(alpha: 0.6),
          splashColor: navy.withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: edgeColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: navy.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  Icons.credit_card_rounded,
                                  color: navy,
                                  size: 18,
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
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      amount,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.slate700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusPill(active: isActive),
                            ],
                          ),
                          if (periodLabel.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.slate100,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 11,
                                        color: ColorUtils.slate500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        periodLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: ColorUtils.slate700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Subtle hint affordance — taps go to detail
                                // / edit, long-press hits delete. Showing a
                                // single chevron beats showing a 3-dot
                                // overflow because there's nothing else
                                // hiding behind it.
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: ColorUtils.slate400,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFF0FDF4) : ColorUtils.slate100;
    final fg = active ? const Color(0xFF166534) : ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
