// Pembayaran tab body — v3 redesign (Mockup #13).
//
// Replaces the legacy `PendingPaymentCard` chrome (full-width card,
// avatar circle, info-row chips) with a compact v3 row that mirrors
// `InvoiceRow` from Tagihan: 4-px amber status edge + name + meta +
// status pill + "Lihat bukti" + "Verifikasi" actions.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';

class FinanceVerificationTab extends StatelessWidget {
  const FinanceVerificationTab({
    required this.pendingPaymentList,
    required this.hasMorePending,
    required this.isReadOnly,
    required this.formatCurrency,
    required this.primaryColor,
    required this.onVerify,
    required this.onShowProof,
    this.scrollController,
    super.key,
  });

  final List<dynamic> pendingPaymentList;
  final bool hasMorePending;
  final bool isReadOnly;

  /// Optional explicit scroll controller. Omit (null) when the tab is
  /// hosted inside a `NestedScrollView` body — the underlying
  /// `CustomScrollView` will then attach to the `PrimaryScrollController`
  /// the NestedScrollView provides, so the KPI overlap + sticky tab-bar
  /// scroll fan-out works as expected. Pass an explicit controller only
  /// when the tab owns its own scrollable (legacy hosting).
  final ScrollController? scrollController;
  final String Function(dynamic) formatCurrency;
  final Color primaryColor;
  final Function(int) onVerify;
  final Function(int) onShowProof;

  @override
  Widget build(BuildContext context) {
    if (pendingPaymentList.isEmpty) {
      return const BrandEmptyState(
        icon: Icons.verified_user_outlined,
        tone: BrandEmptyStateTone.success,
        title: 'Tidak ada pembayaran menunggu verifikasi',
        message: 'Semua pembayaran telah diverifikasi',
      );
    }
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  'MENUNGGU VERIFIKASI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${pendingPaymentList.length} PEMBAYARAN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate300,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: pendingPaymentList.length + (hasMorePending ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == pendingPaymentList.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final m = Map<String, dynamic>.from(
              pendingPaymentList[index] as Map,
            );
            return _PendingRow(
              data: m,
              navy: primaryColor,
              isReadOnly: isReadOnly,
              formatCurrency: formatCurrency,
              onTap: () => onVerify(index),
              onShowProof: () => onShowProof(index),
            );
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
        ),
      ],
    );
  }
}

class _PendingRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color navy;
  final bool isReadOnly;
  final String Function(dynamic) formatCurrency;
  final VoidCallback onTap;
  final VoidCallback onShowProof;

  const _PendingRow({
    required this.data,
    required this.navy,
    required this.isReadOnly,
    required this.formatCurrency,
    required this.onTap,
    required this.onShowProof,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = (data['siswa_nama'] ?? '-').toString();
    final className = (data['kelas_nama'] ?? '-').toString();
    final billType = (data['jenis_pembayaran_nama'] ?? '-').toString();
    final amount = formatCurrency(data['amount']);
    final dateRaw = data['payment_date']?.toString();
    final date = (dateRaw != null && dateRaw.contains('T'))
        ? dateRaw.split('T').first
        : dateRaw ?? '-';
    final hasProof = data['payment_receipt'] != null;
    final initial = studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
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
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
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
                                  'Kelas $className · $billType',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: ColorUtils.slate500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const _MenungguPill(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            amount,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: ColorUtils.slate500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (hasProof)
                            Expanded(
                              child: _OutlineButton(
                                icon: Icons.image_rounded,
                                label: 'Bukti',
                                navy: navy,
                                onTap: onShowProof,
                              ),
                            )
                          else
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ColorUtils.slate100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Tanpa bukti',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.slate500,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _PrimaryButton(
                              label: 'Verifikasi',
                              navy: navy,
                              enabled: !isReadOnly,
                              onTap: isReadOnly ? null : onTap,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _MenungguPill extends StatelessWidget {
  const _MenungguPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFB45309)),
          SizedBox(width: 4),
          Text(
            'Menunggu',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color navy;
  final VoidCallback onTap;
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.navy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: navy),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color navy;
  final bool enabled;
  final VoidCallback? onTap;
  const _PrimaryButton({
    required this.label,
    required this.navy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? navy : ColorUtils.slate300,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
