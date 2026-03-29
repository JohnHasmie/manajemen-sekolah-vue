// Stats summary bar shown at the top of the Kuis tab.
// Displays total count, PG/Essay breakdown, and difficulty dot indicators
// for a list of quiz items in a single horizontal row.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Horizontal stats bar summarising a quiz list by type and difficulty.
///
/// Like a Vue computed-property display: all values are derived from
/// the [quizzes] list prop with no internal state needed.
class QuizStatsBar extends StatelessWidget {
  final List<Map<String, dynamic>> quizzes;
  final Color primaryColor;

  const QuizStatsBar({
    super.key,
    required this.quizzes,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final easy = quizzes.where((q) => q['difficulty'] == 'easy').length;
    final medium = quizzes.where((q) => q['difficulty'] == 'medium').length;
    final hard = quizzes.where((q) => q['difficulty'] == 'hard').length;
    final mc =
        quizzes.where((q) => q['question_type'] == 'multiple_choice').length;
    final essay =
        quizzes.where((q) => q['question_type'] == 'essay').length;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.08),
            primaryColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _StatItem(label: 'Total', value: '${quizzes.length}', color: primaryColor),
          _StatDivider(),
          _StatItem(label: 'PG', value: '$mc', color: ColorUtils.corporateBlue600),
          _StatDivider(),
          _StatItem(label: 'Essay', value: '$essay', color: ColorUtils.violet500),
          _StatDivider(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DiffDot(color: Colors.green, count: easy),
                SizedBox(width: 6),
                _DiffDot(color: Colors.orange, count: medium),
                SizedBox(width: 6),
                _DiffDot(color: Colors.red, count: hard),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets (file-local, not exported)
// ---------------------------------------------------------------------------

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: ColorUtils.slate200);
  }
}

class _DiffDot extends StatelessWidget {
  final Color color;
  final int count;

  const _DiffDot({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }
}
