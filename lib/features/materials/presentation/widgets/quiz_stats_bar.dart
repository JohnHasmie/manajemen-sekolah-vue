// Stats summary bar shown at the top of the Kuis tab.
// Displays total count, PG/Essay breakdown, and difficulty dot indicators
// for a list of quiz items in a single horizontal row.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/stat_summary_card.dart';

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
    final mc = quizzes
        .where((q) => q['question_type'] == 'multiple_choice')
        .length;
    final essay = quizzes.where((q) => q['question_type'] == 'essay').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate200.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: ColorUtils.slate200.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatSummaryRow(
            padding: EdgeInsets.zero,
            spacing: 0,
            cards: [
              StatSummaryCard(
                icon: Icons.functions_rounded,
                label: 'Total Kuis',
                value: '${quizzes.length}',
                color: primaryColor,
              ),
              StatSummaryCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Pilihan Ganda',
                value: '$mc',
                color: ColorUtils.corporateBlue600,
              ),
              StatSummaryCard(
                icon: Icons.edit_note_rounded,
                label: 'Essay',
                value: '$essay',
                color: ColorUtils.info600,
              ),
            ],
          ),
          if (easy > 0 || medium > 0 || hard > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: ColorUtils.slate100),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tingkat Kesulitan:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _DiffBadge(label: 'Mudah', count: easy, color: Colors.green),
                  if (medium > 0) const SizedBox(width: 8),
                  _DiffBadge(
                    label: 'Sedang',
                    count: medium,
                    color: Colors.orange,
                  ),
                  if (hard > 0) const SizedBox(width: 8),
                  _DiffBadge(label: 'Sulit', count: hard, color: Colors.red),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _DiffBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
