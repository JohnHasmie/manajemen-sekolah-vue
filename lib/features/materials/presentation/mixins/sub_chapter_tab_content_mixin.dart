// Tab content builders for sub-chapter detail screen.
//
// Provides methods to build material, quiz, and reference tab content.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/empty_tab_state.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_tab_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/reference_tab_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_quiz_list.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing tab content building methods for sub-chapter detail screen.
///
/// Use with `on State<Widget>` or `on ConsumerState<ScreenWidget>`.
mixin SubChapterTabContentMixin on ConsumerState<SubBabDetailPage> {
  /// Abstract getter for primary color - must be implemented by consumer.
  Color getPrimaryColor();

  /// Abstract getter for parsed material content - must be implemented by
  /// consumer.
  Map<String, dynamic>? parseMaterialContent(Map<String, dynamic>? data);

  /// Abstract getter for HTML stripping function - must be implemented by
  /// consumer.
  String stripHtml(String html);

  /// Callback when AI result is tapped - must be implemented by consumer.
  void onAiResultTap();

  /// Callback when a per-card pencil is tapped — opens the section
  /// editor sheet. Optional: only wired by `SubBabDetailPage`.
  void onEditSection(String fieldKey, String fieldLabel, String currentValue) {
    // Default no-op; the screen overrides this to open the editor.
  }

  /// Builds the material tab content.
  Widget buildMaterialTab(
    bool isRegeneratingMateri,
    Map<String, dynamic>? aiGeneratedData,
    List<dynamic> contentList,
    Widget Function(String) buildLoadingState,
  ) {
    if (isRegeneratingMateri) {
      return buildLoadingState('Memperbarui materi...');
    }
    return MaterialTabContent(
      parsedContent: parseMaterialContent(aiGeneratedData),
      aiGeneratedData: aiGeneratedData,
      contentList: contentList,
      primaryColor: getPrimaryColor(),
      stripHtml: stripHtml,
      onRegenerateTap: onAiResultTap,
      onEditSection: onEditSection,
    );
  }

  /// Builds the quiz (kuis) tab content.
  Widget buildKuisTab(
    bool isAddingQuiz,
    List<Map<String, dynamic>> quizzes,
    Widget Function(List<Map<String, dynamic>>) buildQuizLoadingState,
  ) {
    if (isAddingQuiz) {
      return buildQuizLoadingState(quizzes);
    }
    if (quizzes.isEmpty) {
      return EmptyTabState(
        icon: Icons.quiz_rounded,
        title: 'Belum Ada Kuis',
        subtitle: 'Generate materi AI untuk mendapatkan kuis otomatis.',
        primaryColor: getPrimaryColor(),
        onGenerateTap: onAiResultTap,
      );
    }

    return SubChapterQuizList(
      quizzes: quizzes,
      primaryColor: getPrimaryColor(),
    );
  }

  /// Builds the reference (referensi) tab content.
  Widget buildReferensiTab(
    bool isRegeneratingRef,
    List<Map<String, dynamic>> references,
    Widget Function(String) buildLoadingState,
  ) {
    if (isRegeneratingRef) {
      return buildLoadingState('Memperbarui referensi...');
    }
    return ReferenceTabContent(
      references: references,
      primaryColor: getPrimaryColor(),
      stripHtml: stripHtml,
      onEmptyGenerateTap: onAiResultTap,
    );
  }
}
