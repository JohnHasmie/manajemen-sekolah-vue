import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_group_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_form.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_mode.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_timeline_card.dart';

/// Builds body layouts and main content areas:
/// grouped attendance lists, timeline views,
/// input modes, and loading states.
mixin AttendanceUIBodyMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──
  Color get primaryColor;

  bool get isLoading;
  bool get isLoadingMore;
  bool get isTimelineView;
  bool get isLoadingInput;
  bool get isSubmitting;
  bool get compactMode;
  bool get hasActiveFilter;
  bool get timelineLoadingMore;
  bool get isHomeroomView;

  List<dynamic> get groupedAttendance;
  List<dynamic> get timelineAttendance;
  List<dynamic> get classList;
  List<dynamic> get lessonHours;
  List<dynamic> get subjectTeacher;
  List<Student> get filteredStudentList;

  Map<String, String> get attendanceStatus;

  String? get selectedClassId;
  String? get selectedSubjectId;
  DateTime get selectedDate;
  String? get selectedLessonHourId;
  TextEditingController get searchController;
  TextEditingController get searchInputController;

  ScrollController get timelineScrollController;
  ScrollController? get embeddedScrollController;

  // Methods to call
  Future<void> refreshGroupedAttendance();
  Future<void> refreshTimeline();

  void openAttendanceDetail({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? teacherId,
  });

  void filterStudents();
  Future<void> loadSubjectsByClass(String? classId);
  Future<void> submitAttendance();
  void showQuickActionsSheet(LanguageProvider lp);

  // ═══════════════════════════════════════════
  // MAIN BODY
  // ═══════════════════════════════════════════

  String? get attendanceErrorMessage;
  void setAttendanceError(String? message);

  Widget buildBody(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: attendanceErrorMessage,
      isEmpty: groupedAttendance.isEmpty,
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: lp.getTranslatedText({
        'en': 'No attendance yet',
        'id': 'Belum ada presensi',
      }),
      emptySubtitle: searchController.text.isNotEmpty || hasActiveFilter
          ? lp.getTranslatedText({
              'en': 'No attendance matches your filter',
              'id': 'Tidak ada presensi sesuai filter',
            })
          : lp.getTranslatedText({
              'en': 'Pull down to refresh',
              'id': 'Tarik ke bawah untuk memuat ulang',
            }),
      emptyIcon: Icons.fact_check_outlined,
      childBuilder: _buildGroupedList,
    );
  }

  Widget _buildGroupedList() {
    final lp = ref.watch(languageRiverpod);
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: groupedAttendance.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedAttendance.length) {
          return _buildLoadingIndicator();
        }
        final g = groupedAttendance[index];
        return AttendanceGroupCard(
          group: g,
          primaryColor: primaryColor,
          languageProvider: lp,
          isHomeroomView: isHomeroomView,
          onTap: () => openAttendanceDetail(
            classId: g['class_id']?.toString() ?? '',
            className: g['class_name']?.toString() ?? '',
            subjectId: g['subject_id']?.toString() ?? '',
            subjectName: g['subject_name']?.toString() ?? '',
            teacherId: g['teacher_id']?.toString(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // INPUT MODE
  // ─────────────────────────────────────────

  Widget buildInputMode() {
    final lp = ref.watch(languageRiverpod);
    return AttendanceInputMode(
      isLoadingInput: isLoadingInput,
      inputFormWidget: AttendanceInputForm(
        selectedDate: selectedDate,
        selectedLessonHourId: selectedLessonHourId,
        lessonHours: lessonHours,
        selectedClassId: selectedClassId,
        classList: classList,
        selectedSubjectId: selectedSubjectId,
        subjectTeacher: subjectTeacher,
        primaryColor: primaryColor,
        languageProvider: lp,
        embedded: widget.embedded,
        initialClassName: widget.initialClassName,
        initialSubjectName: widget.initialSubjectName,
        initialLessonHourNumber: widget.initialLessonHourNumber,
        onDatePicked: (picked) {
          setState(() => setSelectedDate(picked));
        },
        onLessonHourChanged: (v) {
          setState(() => setSelectedLessonHourId(v));
        },
        onClassChanged: (v) {
          setState(() {
            setSelectedClassId(v);
            filterStudents();
          });
          loadSubjectsByClass(v);
        },
        onSubjectChanged: (v) {
          setState(() => setSelectedSubjectId(v));
        },
        onQuickActionsPressed: () => showQuickActionsSheet(lp),
      ),
      selectedSubjectId: selectedSubjectId,
      filteredStudentList: filteredStudentList,
      attendanceStatus: attendanceStatus,
      isSubmitting: isSubmitting,
      primaryColor: primaryColor,
      searchController: searchInputController,
      onSearchChanged: filterStudents,
      onQuickActionsPressed: () => showQuickActionsSheet(lp),
      onStatusChanged: (studentId, status) {
        setState(() => attendanceStatus[studentId] = status);
      },
      onSubmit: submitAttendance,
      scrollController: embeddedScrollController,
      compactMode: compactMode,
    );
  }

  // ─────────────────────────────────────────
  // TIMELINE BODY
  // ─────────────────────────────────────────

  Widget buildTimelineBody(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: attendanceErrorMessage,
      isEmpty: timelineAttendance.isEmpty,
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: lp.getTranslatedText({
        'en': 'No attendance records',
        'id': 'Belum ada data presensi',
      }),
      emptySubtitle: lp.getTranslatedText({
        'en': 'Pull down to refresh',
        'id': 'Tarik ke bawah untuk memuat ulang',
      }),
      emptyIcon: Icons.fact_check_outlined,
      childBuilder: () => _buildTimelineList(lp),
    );
  }

  Widget _buildTimelineList(LanguageProvider lp) {
    return ListView.builder(
      controller: timelineScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: timelineAttendance.length + (timelineLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == timelineAttendance.length) {
          return _buildLoadingIndicator();
        }
        final r = timelineAttendance[index];
        return AttendanceTimelineCard(
          record: r,
          primaryColor: primaryColor,
          languageProvider: lp,
          onTap: () => openAttendanceDetail(
            classId: (r['class_id'] ?? '').toString(),
            className: (r['class_name'] ?? r['subject_name'] ?? '').toString(),
            subjectId: (r['subject_id'] ?? '').toString(),
            subjectName: (r['subject_name'] ?? '').toString(),
            teacherId: r['teacher_id']?.toString(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(color: primaryColor)),
    );
  }

  // ═══════════════════════════════════════════
  // BRAND-LAYOUT-FRIENDLY BODIES
  // ═══════════════════════════════════════════
  //
  // [BrandPageLayout] owns the outer ListView, so the body must NOT
  // carry its own scroll or `RefreshIndicator`. These methods return
  // Column-friendly widgets that slot into [BrandPageLayout.bodyChildren]
  // directly. Loading / error / empty states render inline as
  // fixed-height widgets — pull-to-refresh comes from the layout's
  // `onRefresh`, pagination comes from the screen's scroll listener.

  /// Grouped attendance list rendered as a Column for use inside
  /// `BrandPageLayout.bodyChildren`. State branching:
  ///   • loading + empty → skeleton
  ///   • error           → AppErrorState
  ///   • empty           → EmptyState (fixed height)
  ///   • data            → Column of `AttendanceGroupCard`s + footer
  Widget buildGroupedBodyForBrand(LanguageProvider lp) {
    if (isLoading &&
        groupedAttendance.isEmpty &&
        attendanceErrorMessage == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SkeletonListLoading(
          itemCount: 6,
          infoTagCount: 2,
          showActions: false,
        ),
      );
    }
    if (attendanceErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AppErrorState(
          message: attendanceErrorMessage,
          onRetry: forceRefresh,
          role: 'guru',
        ),
      );
    }
    if (groupedAttendance.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          title: lp.getTranslatedText({
            'en': 'No attendance yet',
            'id': 'Belum ada presensi',
          }),
          subtitle: searchController.text.isNotEmpty || hasActiveFilter
              ? lp.getTranslatedText({
                  'en': 'No attendance matches your filter',
                  'id': 'Tidak ada presensi sesuai filter',
                })
              : lp.getTranslatedText({
                  'en': 'Pull down to refresh',
                  'id': 'Tarik ke bawah untuk memuat ulang',
                }),
          icon: Icons.fact_check_outlined,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in groupedAttendance)
            AttendanceGroupCard(
              group: g as Map<String, dynamic>,
              primaryColor: primaryColor,
              languageProvider: lp,
              isHomeroomView: isHomeroomView,
              onTap: () => openAttendanceDetail(
                classId: g['class_id']?.toString() ?? '',
                className: g['class_name']?.toString() ?? '',
                subjectId: g['subject_id']?.toString() ?? '',
                subjectName: g['subject_name']?.toString() ?? '',
                teacherId: g['teacher_id']?.toString(),
              ),
            ),
          if (isLoadingMore) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  /// Timeline list rendered as a Column for use inside
  /// `BrandPageLayout.bodyChildren`.
  Widget buildTimelineBodyForBrand(LanguageProvider lp) {
    if (isLoading &&
        timelineAttendance.isEmpty &&
        attendanceErrorMessage == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SkeletonListLoading(
          itemCount: 6,
          infoTagCount: 1,
          showActions: false,
        ),
      );
    }
    if (attendanceErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AppErrorState(
          message: attendanceErrorMessage,
          onRetry: forceRefresh,
          role: 'guru',
        ),
      );
    }
    if (timelineAttendance.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          title: lp.getTranslatedText({
            'en': 'No attendance records',
            'id': 'Belum ada data presensi',
          }),
          subtitle: lp.getTranslatedText({
            'en': 'Pull down to refresh',
            'id': 'Tarik ke bawah untuk memuat ulang',
          }),
          icon: Icons.fact_check_outlined,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in timelineAttendance)
            AttendanceTimelineCard(
              record: r as Map<String, dynamic>,
              primaryColor: primaryColor,
              languageProvider: lp,
              onTap: () => openAttendanceDetail(
                classId: (r['class_id'] ?? '').toString(),
                className: (r['class_name'] ?? r['subject_name'] ?? '')
                    .toString(),
                subjectId: (r['subject_id'] ?? '').toString(),
                subjectName: (r['subject_name'] ?? '').toString(),
                teacherId: r['teacher_id']?.toString(),
              ),
            ),
          if (timelineLoadingMore) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  // ── Subclass-specific accessors ──
  ScrollController get scrollController;
  Future<void> forceRefresh();
  void setSelectedDate(DateTime v);
  void setSelectedLessonHourId(String? v);
  void setSelectedClassId(String? v);
  void setSelectedSubjectId(String? v);
}
