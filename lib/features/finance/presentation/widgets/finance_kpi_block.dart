// White KPI card + custom Aliran (FlowBar) for the admin Keuangan hub.
//
// Structurally mirrors the parent Tagihan KPI strip (`billing_list.dart`'s
// `_KpiStripCard`): a white slate200-bordered card with three equal
// columns separated by hairlines, each column showing a kicker label
// and a heavy value. Below the columns we keep the admin-specific
// "ALIRAN" FlowBar — the visual that admins explicitly asked us to
// preserve when migrating to the parent header pattern.
//
// Watches `moneyFlowProvider(academicYearId)` directly so the block can
// own its loading/error/empty states without forcing the parent screen
// to plumb the AsyncValue through. The parent screen just drops this
// widget below the header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/data/money_flow_service.dart';

class FinanceKpiBlock extends ConsumerWidget {
  /// Active academic year — keys the `moneyFlowProvider` family.
  final String? academicYearId;

  /// Tap handler for the red "Jatuh tempo" column / FlowBar overdue
  /// segment. Wires through to filter Tagihan to overdue.
  final VoidCallback? onOverdueTap;

  const FinanceKpiBlock({
    super.key,
    required this.academicYearId,
    this.onOverdueTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moneyFlowProvider(academicYearId));

    final Widget body;
    if (async.hasValue) {
      body = _Loaded(summary: async.value!, onOverdueTap: onOverdueTap);
    } else if (async.hasError) {
      body = _ErrorBanner(
        message: _shortenError(async.error!),
        onRetry: () => ref.invalidate(moneyFlowProvider(academicYearId)),
      );
    } else {
      body = const _Skeleton();
    }

    // Outer horizontal padding only — vertical spacing is owned by the
    // screen's overlap-Stack (it controls how far the card pokes up
    // into the gradient and how much sits below). Keeping the bottom
    // pad at 0 here so the screen-level SizedBox is the single source
    // of truth for the gap before the navigation bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: body,
    );
  }
}

String _shortenError(Object e) {
  final raw = e.toString();
  return raw.length <= 140 ? raw : '${raw.substring(0, 140)}…';
}

// =====================================================================
// Loaded state — 3-column KPI strip + ALIRAN bar
// =====================================================================

class _Loaded extends StatelessWidget {
  final MoneyFlowSummary summary;
  final VoidCallback? onOverdueTap;

  const _Loaded({required this.summary, this.onOverdueTap});

  @override
  Widget build(BuildContext context) {
    final figures = summary.figures;
    final hasFlow =
        summary.paidPct + summary.outstandingPct + summary.overduePct > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-column KPI strip — Masuk / Terutang / Jatuh tempo
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiColumn(
                    label: 'Masuk',
                    value: figures.incomingAmount,
                    captionText: '${figures.incomingCount} transaksi',
                    deltaText: figures.incomingDelta,
                    valueColor: const Color(0xFF0F172A),
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _KpiColumn(
                    label: 'Terutang',
                    value: figures.outstandingAmount,
                    captionText: '${figures.outstandingCount} tagihan',
                    valueColor: const Color(0xFF0F172A),
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _KpiColumn(
                    label: 'Jatuh tempo',
                    value: figures.overdueAmount,
                    valueColor: figures.overdueCount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A),
                    chip: figures.overdueCount > 0
                        ? _AlertChip(label: '${figures.overdueCount} wali')
                        : null,
                    onTap: figures.overdueCount > 0 ? onOverdueTap : null,
                  ),
                ),
              ],
            ),
          ),

          if (hasFlow) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: ColorUtils.slate100),
            const SizedBox(height: 12),
            _AliranBar(
              paidPct: summary.paidPct,
              outstandingPct: summary.outstandingPct,
              overduePct: summary.overduePct,
              onOverdueTap: onOverdueTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: ColorUtils.slate100,
    );
  }
}

