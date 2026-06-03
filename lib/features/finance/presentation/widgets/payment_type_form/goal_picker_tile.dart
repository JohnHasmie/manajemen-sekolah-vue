// Target-recipient picker tile for the payment type form sheet. Opens
// the target selection modal on tap and reflects the chosen goal.

part of '../payment_type_form_sheet.dart';

class _GoalPickerTile extends StatelessWidget {
  final Map<String, dynamic>? goalData;
  final Color primaryColor;
  final String description;
  final VoidCallback onTap;

  const _GoalPickerTile({
    required this.goalData,
    required this.primaryColor,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalData != null && goalData!.isNotEmpty;
    final tint = hasGoal ? const Color(0xFF059669) : primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasGoal
                  ? tint.withValues(alpha: 0.4)
                  : ColorUtils.slate200,
              width: hasGoal ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  hasGoal ? Icons.check_circle_rounded : Icons.groups_rounded,
                  size: 18,
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasGoal ? 'Target dipilih' : 'Belum ada target',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: hasGoal ? tint : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasGoal
                          ? description
                          : 'Pilih kelas, tingkat, atau siswa '
                                'yang akan ditagih.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
