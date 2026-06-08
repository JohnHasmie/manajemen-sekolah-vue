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
  /// The form scopes its Mapel + Jam (jam-pelajaran) pickers to the
  /// teacher's own teaching schedule (passed via `schedules`): the
  /// Mapel picker only offers subjects the teacher teaches in the
  /// selected class, and the WAKTU field becomes a "Jam ke-N" picker
  /// for the selected class + day — not all school subjects / a free
  /// clock. See [ActivityScheduleOptions].
  Future<void> showAddActivityFlow(LanguageProvider lp) async {
    final classes = classList
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    // Fetch all subjects the teacher teaches. Best-effort — used as a
    // fallback label source; the form derives the picker options from
    // `schedules` when present. If it fails, fall back to an empty
    // list.
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
      schedules: schedules,
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

  /// Teacher's teaching schedule — forwarded to the form so its Mapel
  /// + Jam pickers can be scoped per class / per day. Provided by the
  /// state mixin composed into the same screen state.
  List<dynamic> get schedules;
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
