import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Compact editable score cell matching Buku Nilai style.
/// Shows score-colored text + small history icon for grade selection.
class GradeRecapEditableCell extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<double> onChanged;
  final VoidCallback onHistoryTap;

  const GradeRecapEditableCell({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onHistoryTap,
  });

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;
    final score = double.tryParse(controller.text) ?? 0;

    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 44,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: hasValue ? _scoreColor(score) : ColorUtils.slate300,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: InputBorder.none,
            hintText: '-',
            hintStyle: TextStyle(color: ColorUtils.slate300, fontWeight: FontWeight.w400, fontSize: 11),
          ),
          onChanged: (val) => onChanged(double.tryParse(val) ?? 0.0),
        ),
      ),
      GestureDetector(
        onTap: onHistoryTap,
        child: Icon(Icons.arrow_drop_down_rounded, size: 16, color: ColorUtils.slate400),
      ),
    ]);
  }
}
