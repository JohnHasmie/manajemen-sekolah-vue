// Essay quiz card displayed in the Kuis tab.
// Shows question number, difficulty badge, question text, answer key,
// and an optional scoring guidance (penilaian) box.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single essay quiz card.
///
/// Like a Vue list-item component: receives [index] and [quiz] as props
/// and renders a fully self-contained card with no callbacks needed.
class EssayQuizCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> quiz;

  const EssayQuizCard({
    super.key,
    required this.index,
    required this.quiz,
  });

  ({Color color, String label}) _difficultyConfig(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return (color: ColorUtils.emerald500, label: 'Mudah');
      case 'medium':
        return (color: ColorUtils.amber500, label: 'Sedang');
      case 'hard':
        return (color: ColorUtils.red500, label: 'Sulit');
      default:
        return (color: ColorUtils.slate500, label: difficulty.toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final difficulty = quiz['difficulty']?.toString().toLowerCase() ?? '';
    final diffConfig = _difficultyConfig(difficulty);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: ColorUtils.violet500.withValues(alpha: 0.03),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ColorUtils.violet500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.violet500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Essay ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: diffConfig.color.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    diffConfig.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate900,
                height: 1.5,
              ),
            ),
          ),
          // Answer key
          if (quiz['correct_answer'] != null) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ColorUtils.emerald500.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColorUtils.emerald500.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.key_rounded,
                        size: 14,
                        color: ColorUtils.emerald500,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Kunci Jawaban',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    quiz['correct_answer'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Explanation / Penilaian
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ColorUtils.violet500.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColorUtils.violet500.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.grading_rounded,
                    size: 14,
                    color: ColorUtils.violet500.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: 6),
        ],
      ),
    );
  }
}
