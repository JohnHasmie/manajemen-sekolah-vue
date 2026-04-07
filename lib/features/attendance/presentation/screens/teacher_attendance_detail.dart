// Teacher attendance detail screen — extracted from teacher_attendance_screen.dart.
// Shows per-student attendance for a specific subject/class/date/lesson-hour,
// with edit mode to change individual statuses and save back to the API.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart'; // For AttendancePage

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
  });

  final String subjectId;
  final String subjectName;
  final DateTime date;
  final String classId;
  final String className;
  final Map<String, dynamic> teacher;
  final String? lessonHourId;
  final String? lessonHourName;

  @override
  ConsumerState<TeacherAttendanceDetailPage> createState() =>
      _TeacherAttendanceDetailPageState();
}

class _TeacherAttendanceDetailPageState
    extends ConsumerState<TeacherAttendanceDetailPage> {
  // Logic migrated to TeacherAttendanceController

  TeacherAttendanceParams get _controllerParams => TeacherAttendanceParams(
        subjectId: widget.subjectId,
        classId: widget.classId,
        date: widget.date,
        teacherId: widget.teacher['id']?.toString() ?? '',
        lessonHourId: widget.lessonHourId,
      );

  @override
  void initState() {
    super.initState();
    // Inisialisasi otomatis via AsyncNotifier build()
  }

  void _openEditSheet() {
    // Extract lesson hour number if possible
    int? lessonHourNum;
    if (widget.lessonHourName != null) {
      final match = RegExp(r'\d+').firstMatch(widget.lessonHourName!);
      if (match != null) {
        lessonHourNum = int.tryParse(match.group(0)!);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return AttendancePage(
              teacher: widget.teacher,
              initialDate: widget.date,
              initialSubjectId: widget.subjectId,
              initialSubjectName: widget.subjectName,
              initialclassId: widget.classId,
              initialClassName: widget.className,
              initialLessonHourNumber: lessonHourNum,
              initialTabIndex: 1, // Start on input tab
              embedded: true,
              scrollController: scrollController,
            );
          },
        );
      },
    ).then((_) {
      // Refresh data after edit sheet is closed
      ref.invalidate(teacherAttendanceProvider(_controllerParams));
    });
  }


  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  // Method to get student's attendance status
  String _getStudentStatus(String studentId, TeacherAttendanceState state) {
    return state.editedStatus[studentId] ?? 'absent';
  }

  Widget _buildStudentCard(
    Student student,
    LanguageProvider languageProvider,
    TeacherAttendanceState state,
    int index,
  ) {
    final status = _getStudentStatus(student.id, state);
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status, languageProvider);
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3.5,
                color: statusColor.withValues(alpha: 0.8),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: avatarColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'NIS: ${student.studentNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.slate500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return Icons.check_circle_rounded;
      case 'terlambat':
      case 'late':
        return Icons.access_time_filled_rounded;
      case 'sakit':
      case 'sick':
        return Icons.medication_rounded;
      case 'izin':
      case 'excused':
      case 'permission':
        return Icons.assignment_turned_in_rounded;
      case 'alpha':
      case 'absent':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return ColorUtils.success600;
      case 'izin':
      case 'excused':
      case 'permission':
        return ColorUtils.info600;
      case 'sakit':
      case 'sick':
        return ColorUtils.warning600;
      case 'alpha':
      case 'absent':
        return ColorUtils.error600;
      case 'terlambat':
      case 'late':
        return ColorUtils.violet700;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'sakit':
      case 'sick':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'izin':
      case 'excused':
      case 'permission':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'alpha':
      case 'absent':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
      case 'late':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }


  Widget _buildOverviewCard(
    LanguageProvider languageProvider,
    Map<String, int> stats,
    int totalStudents,
  ) {
    final presentCount = stats['hadir'] ?? 0;
    final lateCount = stats['terlambat'] ?? 0;
    final sickCount = stats['sakit'] ?? 0;
    final permitCount = stats['izin'] ?? 0;
    final absentCount = stats['alpha'] ?? 0;
    
    final attendanceRate = totalStudents > 0 
        ? ((presentCount + lateCount) / totalStudents * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // === LEFT: Sophisticated Donut ===
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(78, 78),
                          painter: AttendanceDonutPainter(
                            present: presentCount,
                            late: lateCount,
                            sick: sickCount,
                            permit: permitCount,
                            absent: absentCount,
                            total: totalStudents,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$attendanceRate%',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Rate',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate400,
                                height: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Glass Divider 1
                  _buildVerticalDivider(),

                  // === MIDDLE: Legend & Rate Label ===
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Status Summary',
                            'id': 'Ringkasan Status',
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildLegendItem('Hadir', ColorUtils.success600),
                            const SizedBox(width: 8),
                            _buildLegendItem('Telat', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildLegendItem('Skt/Izn', ColorUtils.warning600),
                            const SizedBox(width: 8),
                            _buildLegendItem('Alpha', ColorUtils.error600),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Glass Divider 2
                  _buildVerticalDivider(),

                  // === RIGHT: Total Box (Condensed) ===
                  Container(
                    width: 54,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$totalStudents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        Text(
                          languageProvider.getTranslatedText({ 'en': 'Students', 'id': 'Siswa' }),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Integrated Metrics Bar (Thinner)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ColorUtils.slate50.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactMetric('Hadir', presentCount, ColorUtils.success600),
                _buildSeparator(),
                _buildCompactMetric('Telat', lateCount, Colors.orange),
                _buildSeparator(),
                _buildCompactMetric('Izin', permitCount + sickCount, ColorUtils.warning600),
                _buildSeparator(),
                _buildCompactMetric('Alpha', absentCount, ColorUtils.error600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorUtils.slate100.withValues(alpha: 0),
            ColorUtils.slate200,
            ColorUtils.slate100.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: 12,
      color: ColorUtils.slate200.withValues(alpha: 0.5),
    );
  }

  Widget _buildCompactMetric(String label, int count, Color color) {
    return Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final attendanceState = ref.watch(teacherAttendanceProvider(_controllerParams));

    return attendanceState.when(
      data: (state) => _buildContent(context, languageProvider, state),
      loading: () => Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHeader(context, languageProvider, isLoading: true),
            Expanded(child: SkeletonListLoading(itemCount: 5, infoTagCount: 2)),
          ],
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
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
          // === HEADER ===
          _buildHeader(context, languageProvider, state: state),

          // === BODY ===
          state.isSaving
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: _getPrimaryColor(),
                        ),
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
                      // Modern Integrated Statistics
                      const SizedBox(height: 8),
                      _buildOverviewCard(languageProvider, stats, state.students.length),
                      const SizedBox(height: 12),

                      // Student List Header (More Prominent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 3.5,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor(),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${state.students.length} Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getPrimaryColor(),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Student List
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
                                padding: const EdgeInsets.only(bottom: 80), // Extra space for FAB
                                itemCount: state.students.length,
                                itemBuilder: (context, index) =>
                                    _buildStudentCard(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditSheet,
        backgroundColor: _getPrimaryColor(),
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
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
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LanguageProvider languageProvider, {
    TeacherAttendanceState? state,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ColorUtils.heroGradient(primaryColor: _getPrimaryColor()),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Back button with Glass Effect
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: ColorUtils.glassMorphism(opacity: 0.2, blur: 8),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Session Detail',
                              'id': 'Detail Sesi',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            widget.subjectName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Info Section
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: ColorUtils.glassMorphism(opacity: 0.15, blur: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(widget.date),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.lessonHourName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.lessonHourName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _getPrimaryColor(),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Class breadcrumb
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.className} Class Session',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final strokeWidth = size.width * 0.14; // Thinner stroke for larger hole
    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -3.14159 / 2; // Start from top

    // Slices
    _drawSlice(canvas, rect, paint, startAngle, present / total, ColorUtils.success600);
    startAngle += (present / total) * 2 * 3.14159;

    _drawSlice(canvas, rect, paint, startAngle, late / total, Colors.orange);
    startAngle += (late / total) * 2 * 3.14159;

    _drawSlice(canvas, rect, paint, startAngle, (sick + permit) / total, ColorUtils.warning600);
    startAngle += ((sick + permit) / total) * 2 * 3.14159;

    _drawSlice(canvas, rect, paint, startAngle, absent / total, ColorUtils.error600);
  }

  void _drawSlice(Canvas canvas, Rect rect, Paint paint, double startAngle, double sweepFactor, Color color) {
    if (sweepFactor <= 0) return;
    paint.color = color;
    canvas.drawArc(rect, startAngle, sweepFactor * 2 * 3.14159, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
