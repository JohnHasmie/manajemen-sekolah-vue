// Aktif / Nonaktif segmented control for the payment type form sheet's
// activation status.

part of '../payment_type_form_sheet.dart';

class _StatusSegmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color primaryColor;

  const _StatusSegmented({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusSegment(
              label: 'Aktif',
              icon: Icons.check_circle_rounded,
              activeColor: const Color(0xFF059669),
              selected: value == 'active',
              onTap: () => onChanged('active'),
            ),
          ),
          Expanded(
            child: _StatusSegment(
              label: 'Nonaktif',
              icon: Icons.pause_circle_filled_rounded,
              activeColor: ColorUtils.slate600,
              selected: value == 'inactive',
              onTap: () => onChanged('inactive'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatusSegment({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? activeColor : ColorUtils.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? activeColor : ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
