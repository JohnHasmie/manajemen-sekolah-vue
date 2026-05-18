import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_form_sheet.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityScheduleMixin
    on ConsumerState<TeacherClassActivityScreen> {
  /// Finds the currently ongoing schedule and opens the create-activity
  /// dialog (FAB) directly with the exact class, subject, and lesson hour.
  /// Only called when navigating from the Akses Cepat shortcut.
  void autoOpenCurrentSchedule() {
    AppLogger.debug(
      'class_activity',
      'autoOpenCurrentSchedule called, schedules: ${schedules.length}',
    );
    if (schedules.isEmpty) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    // Match both Indonesian and English day names for robustness
    const wdId = {
      1: 'senin',
      2: 'selasa',
      3: 'rabu',
      4: 'kamis',
      5: 'jumat',
      6: 'sabtu',
    };
    const wdEn = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
    };
    final todayId = wdId[now.weekday] ?? '';
    final todayEn = wdEn[now.weekday] ?? '';

    for (final s in schedules) {
      final Map<String, dynamic> sm = s is Map<String, dynamic>
          ? s
          : <String, dynamic>{};
      final model = Schedule.fromJson(sm);

      // Schedule.fromJson normalizes nested day/hari maps into dayName
      final dn = (model.dayName ?? '').toLowerCase();
      AppLogger.debug(
        'class_activity',
        'Schedule: dayName=$dn, startTime=${model.startTime}, '
            'endTime=${model.endTime}, todayId=$todayId, nowMin=$nowMin',
      );
      if (!dn.contains(todayId) && !dn.contains(todayEn)) continue;

      final st = model.startTime;
      final et = model.endTime;
      if (st == null || et == null) continue;
      int toM(String t) {
        final p = t.replaceAll('.', ':').split(':');
        return p.length < 2
            ? 0
            : (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
      }

      final startMin = toM(st);
      final endMin = toM(et);
      AppLogger.debug(
        'class_activity',
        'Time check: nowMin=$nowMin, startMin=$startMin, endMin=$endMin, '
            'match=${nowMin >= startMin && nowMin < endMin}',
      );
      if (nowMin >= startMin && nowMin < endMin) {
        final cid = model.classId;
        final cn = model.className;
        final sid = model.subjectId;
        final sn = model.subjectName;
        final lessonHourId = model.lessonHourId;

        if (cid != null && sid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final lp = ref.read(languageRiverpod);
              showActivityTypeSelector(
                cid,
                cn ?? '',
                sid,
                sn ?? '',
                lp,
                lessonHourId: lessonHourId,
              );
            }
          });
          return;
        }
      }
    }
  }

  /// Auto-fired when the active teaching slot detection finds a
  /// matching schedule entry. Skips the legacy "Pilih Jenis Kegiatan"
  /// picker and opens the unified [showActivityFormSheet] (Frame B —
  /// "Tambah Kegiatan") with the slot's class + mapel pre-filled. The
  /// teacher picks the type inside the same sheet, so it's one less
  /// hop than the old two-step flow.
  Future<void> showActivityTypeSelector(
    String classId,
    String className,
    String subjectId,
    String subjectName,
    LanguageProvider lp, {
    String? lessonHourId,
  }) async {
    final svc = getIt<ApiClassActivityService>();
    final res = await showActivityFormSheet(
      context: context,
      classes: [
        {'id': classId, 'name': className},
      ],
      subjects: [
        {'id': subjectId, 'name': subjectName},
      ],
      initial: {
        'class_id': classId,
        'class_name': className,
        'subject_id': subjectId,
        'subject_name': subjectName,
        if (lessonHourId != null) 'lesson_hour_id': lessonHourId,
      },
      onSave: (payload) async {
        await svc.createActivity({
          ...payload,
          'teacher_id': teacherId,
          if (lessonHourId != null) 'lesson_hour_id': lessonHourId,
        });
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

  // Abstract getters and methods
  List<dynamic> get schedules;
  String get teacherId;
  String get teacherName;
  Color get primaryColor;

  void openActivityList({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  });

  Future<void> forceRefresh();
}
