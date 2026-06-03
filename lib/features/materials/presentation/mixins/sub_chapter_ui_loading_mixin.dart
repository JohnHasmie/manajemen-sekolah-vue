// Loading state UI helpers for sub-chapter detail screen.
//
// Provides reusable loading state widgets for material, quiz, and reference
// tabs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing loading state widgets for Sub-chapter detail screen.
///
/// Use with `on State<Widget>` or `on ConsumerState<ScreenWidget>`.
mixin SubChapterUiLoadingMixin on ConsumerState<SubBabDetailPage> {
  /// Builds a centered loading state with spinner and message.
  Widget buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Builds quiz loading state with stats placeholder and loading center.
  Widget buildQuizLoadingState(List<Map<String, dynamic>> quizzes) {
    return Column(
      children: [
        if (quizzes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: buildQuizStatsPlaceholder(quizzes),
          ),
        ],
        const Expanded(child: _QuizLoadingCenter()),
      ],
    );
  }

  /// Builds the stats placeholder for quiz loading state.
  Widget buildQuizStatsPlaceholder(List<Map<String, dynamic>> quizzes) {
    return SizedBox(
      height: 50,
      child: Center(
        child: Text(
          '${quizzes.length} kuis tersimpan',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
      ),
    );
  }
}

/// Centered loading spinner with message for quiz additions.
class _QuizLoadingCenter extends StatelessWidget {
  const _QuizLoadingCenter();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Menambahkan kuis baru...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
