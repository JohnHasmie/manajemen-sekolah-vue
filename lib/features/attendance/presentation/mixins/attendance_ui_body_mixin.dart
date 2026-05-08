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
    Map<String, dynamic>? group,
  });

  void filterStudents();
  Future<void> loadSubjectsByClass(String? classId);
  Future<void> submitAttendance();
  void showQuickActionsSheet(LanguageProvider lp);

  /// Frame A "Daftar Siswa · N siswa" section head — provided by the
  /// embedded chrome mixin. Declared abstract here so the body mixin
  /// can reference it without depending on the embedded mixin file.
  Widget buildEmbeddedSectionHead(LanguageProvider lp);

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
            group: g is Map<String, dynamic> ? g : Map<String, dynamic>.from(g),
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
      // Frame A — only embedded sheet shows the section head; the
      // standalone Take Attendance tab uses its own header chrome.
      sectionHead: widget.embedded ? buildEmbeddedSectionHead(lp) : null,
      // Frame A bulk-row chips. Override every student → hadir, or fill
      // only the unmarked rows with alpa. Both stay null on the
      // standalone screen so the row stays hidden there.
      onMarkAllHadir: widget.embedded
          ? () {
              setState(() {
                for (final s in filteredStudentList) {
                  attendanceStatus[s.id] = 'hadir';
                }
              });
            }
          : null,
      onFillRemainingAlpa: widget.embedded
          ? () {
              setState(() {
                for (final s in filteredStudentList) {
                  final v = attendanceStatus[s.id];
                  if (v == null || v.isEmpty) {
                    attendanceStatus[s.id] = 'alpha';
                  }
                }
              });
            }
          : null,
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
            group: r is Map<String, dynamic>
                ? r
                : Map<String, dynamic>.from(r as Map),
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
    // FLATTEN per-session view. Each backend group has a `latest_records`
    // array of (date, lesson_hour, present, total) — the mockup wants one
    // card per session, not per class+subject. Expand each group into N
    // session items, carry the parent's identity fields, and bucket by
    // date (today / older).
    final today = DateTime.now();
    final pendingToday = <Map<String, dynamic>>[];
    final doneToday = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];

    Map<String, dynamic> sessionItemFromGroup(
      Map<String, dynamic> g,
      Map session,
    ) {
      final present = (session['present'] as num?)?.toInt() ?? 0;
      final total = (session['total'] as num?)?.toInt() ?? 0;
      final pct = total > 0 ? (present / total * 100) : 0.0;
      return {
        'class_id': g['class_id'],
        'class_name': g['class_name'],
        'subject_id': g['subject_id'],
        'subject_name': g['subject_name'],
        'teacher_id': g['teacher_id'],
        'teacher_name': g['teacher_name'],
        'date': session['date'],
        'lesson_hour_id': session['lesson_hour_id'],
        'lesson_hour_name': session['lesson_hour_name'],
        'start_time': session['start_time'],
        'end_time': session['end_time'],
        'present': present,
        'total': total,
        'pct': pct,
        'status': total == 0 ? 'pending' : 'recorded',
        // Carry parent group so navigation can use latest_records[0]
        // fallback when needed.
        '__parent_group': g,
      };
    }

    for (final raw in groupedAttendance) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);
      final latest = (g['latest_records'] as List?) ?? const [];
      if (latest.isEmpty) {
        // No recorded sessions yet — surface a single "Belum" card so the
        // teacher sees the slot exists.
        final dateStr = (g['latest_date'] ?? g['date'] ?? '').toString();
        final fallback = sessionItemFromGroup(g, {
          'date': dateStr,
          'lesson_hour_id': null,
          'lesson_hour_name': null,
          'present': 0,
          'total': 0,
        });
        final d = DateTime.tryParse(dateStr);
        final isToday =
            d != null &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        if (isToday) {
          pendingToday.add(fallback);
        } else {
          other.add(fallback);
        }
        continue;
      }
      for (final s in latest) {
        if (s is! Map) continue;
        final item = sessionItemFromGroup(g, s);
        final dateStr = (item['date'] ?? '').toString();
        final d = DateTime.tryParse(dateStr);
        final isToday =
            d != null &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        final recorded = (item['total'] as int) > 0;
        if (isToday && !recorded) {
          pendingToday.add(item);
        } else if (isToday) {
          doneToday.add(item);
        } else {
          other.add(item);
        }
      }
    }

    // Sort each bucket by date desc, then lesson hour asc (Jam ke-1 first).
    int sessionSorter(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ad = DateTime.tryParse((a['date'] ?? '').toString());
      final bd = DateTime.tryParse((b['date'] ?? '').toString());
      if (ad != null && bd != null && ad != bd) return bd.compareTo(ad);
      final aLh = (a['lesson_hour_name'] ?? '').toString();
      final bLh = (b['lesson_hour_name'] ?? '').toString();
      return aLh.compareTo(bLh);
    }

    pendingToday.sort(sessionSorter);
    doneToday.sort(sessionSorter);
    other.sort(sessionSorter);

    // Per-session card matching the brand mockup card row:
    //   `[icon] [Mapel · Class / Day · Time · Jam ke-N] [pill]`.
    Widget cardFor(Map<String, dynamic> s, {required bool pending}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AttendanceMockupCard(
        group: s,
        pending: pending,
        primaryColor: primaryColor,
        onTap: () {
          // Navigate using the SESSION's date + lesson hour, not the
          // parent group's "latest" — that ensures tapping any card in
          // "Sesi sebelumnya" lands on THAT specific session.
          final sessionPayload = <String, dynamic>{
            ...s,
            'latest_records': [
              {
                'date': s['date'],
                'lesson_hour_id': s['lesson_hour_id'],
                'lesson_hour_name': s['lesson_hour_name'],
                'present': s['present'],
                'total': s['total'],
              },
            ],
          };
          openAttendanceDetail(
            classId: s['class_id']?.toString() ?? '',
            className: s['class_name']?.toString() ?? '',
            subjectId: s['subject_id']?.toString() ?? '',
            subjectName: s['subject_name']?.toString() ?? '',
            teacherId: s['teacher_id']?.toString(),
            group: sessionPayload,
          );
        },
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
            for (final g in pendingToday) cardFor(g, pending: true),
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
            for (final g in doneToday) cardFor(g, pending: false),
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
            for (final g in other) cardFor(g, pending: false),
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
                group: r is Map<String, dynamic>
                    ? r
                    : Map<String, dynamic>.from(r as Map),
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

/// Compact session card for the brand-migrated Presensi screen,
/// matching mockup frame 01:
/// `[icon] [Mapel · Kelas / Day · Time · Jam ke-N] [pill]`.
///
/// Each card represents ONE scheduled session (date + lesson hour),
/// not a class+subject aggregate. The pill is "Belum" amber when
/// `pending` (no records yet), `{pct}%` green when fully recorded
/// with everyone present, or amber `{pct}%` when partial.
class _AttendanceMockupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool pending;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AttendanceMockupCard({
    required this.group,
    required this.pending,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject = (group['subject_name'] ?? '-').toString();
    final klass = (group['class_name'] ?? '-').toString();
    final dateStr =
        (group['date'] ?? group['latest_date'] ?? group['tanggal'] ?? '')
            .toString();
    final pct = (group['pct'] as num?)?.toDouble() ?? 0.0;
    final present = (group['present'] as num?)?.toInt() ?? 0;
    final total = (group['total'] as num?)?.toInt() ?? 0;
    final teacherName = (group['teacher_name'] ?? '').toString().trim();

    final iconBg = pending ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE);
    final iconFg = pending ? const Color(0xFFB45309) : ColorUtils.brandCobalt;
    final initial = subject.isEmpty
        ? '?'
        : subject.substring(0, 1).toUpperCase();

    String pillText;
    Color pillBg;
    Color pillFg;
    if (pending || total == 0) {
      pillText = 'Belum';
      pillBg = const Color(0xFFFEF3C7);
      pillFg = const Color(0xFFB45309);
    } else if (present == total) {
      pillText = '100%';
      pillBg = const Color(0xFFDCFCE7);
      pillFg = const Color(0xFF15803D);
    } else if (pct >= 80) {
      pillText = '${pct.toStringAsFixed(0)}%';
      pillBg = const Color(0xFFDCFCE7);
      pillFg = const Color(0xFF15803D);
    } else if (pct >= 60) {
      pillText = '${pct.toStringAsFixed(0)}%';
      pillBg = const Color(0xFFFEF3C7);
      pillFg = const Color(0xFFB45309);
    } else {
      pillText = '${pct.toStringAsFixed(0)}%';
      pillBg = const Color(0xFFFEE2E2);
      pillFg = const Color(0xFFB91C1C);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200, width: 0.75),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: iconFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$subject · $klass',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(
                        dateStr: dateStr,
                        lessonHourName: (group['lesson_hour_name'] ?? '')
                            .toString()
                            .trim(),
                        startTime: (group['start_time'] ?? '')
                            .toString()
                            .trim(),
                        endTime: (group['end_time'] ?? '').toString().trim(),
                        // In wali-kelas mode the backend tags every
                        // row with the recording teacher (the guru
                        // who taught that class·subject·session) so
                        // the wali can spot which guru hasn't filled
                        // their slot. Surface that name as the lead
                        // of the subtitle when present.
                        teacherName: teacherName,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: pillFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle({
    required String dateStr,
    String lessonHourName = '',
    String startTime = '',
    String endTime = '',
    String teacherName = '',
  }) {
    final parts = <String>[];
    if (teacherName.isNotEmpty && teacherName != '-') {
      parts.add(teacherName);
    }
    final d = DateTime.tryParse(dateStr);
    if (d != null) parts.add(_fmtDate(d));
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      parts.add('${_clipTime(startTime)} – ${_clipTime(endTime)}');
    }
    if (lessonHourName.isNotEmpty) parts.add(lessonHourName);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// Trim "HH:MM:SS" → "HH.MM" (Indonesian time formatting).
  String _clipTime(String s) {
    if (s.length >= 5) return s.substring(0, 5).replaceAll(':', '.');
    return s.replaceAll(':', '.');
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Hari ini';
    }
    if (d.year == today.year &&
        d.month == today.month &&
        d.day == today.day - 1) {
      return 'Kemarin';
    }
    return '${d.day} ${months[d.month - 1]}';
  }
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
