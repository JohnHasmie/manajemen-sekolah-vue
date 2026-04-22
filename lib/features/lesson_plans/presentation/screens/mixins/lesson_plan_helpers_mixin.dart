// Helper methods and getters mixin.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';

/// Provides helper methods and computed getters.
mixin LessonPlanHelpersMixin {
  /// Required abstract members from State.
  void setState(VoidCallback fn);

  /// State properties from main class.
  Map<String, dynamic> get lessonPlanData;

  /// Get display title from lesson plan data.
  String getDisplayTitle() {
    final title = LessonPlan.fromJson(lessonPlanData).title;
    return title.isNotEmpty ? title : 'RPP';
  }

  /// Get teacher ID from lesson plan data.
  String get teacherId =>
      (lessonPlanData['guru_id'] ?? lessonPlanData['teacher_id'] ?? '')
          .toString();

  /// Check if lesson plan has AI additional data.
  bool get hasAiAdditionalData {
    const aiKeys = [
      'core_competence',
      'basic_competence',
      'indicator',
      'learning_objective',
      'main_material',
      'learning_method',
      'media_tools',
      'learning_source',
      'learning_activities',
      'assessment',
      'ai_model_used',
      'ai_tokens_used',
      'ai_generated',
      'is_ai_generated',
      // Indonesian alt keys (from AI generate form)
      'kompetensi_inti',
      'kompetensi_dasar',
      'tujuan_pembelajaran',
      'kegiatan_inti',
      'penilaian',
    ];
    return aiKeys.any((key) {
      final value = lessonPlanData[key];
      if (value is bool) return value;
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  /// Strip HTML tags from content.
  String stripHtml(String html) => LessonPlanContentFormatter.stripHtml(html);

  /// Format lesson plan content.
  String formatLessonPlanContent() =>
      LessonPlanContentFormatter.format(lessonPlanData);
}
