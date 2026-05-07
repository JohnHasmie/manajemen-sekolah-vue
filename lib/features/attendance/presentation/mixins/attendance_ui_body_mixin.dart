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
        // shrinkWrap: true → render as a sized Column instead of a
        // ListView with its own viewport. BrandPageLayout slots this
        // body into an outer sliver list that gives children
        // unbounded vertical space, which would otherwise blow up
        // the inner ListView's layout.
        child: SkeletonListLoading(
          itemCount: 6,
          infoTagCount: 2,
          showActions: false,
          shrinkWrap: true,
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
    // Group rows into 3 buckets so the body matches the mockup:
    //   • today + no records yet  → "Sesi belum diabsen"
    //   • today + records present → "Sesi selesai"
    //   • everything else (older days, future) → "Lainnya"
    final today = DateTime.now();
    final pendingToday = <Map<String, dynamic>>[];
    final doneToday = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];
    for (final raw in groupedAttendance) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final dateStr = (m['latest_date'] ?? m['date'] ?? m['tanggal'] ?? '')
          .toString();
      final d = DateTime.tryParse(dateStr);
      final isToday =
          d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
      final recorded =
          (m['total_sessions'] ??
                  m['recorded_count'] ??
                  m['attendance_count'] ??
                  0)
              as num? ??
          0;
      if (isToday && recorded == 0) {
        pendingToday.add(m);
      } else if (isToday) {
        doneToday.add(m);
      } else {
        other.add(m);
      }
    }

    Widget cardFor(Map<String, dynamic> g) => AttendanceGroupCard(
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingToday.isNotEmpty) ...[
            _AttendanceSectionHeader(
              title: lp.getTranslatedText({
                'en': 'Sessions not yet recorded',
                'id': 'Sesi belum diabsen',
              }),
              trailing: '${pendingToday.length} sesi',
            ),
            const SizedBox(height: 8),
            for (final g in pendingToday) cardFor(g),
            const SizedBox(height: 18),
          ],
          if (doneToday.isNotEmpty) ...[
            _AttendanceSectionHeader(
              title: lp.getTranslatedText({
                'en': 'Sessions completed',
                'id': 'Sesi selesai',
              }),
              trailing: '${doneToday.length} sesi',
            ),
            const SizedBox(height: 8),
            for (final g in doneToday) cardFor(g),
            const SizedBox(height: 18),
          ],
          if (other.isNotEmpty) ...[
            _AttendanceSectionHeader(
              title: lp.getTranslatedText({
                'en': 'Older sessions',
                'id': 'Sesi sebelumnya',
              }),
              trailing: '${other.length}',
            ),
            const SizedBox(height: 8),
            for (final g in other) cardFor(g),
          ],
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
        // shrinkWrap: true — see note in buildGroupedBodyForBrand.
        child: SkeletonListLoading(
          itemCount: 6,
          infoTagCount: 1,
          showActions: false,
          shrinkWrap: true,
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

/// Compact "Title · trailing" section heading used to break the
/// grouped attendance body into "Sesi belum diabsen" / "Sesi selesai" /
/// "Sesi sebelumnya" buckets — matches the v1 mockup.
class _AttendanceSectionHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _AttendanceSectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
