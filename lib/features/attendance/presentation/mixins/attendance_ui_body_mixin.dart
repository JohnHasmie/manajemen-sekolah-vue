import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
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

  // ── Subclass-specific accessors ──
  ScrollController get scrollController;
  Future<void> forceRefresh();
  void setSelectedDate(DateTime v);
  void setSelectedLessonHourId(String? v);
  void setSelectedClassId(String? v);
  void setSelectedSubjectId(String? v);
}
