import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';

/// Mixin for CRUD operations on lesson plans (create, read, update, delete).
mixin LessonPlanCrudMixin on ConsumerState<LessonPlanScreen> {
  /// Abstract method: subclass provides refresh functionality.
  Future<void> forceRefresh();

  /// Abstract method: subclass provides list reload functionality.
  Future<void> loadLessonPlans({bool useCache = true});

  /// Abstract getter: subclass provides the teacher ID.
  String get teacherId => widget.teacherId;

  /// Shows the lesson plan form dialog for manual upload.
  ///
  /// QQ.H2 — dropped the outer `Padding(bottom: viewInsets.bottom)`
  /// wrapper. [LessonPlanFormDialog] already lifts itself above the
  /// keyboard internally (see its build method); the wrapper was
  /// double-padding and added stray whitespace when the keyboard
  /// appeared.
  void showLessonPlanFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LessonPlanFormDialog(teacherId: teacherId, onSaved: loadLessonPlans),
    );
  }

  /// Shows the AI generation form dialog.
  void showGenerateLessonPlanFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GenerateLessonPlanFormDialog(
        teacherId: teacherId,
        onSaved: forceRefresh,
      ),
    );
  }

  /// Opens the edit dialog for a lesson plan. Same QQ.H2 cleanup — the
  /// inner form dialog handles the keyboard inset itself, so no outer
  /// `Padding` wrapper is needed.
  void editLessonPlan(Map<String, dynamic> lessonPlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonPlanFormDialog(
        teacherId: teacherId,
        onSaved: loadLessonPlans,
        lessonPlanData: lessonPlan,
      ),
    );
  }

  /// Deletes a lesson plan after showing a confirmation dialog.
  Future<void> deleteLessonPlan(Map<String, dynamic> lessonPlan) async {
    final languageProvider = ref.read(languageRiverpod);
    final title = LessonPlan.fromJson(lessonPlan).title;
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Confirm Delete',
        'id': 'Konfirmasi Hapus',
      }),
      message: languageProvider.getTranslatedText({
        'en': 'Are you sure you want to delete RPP "$title"?',
        'id': 'Apakah Anda yakin ingin menghapus RPP "$title"?',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await LessonPlanService.deleteLessonPlan(lessonPlan['id']);
        loadLessonPlans(useCache: false);
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            languageProvider.getTranslatedText({
              'en': 'RPP deleted successfully',
              'id': 'RPP berhasil dihapus',
            }),
          );
        }
      } catch (e) {
        AppLogger.error('lesson_plan', 'Delete RPP error: $e');
        if (mounted) {
          final prefix = languageProvider.getTranslatedText({
            'en': 'Failed to delete RPP: ',
            'id': 'Gagal menghapus RPP: ',
          });
          SnackBarUtils.showError(
            context,
            '$prefix${ErrorUtils.getFriendlyMessage(e)}',
          );
        }
      }
    }
  }

  /// Navigates to the lesson plan detail view.
  Future<void> viewLessonPlanDetail(Map<String, dynamic> lessonPlan) async {
    final id = lessonPlan['id']?.toString();
    if (id == null || id.isEmpty) {
      SnackBarUtils.showError(
        context,
        ErrorUtils.getFriendlyMessage(Exception('RPP ID tidak tersedia')),
      );
      return;
    }

    try {
      final fullLessonPlan = await LessonPlanService.getLessonPlanById(id);
      if (mounted) {
        // Flat-flow bottom sheet (#145/RPP refactor) — detail + inline edit
        // live inside the sheet instead of a separate route.
        await RPPDetailPage.show(
          context: context,
          lessonPlanData: fullLessonPlan,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Fetch RPP detail error: $e');
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }
}
