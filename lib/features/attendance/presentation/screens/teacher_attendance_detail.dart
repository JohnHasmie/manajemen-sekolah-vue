// Teacher attendance detail screen — extracted from teacher_attendance_screen.dart.
// Shows per-student attendance for a specific subject/class/date/lesson-hour,
// with edit mode to change individual statuses and save back to the API.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/teacher_attendance_detail_status_mixin.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/teacher_attendance_detail_header_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/teacher_attendance_detail_overview_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/teacher_attendance_detail_card_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/teacher_attendance_detail_actions_mixin.dart';

// ========== TEACHER ABSENSI DETAIL PAGE ==========
class TeacherAttendanceDetailPage extends ConsumerStatefulWidget {
  const TeacherAttendanceDetailPage({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.classId,
    required this.className,
    required this.teacher,
    this.lessonHourId,
    this.lessonHourName,
    this.canEdit = true,
    this.filterTeacherId,
  });

  final String subjectId;
  final String subjectName;
  final DateTime date;
  final String classId;
  final String className;
  final Map<String, dynamic> teacher;
  final String? lessonHourId;
  final String? lessonHourName;
  final bool canEdit;
  final String? filterTeacherId;

  @override
  ConsumerState<TeacherAttendanceDetailPage> createState() =>
      _TeacherAttendanceDetailPageState();
}

class _TeacherAttendanceDetailPageState
    extends ConsumerState<TeacherAttendanceDetailPage>
    with
        TeacherAttendanceDetailStatusMixin,
        TeacherAttendanceDetailHeaderMixin,
        TeacherAttendanceDetailOverviewMixin,
        TeacherAttendanceDetailCardMixin,
        TeacherAttendanceDetailActionsMixin {
  TeacherAttendanceParams get _controllerParams => TeacherAttendanceParams(
    subjectId: widget.subjectId,
    classId: widget.classId,
    date: widget.date,
    teacherId:
        widget.filterTeacherId ??
        (widget.canEdit ? Teacher.fromJson(widget.teacher).id : null),
    lessonHourId: widget.lessonHourId,
  );

  @override
  void initState() {
    super.initState();
    // Inisialisasi otomatis via AsyncNotifier build()
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final attendanceState = ref.watch(
      teacherAttendanceProvider(_controllerParams),
    );

    return attendanceState.when(
      data: (state) => _buildContent(context, languageProvider, state),
      loading: () => Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            buildHeader(context, languageProvider, isLoading: true),
            const Expanded(
              child: SkeletonListLoading(itemCount: 5, infoTagCount: 2),
            ),
          ],
        ),
      ),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LanguageProvider languageProvider,
    TeacherAttendanceState state,
  ) {
    final stats = state.statistics;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeader(context, languageProvider, state: state),
          state.isSaving
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: getPrimaryColor()),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Saving changes...',
                            'id': 'Menyimpan perubahan...',
                          }),
                          style: TextStyle(
                            color: ColorUtils.slate500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      buildOverviewCard(
                        languageProvider,
                        stats,
                        state.students.length,
                      ),
                      const SizedBox(height: 12),
                      // Frame F · read-only banner — surfaces when the
                      // session is from a past academic year (canEdit=false)
                      // so the teacher knows why pills aren't tappable.
                      if (!widget.canEdit)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.info600.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ColorUtils.info600.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: ColorUtils.info600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en':
                                          'Past academic year — '
                                          'attendance is locked. '
                                          'Export to archive.',
                                      'id':
                                          'Tahun ajaran lalu — '
                                          'tidak bisa diubah. '
                                          'Ekspor Excel untuk arsip.',
                                    }),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.info600,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Mockup-style section head — uppercase title +
                      // "N siswa" trailing label, no boxed pill.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Student List',
                                'id': 'Daftar Siswa',
                              }).toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${state.students.length} '
                              '${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ColorUtils.slate500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: state.students.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: ColorUtils.slate200,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'No student data found',
                                        'id': 'Tidak ada data siswa',
                                      }),
                                      style: TextStyle(
                                        color: ColorUtils.slate400,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: state.students.length,
                                itemBuilder: (context, index) =>
                                    buildStudentCard(
                                      state.students[index],
                                      languageProvider,
                                      state,
                                      index,
                                    ),
                              ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: openEditSheet,
              backgroundColor: getPrimaryColor(),
              elevation: 3,
              highlightElevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                languageProvider.getTranslatedText({
                  'en': 'Edit Attendance',
                  'id': 'Update Kehadiran',
                }),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            )
          : null,
    );
  }
}

// AttendanceDonutPainter retired with the Frame B/F redesign — the
// detail screen now shows a 4-cell KPI strip instead of the donut +
// legend. Re-add from git history if a future view needs the donut.
