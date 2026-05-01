// Pembayaran berhasil — Phase 5 surface D.
//
// Pushed by the Bayar checkout (surface C) when the gateway poll
// returns "paid". The page mirrors the v3 mockup:
//
//   • Success-green hero (gradient + dotted confetti accent), big
//     white check disc, "Pembayaran Berhasil" title, subtitle with
//     bill + student
//   • White card under the hero with the total amount + via-method
//     line
//   • Receipt timeline (3 dots): created → confirmed → recorded
//   • Action row: Unduh PDF + Bagikan + Selesai
//
// Pending variant
// ---------------
// For the manual-transfer flow (`isManualPending = true`) the hero
// flips to amber, the title becomes "Menunggu Verifikasi", and the
// timeline ends at step 2. Same widget — same call site, just one
// flag.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

class ParentPaymentSuccessScreen extends StatelessWidget {
  final String billName;
  final String studentName;
  final String methodLabel;
  final double amount;
  final double adminFee;

  /// True = manual flow finished upload, awaiting admin verification.
  /// Flips the hero from green to amber and the timeline to a
  /// 2-of-3 state.
  final bool isManualPending;

  const ParentPaymentSuccessScreen({
    super.key,
    required this.billName,
    required this.studentName,
    required this.methodLabel,
    required this.amount,
    required this.adminFee,
    this.isManualPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildAmountCard(),
                    AppSpacing.v16,
                    _buildTimelineCard(),
                    AppSpacing.v16,
                    _buildActionsRow(context),
                    AppSpacing.v8,
                    _buildSelesaiButton(context),
                    AppSpacing.v16,
                    Text(
                      isManualPending
                          ? 'Bukti diteruskan ke admin sekolah untuk verifikasi.'
                          : 'Notifikasi lunas otomatis dikirim ke admin sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────── pieces ──────────────

  Widget _buildHero() {
    final gradientStart = isManualPending
        ? const Color(0xFFF59E0B)
        : ColorUtils.success600;
    final gradientEnd = isManualPending
        ? const Color(0xFFB45309)
        : const Color(0xFF059669);
    final iconColor = isManualPending
        ? const Color(0xFFB45309)
        : ColorUtils.success600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isManualPending
                  ? Icons.access_time_rounded
                  : Icons.check_rounded,
              color: iconColor,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isManualPending
                ? 'Menunggu Verifikasi'
                : 'Pembayaran Berhasil',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$billName · $studentName',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final total = amount + adminFee;
    final color = isManualPending
        ? const Color(0xFFB45309)
        : ColorUtils.success600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isManualPending ? 'NOMINAL DIKIRIM' : 'JUMLAH DIBAYAR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRupiah(total),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'via $methodLabel · ${_formatTodayShort()}',
            style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIWAYAT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimelineStep(
            label: 'Pembayaran dibuat',
            sub: '${_formatTimeShort()} · $methodLabel',
            done: true,
          ),
          _TimelineConnector(done: true),
          _TimelineStep(
            label: isManualPending
                ? 'Bukti pembayaran diunggah'
                : 'Pembayaran dikonfirmasi',
            sub: isManualPending
                ? '${_formatTimeShort()} · menunggu admin verifikasi'
                : '${_formatTimeShort()} · gateway',
            done: true,
          ),
          _TimelineConnector(done: !isManualPending),
          _TimelineStep(
            label: isManualPending
                ? 'Verifikasi admin (1–24 jam)'
                : 'Tagihan ditandai LUNAS',
            sub: isManualPending
                ? 'Status akan berubah otomatis'
                : '${_formatTimeShort()} · Kuitansi tersedia',
            done: !isManualPending,
            isPending: isManualPending,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(
            icon: Icons.download_rounded,
            label: 'Unduh PDF',
            onTap: () => SnackBarUtils.showInfo(
              context,
              'Fitur unduh PDF segera hadir',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.share_rounded,
            label: 'Bagikan',
            onTap: () => SnackBarUtils.showInfo(
              context,
              'Fitur bagikan kuitansi segera hadir',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelesaiButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () => AppNavigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorUtils.brandAzureDeep,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Selesai',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final String sub;
  final bool done;
  final bool isPending;

  const _TimelineStep({
    required this.label,
    required this.sub,
    required this.done,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPending
        ? const Color(0xFFF59E0B)
        : (done ? ColorUtils.success600 : const Color(0xFFCBD5E1));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
            isPending
                ? Icons.access_time_rounded
                : (done ? Icons.check_rounded : Icons.circle_outlined),
            size: 12,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: done ? ColorUtils.slate900 : ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final bool done;

  const _TimelineConnector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        width: 2,
        height: 16,
        color: done ? ColorUtils.success600 : const Color(0xFFCBD5E1),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: ColorUtils.brandAzureDeep),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRupiah(double amount) {
  final whole = amount.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final remain = s.length - i;
    buf.write(s[i]);
    if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
  }
  return 'Rp $buf';
}

String _formatTodayShort() {
  final n = DateTime.now();
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${n.day} ${months[n.month - 1]} ${n.year}';
}

String _formatTimeShort() {
  final n = DateTime.now();
  final h = n.hour.toString().padLeft(2, '0');
  final m = n.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
