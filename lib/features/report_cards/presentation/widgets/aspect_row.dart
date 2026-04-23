import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/compact_text_field.dart';

class AspectRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String scoreValue;
  final String predicateValue;
  final String descriptionValue;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<String> onPredicateChanged;
  final ValueChanged<String> onDescChanged;

  const AspectRow({
    super.key,
    required this.icon,
    required this.label,
    required this.scoreValue,
    required this.predicateValue,
    required this.descriptionValue,
    required this.onScoreChanged,
    required this.onPredicateChanged,
    required this.onDescChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        _buildScoreAndPredicate(),
        const SizedBox(height: 8),
        CompactTextField(
          label: 'Deskripsi',
          initialValue: descriptionValue,
          onChanged: onDescChanged,
        ),
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Icon(icon, size: 14, color: ColorUtils.slate400),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreAndPredicate() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: CompactTextField(
            label: 'Nilai',
            initialValue: scoreValue,
            isNumber: true,
            onChanged: onScoreChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: CompactTextField(
            label: 'Predikat',
            initialValue: predicateValue,
            onChanged: onPredicateChanged,
          ),
        ),
      ],
    );
  }
}
