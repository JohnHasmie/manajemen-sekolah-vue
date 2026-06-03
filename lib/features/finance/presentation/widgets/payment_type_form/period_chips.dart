// Billing-period selection chips (Sekali / Bulanan / Semester /
// Tahunan) for the payment type form sheet.

part of '../payment_type_form_sheet.dart';

class _PeriodChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color primaryColor;

  const _PeriodChips({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Value strings must match CreatePaymentTypeRequest's `in:` rule
    // exactly. The legacy `'sekali bayar'` string (with a space) was
    // rejected by validation, surfacing as a generic "Gagal memproses"
    // toast. Use the same lowercase pattern as the other three so the
    // backend accepts it.
    const options = [
      _PeriodOption('sekali', 'Sekali', Icons.looks_one_rounded),
      _PeriodOption('bulanan', 'Bulanan', Icons.calendar_view_month_rounded),
      _PeriodOption('semester', 'Semester', Icons.date_range_rounded),
      _PeriodOption('tahunan', 'Tahunan', Icons.calendar_today_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              Expanded(
                child: _PeriodChipTile(
                  option: options[i],
                  selected: value == options[i].value,
                  primaryColor: primaryColor,
                  onTap: () => onChanged(options[i].value),
                ),
              ),
              if (i < options.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sekali = tagihan sekali jalan, Bulanan/Semester/Tahunan = berulang otomatis.',
          style: TextStyle(
            fontSize: 10.5,
            color: ColorUtils.slate500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PeriodOption {
  final String value;
  final String label;
  final IconData icon;
  const _PeriodOption(this.value, this.label, this.icon);
}

class _PeriodChipTile extends StatelessWidget {
  final _PeriodOption option;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PeriodChipTile({
    required this.option,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 18,
                color: selected ? primaryColor : ColorUtils.slate500,
              ),
              const SizedBox(height: 4),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? primaryColor : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
