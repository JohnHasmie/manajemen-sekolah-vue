// "Kuis" tab content for the AI material result screen.
// Lists all quiz questions and provides an "Add Quiz" action button.
// Like a Vue `<QuizTab :quizzes :materialId :isRegenerating @addQuiz />` component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_quiz_card.dart';

/// Renders the full "Kuis" tab: an optional header row with quiz count and
/// "Tambah Kuis" button, then a scrollable list of [MaterialQuizCard]s.
///
/// When [quizzes] is empty, a friendly empty-state is shown instead.
/// The "Tambah Kuis" button is disabled while [isRegenerating] is true,
/// mirroring the screen's loading guard (like a Vue `v-bind:disabled`).
class MaterialQuizTab extends StatelessWidget {
  /// List of raw quiz data maps from the AI API.
  final List<dynamic> quizzes;

  /// The server-assigned material ID; the header row is hidden when null.
  final String? materialId;

  /// Whether a regeneration request is currently in flight.
  /// Disables the "Tambah Kuis" button when true.
  final bool isRegenerating;

  /// Accent colour for interactive elements (button text, icons).
  final Color primaryColor;

  /// Called when the user taps "Tambah Kuis".
  /// Parent handles the actual API call and state update.
  final VoidCallback onAddQuiz;

  const MaterialQuizTab({
    super.key,
    required this.quizzes,
    required this.materialId,
    required this.isRegenerating,
    required this.primaryColor,
    required this.onAddQuiz,
  });

  @override
  Widget build(BuildContext context) {
    // Empty state — like Vue `v-if="quizzes.length === 0"`
    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: ColorUtils.slate300),
            SizedBox(height: AppSpacing.md),
            Text(
              'Belum ada kuis',
              style: TextStyle(color: ColorUtils.slate500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row: count + add-quiz button (only when materialId is known)
        if (materialId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${quizzes.length} Pertanyaan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                  ),
                ),
                TextButton.icon(
                  onPressed: isRegenerating ? null : onAddQuiz,
                  icon: Icon(Icons.add, size: 16, color: primaryColor),
                  label: Text(
                    'Tambah Kuis',
                    style: TextStyle(fontSize: 12, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
        // Scrollable quiz list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(AppSpacing.lg),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              return MaterialQuizCard(
                index: index,
                quiz: Map<String, dynamic>.from(quizzes[index]),
                primaryColor: primaryColor,
              );
            },
          ),
        ),
      ],
    );
  }
}
