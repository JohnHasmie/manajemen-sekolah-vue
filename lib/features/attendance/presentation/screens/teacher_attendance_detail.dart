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
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';

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

  Future<void> exportDetail() async {
    // Legacy export logic remains mostly unchanged for now, but should use state
  }


  Future<void> _saveChanges() async {
    final success = await ref
        .read(teacherAttendanceProvider(_controllerParams).notifier)
        .saveChanges();
    
    if (success && mounted) {
      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Attendance updated successfully',
          'id': 'Absensi berhasil diperbarui',
        }),
      );
    } else if (!success && mounted) {
      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to update attendance',
          'id': 'Gagal memperbarui absensi',
        }),
      );
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.8)],
    );
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIS: ${student.studentNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (state.isEditing) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStatusButton(
                      'hadir',
                      'H',
                      ColorUtils.success600,
                      student.id,
                      state,
                    ),
                    _buildQuickStatusButton(
                      'terlambat',
                      'T',
                      ColorUtils.violet700,
                      student.id,
                      state,
                    ),
                    _buildQuickStatusButton(
                      'sakit',
                      'S',
                      ColorUtils.warning600,
                      student.id,
                      state,
                    ),
                    _buildQuickStatusButton(
                      'izin',
                      'I',
                      ColorUtils.info600,
                      student.id,
                      state,
                    ),
                    _buildQuickStatusButton(
                      'alpha',
                      'A',
                      ColorUtils.error600,
                      student.id,
                      state,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _buildQuickStatusButton(
    String status,
    String label,
    Color color,
    String studentId,
    TeacherAttendanceState state,
  ) {
    final isSelected = state.editedStatus[studentId]?.toLowerCase() == status;
    return GestureDetector(
      onTap: () {
        ref
            .read(teacherAttendanceProvider(_controllerParams).notifier)
            .updateStatus(studentId, status);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
            _buildLegacyHeader(context, languageProvider, isLoading: true),
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
          _buildLegacyHeader(context, languageProvider, state: state),

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
                      // Statistics Row
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildStatCard(
                              languageProvider.getTranslatedText({
                                'en': 'Present',
                                'id': 'Hadir',
                              }),
                              stats['hadir']!,
                              ColorUtils.success600,
                              Icons.check_circle,
                            ),
                            _buildStatCard(
                              languageProvider.getTranslatedText({
                                'en': 'Late',
                                'id': 'Terlambat',
                              }),
                              stats['terlambat']!,
                              ColorUtils.warning600,
                              Icons.access_time,
                            ),
                            _buildStatCard(
                              languageProvider.getTranslatedText({
                                'en': 'Absent',
                                'id': 'Tidak Hadir',
                              }),
                              stats['alpha']! +
                                  stats['izin']! +
                                  stats['sakit']!,
                              ColorUtils.error600,
                              Icons.cancel,
                            ),
                            if (stats['izin']! > 0)
                              _buildStatCard(
                                languageProvider.getTranslatedText({
                                  'en': 'Permission',
                                  'id': 'Izin',
                                }),
                                stats['izin']!,
                                ColorUtils.info600,
                                Icons.event_note,
                              ),
                            if (stats['sakit']! > 0)
                              _buildStatCard(
                                languageProvider.getTranslatedText({
                                  'en': 'Sick',
                                  'id': 'Sakit',
                                }),
                                stats['sakit']!,
                                ColorUtils.violet700,
                                Icons.medical_services,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Student List Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor(),
                                borderRadius: const BorderRadius.all(Radius.circular(2)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Student List',
                                'id': 'Daftar Siswa',
                              }),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.slate100,
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(
                                '${state.students.length} ${AppLocalizations.students.tr}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate600,
                                  fontWeight: FontWeight.w500,
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
                                      color: ColorUtils.slate300,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'No student data found',
                                        'id': 'Tidak ada data siswa',
                                      }),
                                      style: TextStyle(
                                        color: ColorUtils.slate500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
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
    );
  }

  Widget _buildLegacyHeader(
    BuildContext context,
    LanguageProvider languageProvider, {
    TeacherAttendanceState? state,
    bool isLoading = false,
  }) {
    final isEditing = state?.isEditing ?? false;
    final isSaving = state?.isSaving ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back/Close button
              GestureDetector(
                onTap: () {
                  if (isEditing) {
                    ref
                        .read(teacherAttendanceProvider(_controllerParams).notifier)
                        .toggleEdit();
                  } else {
                    AppNavigator.pop(context);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    isEditing ? Icons.close : Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? languageProvider.getTranslatedText({
                              'en': 'Edit Attendance',
                              'id': 'Edit Absensi',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Attendance Details',
                              'id': 'Detail Absensi',
                            }),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit/Save button
              if (!isLoading)
                GestureDetector(
                  onTap: () {
                    if (isEditing) {
                      _saveChanges();
                    } else {
                      ref
                          .read(teacherAttendanceProvider(_controllerParams).notifier)
                          .toggleEdit();
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: isSaving
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.check : Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat(
                  'EEEE, dd MMMM yyyy',
                  'id_ID',
                ).format(widget.date),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              if (widget.lessonHourName != null &&
                  widget.lessonHourName!.isNotEmpty) ...[
                Text(
                  ' • ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  widget.lessonHourName!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
