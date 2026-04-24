import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_actions_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_detail_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Handles view toggle, bottom sheet navigation, and
/// core action flows for the teacher attendance screen.
mixin AttendanceNavigationMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──

  Color get primaryColor;
  String get teacherId;
  String get teacherNama;
  List<dynamic> get classList;
  List<dynamic> get lessonHours;
  List<Student> get filteredStudentList;
  Map<String, String> get attendanceStatus;
  bool get isHomeroomView;
  bool get isTimelineView;
  set isTimelineView(bool v);

  List<dynamic> get timelineAttendance;
  set timelineAttendance(List<dynamic> v);
  bool get timelineHasMore;
  set timelineHasMore(bool v);
  bool get timelineLoadingMore;
  set timelineLoadingMore(bool v);

  Future<void> refreshGroupedAttendance();
  Future<void> refreshTimeline();
  Future<void> loadMoreGroupedAttendance();
  void detectLessonHour();

  // ═══════════════════════════════════════════
  // CORE NAVIGATION & ACTIONS
  // ═══════════════════════════════════════════

  @override
  void toggleView() {
    setState(() => isTimelineView = !isTimelineView);
    LocalCacheService.save('absensi_view_preference', {
      'is_timeline': isTimelineView,
    });
    if (isTimelineView && timelineAttendance.isEmpty) {
      refreshTimeline();
    }
  }

  @override
  void openAttendanceDetail({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? teacherId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, sc) => AttendanceDetailSheet(
          teacherId: this.teacherId,
          teacherNama: this.teacherNama,
          classId: classId,
          className: className,
          subjectId: subjectId,
          subjectName: subjectName,
          filterTeacherId:
              teacherId ?? (isHomeroomView ? null : this.teacherId),
          lessonHours: lessonHours,
          classList: classList,
          primaryColor: primaryColor,
          languageProvider: ref.read(languageRiverpod),
          canEdit: !isHomeroomView,
        ),
      ),
    ).then((_) => refreshGroupedAttendance());
  }

  @override
  void openInputSheet({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, sc) => AttendancePage(
          teacher: {'id': teacherId, 'nama': teacherNama},
          initialDate: DateTime.now(),
          initialSubjectId: subjectId,
          initialSubjectName: subjectName,
          initialclassId: classId,
          initialClassName: className,
          initialTabIndex: 1,
          embedded: true,
          scrollController: sc,
        ),
      ),
    ).then((_) => refreshGroupedAttendance());
  }

  @override
  void showQuickActionsSheet(LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceQuickActionsSheet(
        languageProvider: lp,
        onStatusSelected: (status) {
          setState(() {
            for (final s in filteredStudentList) {
              attendanceStatus[s.id] = status;
            }
          });
        },
      ),
    );
  }

  @override
  void detectCurrentLessonHour() => detectLessonHour();

  @override
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('presence_');
    if (isTimelineView) {
      await refreshTimeline();
    } else {
      await refreshGroupedAttendance();
    }
  }
}
