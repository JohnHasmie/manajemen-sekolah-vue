// Read-only detail sheet for a payment type, opened on tap from the
// Jenis tab. Pairs a status pill, amount, period, target description,
// and (optional) free-text description with a single "Edit jenis"
// primary CTA and a "Hapus" secondary destructive CTA.
//
// Replaces the old PopupMenuButton + Generate flow on the row card —
// see `finance_payment_types_tab.dart`'s top-of-file comment for the
// rationale. Long-press still routes straight to the destructive
// confirm sheet, this sheet is for the soft-tap case where the admin
// wants to look first.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Shows the detail sheet and waits for the user to tap one of the two
/// actions (or dismiss). Returns the chosen [PaymentTypeDetailAction]
/// or `null` if the sheet was dismissed.
Future<PaymentTypeDetailAction?> showPaymentTypeDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> paymentType,
  required Color primaryColor,
  required String Function(dynamic) formatCurrency,
  required String Function(String?) getTranslatedPeriod,
  required String Function(dynamic) getGoalDescription,
}) {
  return showModalBottomSheet<PaymentTypeDetailAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaymentTypeDetailSheet(
      paymentType: paymentType,
      primaryColor: primaryColor,
      formatCurrency: formatCurrency,
      getTranslatedPeriod: getTranslatedPeriod,
      getGoalDescription: getGoalDescription,
    ),
  );
}

/// What the user picked from the detail sheet.
///
///   - [edit]    — open the full edit form
///   - [delete]  — destructive confirm + hard delete (or soft
///                 deactivate when bills exist)
///   - [activate] / [deactivate] — quick status flip without
///     reopening the form, returned when the admin taps the
///     activate/deactivate quick action
enum PaymentTypeDetailAction { edit, delete, activate, deactivate }

class PaymentTypeDetailSheet extends StatelessWidget {
  final Map<String, dynamic> paymentType;
  final Color primaryColor;
  final String Function(dynamic) formatCurrency;
  final String Function(String?) getTranslatedPeriod;
  final String Function(dynamic) getGoalDescription;

  const PaymentTypeDetailSheet({
    super.key,
    required this.paymentType,
    required this.primaryColor,
    required this.formatCurrency,
    required this.getTranslatedPeriod,
    required this.getGoalDescription,
  });

  @override
  Widget build(BuildContext context) {
    final navy = primaryColor;
    final name = (paymentType['name'] ?? '-').toString();
    final amount = formatCurrency(paymentType['amount']);
    final periodRaw = (paymentType['periode'] ?? paymentType['type'])
        ?.toString();
    final periodLabel = getTranslatedPeriod(periodRaw);
    final status = (paymentType['status'] ?? 'active').toString().toLowerCase();
    final isActive = status == 'active';
    final description = (paymentType['description'] ?? '').toString().trim();
    final goalLabel = getGoalDescription(paymentType['goal']);

    return AppBottomSheet(
      title: name,
      subtitle: 'Detail jenis pembayaran',
      icon: Icons.credit_card_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.85,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero amount + status pill
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.credit_card_rounded, color: navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'JUMLAH',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(active: isActive),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Detail rows
          const _SectionHeader(label: 'INFORMASI'),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Periode penagihan',
            value: periodLabel.isEmpty ? '—' : periodLabel,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.groups_rounded,
            label: 'Target penerima',
            value: goalLabel,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.notes_rounded,
              label: 'Deskripsi',
              value: description,
              multiline: true,
            ),
          ],
          const SizedBox(height: 16),

          // Schedule explainer card — replaces the old "Generate" mini
          // button. This sets expectations: bills auto-generate every
          // night when the type is active.
          if (isActive)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: navy.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_repeat_rounded, size: 16, color: navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tagihan untuk jenis ini dibuat otomatis setiap malam.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: navy,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle_rounded,
                    size: 16,
                    color: ColorUtils.slate500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jenis ini sedang nonaktif — tidak ada tagihan '
                      'baru yang dibuat.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Quick activate/deactivate row — saves the admin a trip
          // through the full Edit form just to flip status. Only shown
          // when there's a meaningful direction to flip.
          const SizedBox(height: 12),
          _StatusToggleButton(
            isActive: isActive,
            navy: navy,
            onTap: () => AppNavigator.pop(
              context,
              isActive
                  ? PaymentTypeDetailAction.deactivate
                  : PaymentTypeDetailAction.activate,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Edit jenis',
        primaryColor: navy,
        secondaryLabel: 'Hapus',
        secondaryDestructive: true,
        onPrimary: () =>
            AppNavigator.pop(context, PaymentTypeDetailAction.edit),
        onSecondary: () =>
            AppNavigator.pop(context, PaymentTypeDetailAction.delete),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: multiline ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick activate/deactivate row inside the detail sheet body. When
/// the type is currently active, it offers "Nonaktifkan jenis"; when
/// inactive, it offers "Aktifkan jenis" in cobalt. Tapping pops the
/// sheet with [PaymentTypeDetailAction.activate] or `.deactivate`.
class _StatusToggleButton extends StatelessWidget {
  final bool isActive;
  final Color navy;
  final VoidCallback onTap;

  const _StatusToggleButton({
    required this.isActive,
    required this.navy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? ColorUtils.slate600 : navy;
    final fillBg = isActive ? Colors.white : navy.withValues(alpha: 0.08);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: fillBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? ColorUtils.slate200
                  : navy.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.pause_circle_rounded
                    : Icons.play_circle_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive ? 'Nonaktifkan jenis' : 'Aktifkan jenis',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? 'Hentikan pembuatan tagihan baru tanpa '
                                'menghapus jenis.'
                          : 'Mulai lagi pembuatan tagihan otomatis '
                                'untuk jenis ini.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
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

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFF0FDF4) : ColorUtils.slate100;
    final fg = active ? const Color(0xFF166534) : ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
