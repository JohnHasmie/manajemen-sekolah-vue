import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_ui_helpers_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_form_sheet.dart';

mixin TeacherActivityNavigationMixin
    on ConsumerState<TeacherClassActivityScreen>
    implements TeacherActivityUIHelpersMixin {
  final _dio = getIt<Dio>();

  void openActivityList({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  }) {
    AppDraggableSheet.show<void>(
      context: context,
      builder: (_, _) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: EmbeddedActivityListScreen(
          teacherId: teacherId,
          teacherName: teacherName,
          classId: classId,
          className: className,
          subjectId: subjectId,
          subjectName: subjectName,
        ),
      ),
    );
  }

  /// Opens the redesigned single-step "Tambah Kegiatan" sheet —
  /// Frame B from `_design/teacher_class_activity_mockup.html`.
  ///
  /// One sheet collapses what used to be two steps (class+mapel
  /// picker → type selector). It reuses [showActivityFormSheet] so
  /// add and edit share the same widget; passing `initial: null`
  /// puts it in add mode (class+mapel pickers unlocked, primary =
  /// "Simpan").
  ///
  /// Subjects are pre-fetched across all of the teacher's classes
  /// upfront. The picker isn't class-scoped because the form widget
  /// holds `subjects` as a static list — minor UX downgrade vs the
  /// legacy class-driven refetch, but the backend validates the
  /// (class_id, subject_id) pair on save.
  Future<void> showAddActivityFlow(LanguageProvider lp) async {
    final classes = classList
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    // Fetch all subjects the teacher teaches. Best-effort — if it
    // fails, fall back to an empty list and let the user retry from
    // an error state inside the picker.
    List<Map<String, dynamic>> subjects = const [];
    try {
      final r = await _dio.get('/teacher/$teacherId/subjects');
      final raw = r.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : const []);
      subjects = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      // Non-fatal — sheet still opens with an empty subject list.
    }

    if (!mounted) return;

    final svc = getIt<ApiClassActivityService>();
    final res = await showActivityFormSheet(
      context: context,
      classes: classes,
      subjects: subjects,
      onSave: (payload) async {
        await svc.createActivity({...payload, 'teacher_id': teacherId});
      },
    );
    if (res != null && mounted) {
      SnackBarUtils.showSuccess(
        context,
        lp.getTranslatedText({
          'en': 'Activity saved',
          'id': 'Kegiatan tersimpan',
        }),
      );
      await forceRefresh();
    }
  }

  void showActivityTypeSelector(
    String classId,
    String className,
    String subjectId,
    String subjectName,
    LanguageProvider lp, {
    String? lessonHourId,
  });

  void showFilterDialog(LanguageProvider lp);

  List<dynamic> get classList;
  @override
  Color get primaryColor;
  String get teacherId;
  String get teacherName;
  bool get isHomeroomView;

  /// Reloads the activity list. Provided by the data-loading mixin
  /// composed into the same state — declared abstract here so the
  /// nav mixin can refresh after a save without knowing the source.
  Future<void> forceRefresh();
}
