// RPP detail bottom sheet — public dispatcher.
//
// At entry it inspects the lesson-plan payload once and routes to
// either:
//
//   • [AiRppDetailScreen]      (lib/features/lesson_plans/presentation
//                               /screens/ai/) for AI-generated plans —
//                               structured per-section editor + regen +
//                               AI-backend save.
//
//   • [ManualRppDetailScreen]  (.../manual/) for teacher-uploaded
//                               plans — file download + form-dialog
//                               edit + core-backend save.
//
// Call sites still go through `RPPDetailPage.show(...)` so the public
// surface is unchanged. The two screens never re-check the kind once
// running — that branching used to be sprinkled across the editor, the
// preview, and the save handler, and was the source of every "saves
// silently / UI flips after save" regression we hit.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/features/lesson_plans/presentation/screens/ai/ai_rpp_detail_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/manual/manual_rpp_detail_screen.dart';

/// Public entry point for opening a lesson-plan detail sheet.
///
/// Internally a dispatcher: the actual UI is in [AiRppDetailScreen]
/// or [ManualRppDetailScreen] depending on what the payload looks
/// like. The class survives only so existing call sites don't have
/// to change; new code can call the kind-specific screen directly.
class RPPDetailPage extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const RPPDetailPage({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  /// Opens the right detail sheet for [lessonPlanData].
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlanData,
    bool isNew = false,
  }) {
    if (_isAiGenerated(lessonPlanData)) {
      return AiRppDetailScreen.show(
        context: context,
        lessonPlanData: lessonPlanData,
        isNew: isNew,
      );
    }
    return ManualRppDetailScreen.show(
      context: context,
      lessonPlanData: lessonPlanData,
      isNew: isNew,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Direct widget construction is rare (call sites prefer .show())
    // but kept as a fallback so legacy `Navigator.push(RPPDetailPage(…))`
    // still works.
    if (_isAiGenerated(lessonPlanData)) {
      return AiRppDetailScreen(lessonPlanData: lessonPlanData, isNew: isNew);
    }
    return ManualRppDetailScreen(
      lessonPlanData: lessonPlanData,
      isNew: isNew,
    );
  }

  /// Inclusive AI detection. Any of:
  ///   • bookkeeping flag — ai_generated / is_ai_generated truthy,
  ///     ai_model_used / ai_tokens_used set, lesson_plan_ai_id set,
  ///   • AI-only relation pointers — chapter_id / sub_chapter_id set,
  ///   • any RPP content field carries text.
  ///
  /// Manually-uploaded RPPs leave all of these empty. The check is
  /// intentionally generous so the wrong screen never opens for an
  /// AI-generated plan whose backend response happens to omit a
  /// bookkeeping flag — silently routing to the manual screen would
  /// hide the regen banner and PATCH the wrong endpoint on save.
  static bool _isAiGenerated(Map<String, dynamic> data) {
    bool truthy(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s.isNotEmpty && s != 'false' && s != '0' && s != 'null';
      }
      return v != null;
    }

    const flagKeys = [
      'is_ai_generated',
      'ai_generated',
      'ai_model_used',
      'ai_tokens_used',
      'lesson_plan_ai_id',
      'chapter_id',
      'sub_chapter_id',
    ];
    for (final k in flagKeys) {
      if (truthy(data[k])) return true;
    }

    const contentKeys = [
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
    ];
    for (final k in contentKeys) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return true;
    }
    return false;
  }
}
