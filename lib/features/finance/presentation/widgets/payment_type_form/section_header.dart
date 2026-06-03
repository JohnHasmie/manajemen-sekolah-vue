// Section header used between groups of inputs in the payment type
// form sheet — small icon, kicker label, and a hairline rule.

part of '../payment_type_form_sheet.dart';

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ColorUtils.slate500),
        const SizedBox(width: 6),
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
