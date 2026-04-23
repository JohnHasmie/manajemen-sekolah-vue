import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_item.dart';

/// Mixin providing payment info display for verification dialog.
mixin VerificationDialogPaymentInfoMixin {
  /// Abstract: State and widget access.
  WidgetRef get ref;
  Map<String, dynamic> get payment;
  String Function(dynamic) get formatCurrency;
  VoidCallback get onShowPaymentProof;

  /// Builds the payment information rows section.
  Widget buildPaymentInfoSection() {
    final languageProvider = ref.watch(languageRiverpod);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FinanceInfoItem(label: 'Siswa', value: payment['siswa_nama'] ?? '-'),
        FinanceInfoItem(label: 'Kelas', value: payment['kelas_nama'] ?? '-'),
        FinanceInfoItem(
          label: languageProvider.getTranslatedText(
            AppLocalizations.paymentTypes,
          ),
          value: payment['jenis_pembayaran_nama'] ?? '-',
        ),
        FinanceInfoItem(
          label: 'Jumlah Bayar',
          value: formatCurrency(payment['amount']),
        ),
        FinanceInfoItem(
          label: 'Metode Bayar',
          value: payment['metode_bayar'] ?? '-',
        ),
      ],
    );
  }

  /// Builds the payment proof banner if receipt exists.
  Widget buildPaymentProofBanner() {
    if (payment['payment_receipt'] == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        _buildProofBannerContent(),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// Helper to build the proof banner content.
  Widget _buildProofBannerContent() {
    return GestureDetector(
      onTap: onShowPaymentProof,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            _buildProofIcon(),
            const SizedBox(width: AppSpacing.sm),
            _buildProofTextContent(),
            _buildProofChevron(),
          ],
        ),
      ),
    );
  }

  /// Helper to build the proof banner icon.
  Widget _buildProofIcon() {
    return Icon(
      Icons.photo_library,
      color: ColorUtils.corporateBlue600,
      size: 20,
    );
  }

  /// Helper to build the proof banner text content.
  Widget _buildProofTextContent() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bukti Pembayaran Tersedia',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorUtils.corporateBlue600,
              fontSize: 12,
            ),
          ),
          Text(
            'Klik untuk melihat gambar',
            style: TextStyle(color: ColorUtils.corporateBlue600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Helper to build the proof banner chevron.
  Widget _buildProofChevron() {
    return Icon(
      Icons.chevron_right,
      color: ColorUtils.corporateBlue600,
      size: 16,
    );
  }
}