class _KpiColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? captionText;
  final String? deltaText;
  final Color valueColor;
  final Widget? chip;
  final VoidCallback? onTap;

  const _KpiColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.captionText,
    this.deltaText,
    this.chip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (chip != null)
          chip!
        else if (deltaText != null)
          Text(
            deltaText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.success600,
            ),
          )
        else if (captionText != null)
          Text(
            captionText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate500,
            ),
          ),
      ],
    );

    if (onTap == null) return col;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: col,
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  const _AlertChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.priority_high_rounded,
            size: 11,
            color: Color(0xFF991B1B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Aliran bar — the admin's distinctive payment-flow visual.
//
// We can't reuse the existing [FlowBar] from `admin_finance_components`
// directly because it was tuned for the navy-on-navy hero
// (white-on-color labels). Inside a white card we want darker labels
// and a kicker that matches the rest of the v3 admin language.
// =====================================================================

class _AliranBar extends StatelessWidget {
  final double paidPct;
  final double outstandingPct;
  final double overduePct;
  final VoidCallback? onOverdueTap;

  const _AliranBar({
    required this.paidPct,
    required this.outstandingPct,
    required this.overduePct,
    this.onOverdueTap,
  });

  double get _total {
    final t = paidPct + outstandingPct + overduePct;
    return t <= 0 ? 1.0 : t;
  }

  @override
  Widget build(BuildContext context) {
    final paidFrac = paidPct / _total;
    final outFrac = outstandingPct / _total;
    final ovrFrac = overduePct / _total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 12,
              color: ColorUtils.slate500,
            ),
            const SizedBox(width: 5),
            Text(
              'ALIRAN PEMBAYARAN',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: ColorUtils.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (paidFrac > 0)
                  Expanded(
                    flex: (paidFrac * 1000).round(),
                    child: _AliranSegment(
                      color: const Color(0xFF10B981),
                      label: '${paidPct.round()}%',
                      textColor: Colors.white,
                    ),
                  ),
                if (outFrac > 0)
                  Expanded(
                    flex: (outFrac * 1000).round(),
                    child: _AliranSegment(
                      color: const Color(0xFFF59E0B),
                      label: '${outstandingPct.round()}%',
                      textColor: const Color(0xFF7C2D12),
                    ),
                  ),
                if (ovrFrac > 0)
                  Expanded(
                    flex: (ovrFrac * 1000).round(),
                    child: _AliranSegment(
                      color: const Color(0xFFDC2626),
                      label: '${overduePct.round()}%',
                      textColor: Colors.white,
                      onTap: onOverdueTap,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            _Legend(color: Color(0xFF10B981), label: 'Terbayar'),
            SizedBox(width: 12),
            _Legend(color: Color(0xFFF59E0B), label: 'Belum lunas'),
            SizedBox(width: 12),
            _Legend(color: Color(0xFFDC2626), label: 'Jatuh tempo'),
          ],
        ),
      ],
    );
  }
}

class _AliranSegment extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  final VoidCallback? onTap;

  const _AliranSegment({
    required this.color,
    required this.label,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Skeleton + error states
// =====================================================================

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget shimmer({double width = 60, double height = 18}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ColorUtils.slate100,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    Widget col() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        shimmer(width: 56, height: 10),
        const SizedBox(height: 8),
        shimmer(width: 70, height: 16),
        const SizedBox(height: 6),
        shimmer(width: 50, height: 9),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: col()),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: ColorUtils.slate100,
                ),
                Expanded(child: col()),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: ColorUtils.slate100,
                ),
                Expanded(child: col()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: ColorUtils.slate100),
          const SizedBox(height: 12),
          shimmer(width: 110, height: 10),
          const SizedBox(height: 8),
          shimmer(width: double.infinity, height: 14),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'Ringkasan keuangan gagal dimuat',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
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
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
              height: 1.3,
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
                  color: const Color(0xFF143068),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Coba lagi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
