// Activation section — start_date picker + monthly day-of-month picker
// for the payment type form sheet.

part of '../payment_type_form_sheet.dart';

/// Renders the "Mulai aktif" inputs.
///
/// Always shows the start_date picker so every periode (sekali too) has
/// a clear "this is when billing kicks in" anchor. The day-of-month
/// picker only appears when periode is `bulanan` since the other
/// periodes derive their due_date from start_date alone.
class _ActivationFields extends StatelessWidget {
  final DateTime startDate;
  final int dayOfMonth;
  final String periode;
  final Color primaryColor;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<int> onDayOfMonthChanged;

  const _ActivationFields({
    required this.startDate,
    required this.dayOfMonth,
    required this.periode,
    required this.primaryColor,
    required this.onStartDateChanged,
    required this.onDayOfMonthChanged,
  });

  // Indonesian month names for the human-readable date display.
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  /// Periode-aware helper text. We don't want to claim "tagihan tiap
  /// tanggal X" for a Jenis that only bills once.
  String _startHelper() {
    switch (periode) {
      case 'bulanan':
        return 'Tagihan akan dibuat mulai bulan ini.';
      case 'semester':
        return 'Tagihan semester akan dibuat dari tanggal ini.';
      case 'tahunan':
        return 'Tagihan tahunan akan dibuat dari tanggal ini.';
      case 'sekali':
      default:
        return 'Tanggal jatuh tempo tagihan.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBulanan = periode == 'bulanan';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DatePickerTile(
          label: 'TANGGAL MULAI',
          value: _formatDate(startDate),
          icon: Icons.event_rounded,
          primaryColor: primaryColor,
          onTap: () async {
            final picked = await showModernDatePicker(
              context: context,
              initialDate: startDate,
              title: 'Pilih tanggal mulai',
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              primaryColor: primaryColor,
            );
            if (picked != null) onStartDateChanged(picked);
          },
          helper: _startHelper(),
        ),
        if (isBulanan) ...[
          const SizedBox(height: 14),
          _DayOfMonthStepper(
            value: dayOfMonth,
            onChanged: onDayOfMonthChanged,
            primaryColor: primaryColor,
          ),
        ],
      ],
    );
  }
}

/// A read-only tile that opens a date picker on tap.
class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;
  final String? helper;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: ColorUtils.slate400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.slate400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Day-of-month picker as a — / + stepper with the value in the middle.
/// Clamped 1-28 to match the backend rule (avoids Feb-29 edge cases).
class _DayOfMonthStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color primaryColor;

  const _DayOfMonthStepper({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JATUH TEMPO TIAP TANGGAL',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                primaryColor: primaryColor,
                enabled: value > 1,
                onTap: () => onChanged(value - 1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tanggal $value',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                primaryColor: primaryColor,
                enabled: value < 28,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Berlaku 1-28 untuk menghindari masalah Februari.',
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

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color primaryColor;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.primaryColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled
                ? primaryColor.withValues(alpha: 0.10)
                : ColorUtils.slate100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? primaryColor : ColorUtils.slate400,
          ),
        ),
      ),
    );
  }
}
