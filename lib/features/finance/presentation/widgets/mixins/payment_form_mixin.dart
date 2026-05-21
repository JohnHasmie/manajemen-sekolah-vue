// Field builders for the admin manual payment sheet.
//
// v2 redesign:
//   * Metode Pembayaran is now a horizontal chip row (Tunai / Transfer /
//     Kartu / Lainnya) instead of an outlined dropdown. Each chip is
//     bigger, has its own icon, and reads its selection state from the
//     `paymentMethodController.text` — that means the parent sheet's
//     existing controller wiring keeps working without changes.
//   * Jumlah Bayar is locked (read-only). The amount is pre-filled with
//     the bill's outstanding total when the sheet opens. The backend
//     validator rejects partial / over-payment, so making the field
//     editable was a foot-gun that surfaced "Jumlah pembayaran melebihi
//     sisa tagihan" errors after the admin "rounded" the number. Now
//     it's displayed as a polished read-only currency pill with a
//     small "tidak dapat diubah" caption.
//   * Tanggal Bayar still launches `showModernDatePicker` as before,
//     but with a slightly nicer leading icon styling.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dialog_text_field.dart';

/// Mixin providing payment form field builders.
mixin PaymentFormMixin {
  /// Abstract: BuildContext for date picker.
  BuildContext get context;

  /// Abstract: Primary color for styling.
  Color get primaryColor;

  /// Abstract: Payment method controller — populated by the chip row.
  TextEditingController get paymentMethodController;

  /// Abstract: Amount controller — pre-filled, displayed read-only.
  TextEditingController get amountController;

  /// Abstract: Payment date controller — populated by the date picker.
  TextEditingController get paymentDateController;

  /// The four canonical payment methods. Backend accepts any non-empty
  /// string but we keep the surface to these four so the admin can't
  /// type a misspelling that breaks downstream reports.
  static const List<_PaymentMethodOption> _methodOptions = [
    _PaymentMethodOption(
      value: 'Tunai',
      labelKey: 'Tunai',
      icon: Icons.payments_rounded,
    ),
    _PaymentMethodOption(
      value: 'Transfer Bank',
      labelKey: 'Transfer Bank',
      icon: Icons.account_balance_rounded,
    ),
    _PaymentMethodOption(
      value: 'Kartu Kredit/Debit',
      labelKey: 'Kartu',
      icon: Icons.credit_card_rounded,
    ),
    _PaymentMethodOption(
      value: 'Lainnya',
      labelKey: 'Lainnya',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  /// Section header + chip row for choosing the payment method.
  ///
  /// Driven entirely off `paymentMethodController.text` so the parent
  /// sheet doesn't need any extra plumbing — pre-set the controller to
  /// `'Tunai'` (or whatever default) and the right chip will light up.
  Widget buildPaymentMethod() {
    return _PaymentMethodChipRow(
      controller: paymentMethodController,
      primaryColor: primaryColor,
      options: _methodOptions,
    );
  }

  /// Read-only Jumlah Bayar display. The bill's outstanding amount is
  /// pre-filled in the controller by the parent sheet; tapping the
  /// field is a no-op (no keyboard pops). A tiny caption explains why.
  Widget buildAmount() {
    final amountText = amountController.text;
    // Normalise to a "1.500.000" style if the controller carries a
    // numeric-looking string. Falls back to the raw value otherwise so
    // callers that pre-format are still respected.
    final pretty = _formatRupiahFromController(amountText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jumlah Bayar',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pretty,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Nominal mengikuti sisa tagihan dan tidak dapat diubah.',
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  /// Date picker field.
  Widget buildDate() => FinanceDialogTextField(
        controller: paymentDateController,
        label: 'Tanggal Bayar',
        icon: Icons.calendar_today_rounded,
        primaryColor: primaryColor,
        onTap: () async {
          final date = await showModernDatePicker(
            context: context,
            initialDate: DateTime.now(),
            title: 'Pilih Tanggal Bayar',
            lastDate: DateTime.now(),
          );
          if (date != null) {
            paymentDateController.text = date.toString().split(' ')[0];
          }
        },
      );

  String _formatRupiahFromController(String raw) {
    if (raw.isEmpty) return 'Rp 0';
    final n = num.tryParse(raw);
    if (n == null) return raw;
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }
}

/// One row of the four payment-method chips. Stateful so tapping a
/// chip can flip the `paymentMethodController` value AND re-render
/// without forcing the parent sheet to rebuild.
class _PaymentMethodChipRow extends StatefulWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final List<_PaymentMethodOption> options;

  const _PaymentMethodChipRow({
    required this.controller,
    required this.primaryColor,
    required this.options,
  });

  @override
  State<_PaymentMethodChipRow> createState() => _PaymentMethodChipRowState();
}

class _PaymentMethodChipRowState extends State<_PaymentMethodChipRow> {
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = widget.controller.text.isNotEmpty
        ? widget.controller.text
        : widget.options.first.value;
    // Make sure the controller carries a valid value on first paint —
    // earlier the controller could be empty if the parent forgot to
    // seed it, which made the chip row read as "nothing selected".
    if (widget.controller.text.isEmpty) {
      widget.controller.text = _current;
    }
  }

  void _select(String value) {
    if (value == _current) return;
    setState(() => _current = value);
    widget.controller.text = value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.payment_rounded,
                size: 13,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 5),
              Text(
                'METODE PEMBAYARAN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: widget.options
              .map(
                (opt) => _MethodChip(
                  option: opt,
                  isSelected: opt.value == _current,
                  primaryColor: widget.primaryColor,
                  onTap: () => _select(opt.value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _PaymentMethodOption {
  final String value;
  final String labelKey;
  final IconData icon;
  const _PaymentMethodOption({
    required this.value,
    required this.labelKey,
    required this.icon,
  });
}

class _MethodChip extends StatelessWidget {
  final _PaymentMethodOption option;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _MethodChip({
    required this.option,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? primaryColor.withValues(alpha: 0.10)
        : ColorUtils.slate50;
    final border = isSelected ? primaryColor : ColorUtils.slate200;
    final fg = isSelected ? primaryColor : ColorUtils.slate700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border, width: isSelected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                option.labelKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
