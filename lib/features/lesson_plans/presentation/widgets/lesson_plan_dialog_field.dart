// A read-only display field used inside the "Generate Ulang AI" dialog.
// Like a Vue <ReadonlyField> component — takes label + value strings
// and renders a labelled grey box without touching parent state.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Read-only label + value display used inside the regenerate dialog.
///
/// [label] is the field name (e.g. "Mata Pelajaran").
/// [value] is the current value to display; shows "-" when empty.
class LessonPlanDialogField extends StatelessWidget {
  final String label;
  final String value;

  const LessonPlanDialogField({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ColorUtils.slate500, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              color: ColorUtils.slate800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
