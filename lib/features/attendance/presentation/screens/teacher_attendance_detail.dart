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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3.5,
                              height: 16,
                              decoration: BoxDecoration(
                                color: getPrimaryColor(),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Attendance List',
                                'id': 'Daftar Peserta Didik',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: getPrimaryColor().withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${state.students.length} Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: getPrimaryColor(),
                                  fontWeight: FontWeight.w900,
                                ),
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

// === CUSTOM PAINTER FOR DONUT CHART ===
class AttendanceDonutPainter extends CustomPainter {
  final int present;
  final int late;
  final int sick;
  final int permit;
  final int absent;
  final int total;

  AttendanceDonutPainter({
    required this.present,
    required this.late,
    required this.sick,
    required this.permit,
    required this.absent,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.14;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - (strokeWidth / 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -3.14159 / 2;

    _drawSlice(
      canvas,
      rect,
      paint,
      startAngle,
      present / total,
      ColorUtils.success600,
    );
    startAngle += (present / total) * 2 * 3.14159;

    _drawSlice(canvas, rect, paint, startAngle, late / total, Colors.orange);
    startAngle += (late / total) * 2 * 3.14159;

    _drawSlice(
      canvas,
      rect,
      paint,
      startAngle,
      (sick + permit) / total,
      ColorUtils.warning600,
    );
    startAngle += ((sick + permit) / total) * 2 * 3.14159;

    _drawSlice(
      canvas,
      rect,
      paint,
      startAngle,
      absent / total,
      ColorUtils.error600,
    );
  }

  void _drawSlice(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double startAngle,
    double sweepFactor,
    Color color,
  ) {
    if (sweepFactor <= 0) return;
    paint.color = color;
    canvas.drawArc(rect, startAngle, sweepFactor * 2 * 3.14159, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
