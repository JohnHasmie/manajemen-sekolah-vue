// Summary banner shown on the Dashboard tab when there are pending payments.
//
// Extracted from `_buildPendingSection` in admin_finance_screen.dart.
// Like a Vue `<PendingPaymentBanner>` component — shows the count and a
// "Verify Now" button that switches to the verification tab.
//
// Strings that have no AppLocalizations key are passed as plain [String]
// constructor params (resolved by the parent which has a LanguageProvider).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Warning banner displayed on the finance dashboard when pending payments exist.
///
/// [pendingCount] drives both the subtitle and the badge.
/// [isReadOnly] hides the "Verify Now" button for archived academic years.
/// [onVerifyNow] is called when the user taps that button — the parent
/// switches to tab index 2 (verification tab).
///
/// [verifyNowLabel] and [paymentsNeedVerificationLabel] are pre-translated by
/// the parent because no static AppLocalizations key exists for those phrases.
class FinancePendingSection extends StatelessWidget {
  final int pendingCount;
  final bool isReadOnly;
  final VoidCallback onVerifyNow;

  /// e.g. languageProvider.getTranslatedText({'en':'Verify Now','id':'Verifikasi Sekarang'})
  final String verifyNowLabel;

  /// e.g. languageProvider.getTranslatedText({'en':'payments need verification', ...})
  final String paymentsNeedVerificationLabel;

  const FinancePendingSection({
    super.key,
    required this.pendingCount,
    required this.isReadOnly,
    required this.onVerifyNow,
    required this.verifyNowLabel,
    required this.paymentsNeedVerificationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.warning600.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.warning600.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: ColorUtils.warning600,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.paymentsPendingVerification.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$pendingCount $paymentsNeedVerificationLabel',
                      style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: TextStyle(
                    color: ColorUtils.warning600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!isReadOnly) ...[
            SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVerifyNow,
                icon: Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                label: Text(
                  verifyNowLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.warning600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
