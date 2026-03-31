// Multiple-choice quiz card displayed in the Kuis tab.
// Shows question number, difficulty badge, question text, answer options
// with correct-answer highlighting, and an optional explanation box.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single multiple-choice quiz card.
///
/// Like a Vue list-item component: receives [index] and [quiz] as props
/// and renders a fully self-contained card with no callbacks needed.
class McQuizCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> quiz;
  final Color primaryColor;

  const McQuizCard({
    super.key,
    required this.index,
    required this.quiz,
    required this.primaryColor,
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
    final options = quiz['options'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pertanyaan ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
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
          // Question text
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
          // Options
          ...options.map((opt) {
            final option = opt as Map<String, dynamic>;
            final isCorrect = option['is_correct'] == true;
            return Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? ColorUtils.emerald500.withValues(alpha: 0.08)
                    : ColorUtils.slate50,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(
                  color: isCorrect
                      ? ColorUtils.emerald500.withValues(alpha: 0.3)
                      : ColorUtils.slate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? ColorUtils.emerald500.withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      border: Border.all(
                        color: isCorrect
                            ? ColorUtils.emerald500
                            : ColorUtils.slate300,
                      ),
                    ),
                    child: Center(
                      child: isCorrect
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: ColorUtils.emerald500,
                            )
                          : Text(
                              option['label'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option['text'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCorrect
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isCorrect
                            ? Color(0xFF059669)
                            : ColorUtils.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Explanation
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ColorUtils.corporateBlue500.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(
                  color: ColorUtils.corporateBlue500.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: ColorUtils.corporateBlue500.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
