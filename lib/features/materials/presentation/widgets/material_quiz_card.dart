// Card widget displaying a single AI-generated quiz question with options and answer key.
// Used inside the "Kuis" tab of [MaterialAiResultScreen].
// Like a Vue `<QuizCard :index="idx" :quiz="quiz" />` presentational component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Renders a single quiz question card with difficulty badge, question text,
/// multiple-choice options (with correct answer highlighted), and the answer
/// key / explanation block.
///
/// All data is passed as constructor params — no state access, no callbacks.
/// This is a pure display widget (like a dumb Vue component receiving props).
class MaterialQuizCard extends StatelessWidget {
  /// 0-based index of this question in the quiz list (displayed as "Pertanyaan N+1").
  final int index;

  /// Raw quiz data map from the AI API, expected keys:
  /// `question`, `question_type`, `difficulty`, `options` (List),
  /// `correct_answer`, `explanation`.
  final Map<String, dynamic> quiz;

  /// Primary accent colour used for subtle UI elements.
  final Color primaryColor;

  const MaterialQuizCard({
    super.key,
    required this.index,
    required this.quiz,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Determine difficulty badge colour
    // Like a computed property in Vue: `diffColor() { ... }`
    Color diffColor = Colors.grey;
    final String difficulty =
        quiz['difficulty']?.toString().toLowerCase() ?? '';
    if (difficulty == 'easy') {
      diffColor = Colors.green;
    } else if (difficulty == 'medium') {
      diffColor = Colors.orange;
    } else if (difficulty == 'hard') {
      diffColor = Colors.red;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: question number + type & difficulty badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pertanyaan ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate500,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    // Question-type badge (e.g. MULTIPLE CHOICE)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quiz['question_type']
                                ?.toString()
                                .replaceAll('_', ' ')
                                .toUpperCase() ??
                            'KUIS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Difficulty badge (EASY / MEDIUM / HARD)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: diffColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        difficulty.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            // Question text
            Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: ColorUtils.slate800,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // Options list — only rendered when options exist
            if (quiz['options'] != null &&
                (quiz['options'] as List).isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (quiz['options'] as List).map((opt) {
                    final bool isCorrect =
                        opt.toString().trim() ==
                        quiz['correct_answer']?.toString().trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isCorrect
                                ? Colors.green
                                : ColorUtils.slate400,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              opt.toString(),
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.green.shade700
                                    : ColorUtils.slate700,
                                fontWeight: isCorrect
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: AppSpacing.md),
            ],
            // Answer key + optional explanation block
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunci Jawaban:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    quiz['correct_answer'] ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                  if (quiz['explanation'] != null) ...[
                    SizedBox(height: AppSpacing.sm),
                    Divider(color: Colors.green.shade200),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Penjelasan:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
