import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/quiz_stats_bar.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mc_quiz_card.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/essay_quiz_card.dart';

/// Quiz list content for sub-chapter detail screen.
class SubChapterQuizList extends StatelessWidget {
  final List<Map<String, dynamic>> quizzes;
  final Color primaryColor;

  const SubChapterQuizList({
    super.key,
    required this.quizzes,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final mcQuizzes = quizzes
        .where((q) => q['question_type'] == 'multiple_choice')
        .toList();
    final essayQuizzes = quizzes
        .where((q) => q['question_type'] == 'essay')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        QuizStatsBar(quizzes: quizzes, primaryColor: primaryColor),
        const SizedBox(height: AppSpacing.lg),
        if (mcQuizzes.isNotEmpty) ..._buildMcSection(mcQuizzes),
        if (essayQuizzes.isNotEmpty) ..._buildEssaySection(essayQuizzes),
      ],
    );
  }

  List<Widget> _buildMcSection(List<Map<String, dynamic>> mcQuizzes) {
    return [
      _buildSubSectionHeader(
        icon: Icons.check_circle_outline_rounded,
        title: kMatMultipleChoice.tr,
        count: mcQuizzes.length,
        color: primaryColor,
      ),
      const SizedBox(height: 10),
      ...mcQuizzes.asMap().entries.map(
        (entry) => McQuizCard(
          index: entry.key,
          quiz: entry.value,
          primaryColor: primaryColor,
        ),
      ),
    ];
  }

  List<Widget> _buildEssaySection(List<Map<String, dynamic>> essayQuizzes) {
    return [
      const SizedBox(height: AppSpacing.lg),
      _buildSubSectionHeader(
        icon: Icons.edit_note_rounded,
        title: kMatEssay.tr,
        count: essayQuizzes.length,
        color: ColorUtils.violet500,
      ),
      const SizedBox(height: 10),
      ...essayQuizzes.asMap().entries.map(
        (entry) => EssayQuizCard(index: entry.key, quiz: entry.value),
      ),
    ];
  }

  Widget _buildSubSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.all(Radius.circular(7)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
