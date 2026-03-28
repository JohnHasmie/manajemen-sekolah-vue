// Admin attendance detail page - shows per-student attendance for a specific
// subject/class/date combination, with edit capability.
//
// Extracted from admin_attendance_report_screen.dart to keep the report screen
// focused on the list/table overview. This page is navigated to when an admin
// taps a specific attendance summary row.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

// ========== ADMIN ABSENSI DETAIL PAGE ==========
class AdminAbsensiDetailPage extends ConsumerStatefulWidget {
  final String subjectId;
  final String classId;
  final DateTime date;
  final String subjectName;
  final String className;
  final String? lessonHourId;
  final String? lessonHourName;
  final String? academicYearId;

  const AdminAbsensiDetailPage({
    super.key,
    required this.subjectId,
    required this.classId,
    required this.date,
    required this.subjectName,
    required this.className,
    this.lessonHourId,
    this.lessonHourName,
    this.academicYearId,
  });

  @override
  ConsumerState<AdminAbsensiDetailPage> createState() => _AdminAbsensiDetailPageState();
}

class _AdminAbsensiDetailPageState extends ConsumerState<AdminAbsensiDetailPage> {
  List<dynamic> _attendanceData = [];
  List<Student> _studentList = [];
  bool _isLoading = true;
  bool _isEditing = false;
  final Map<String, String> _tempAttendanceStatus = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 1. Load attendance data
      final attendanceData = await AttendanceService.getAttendance(
        subjectId: widget.subjectId,
        date: DateFormat('yyyy-MM-dd').format(widget.date),
        classId: widget.classId,
        lessonHourId: widget.lessonHourId,
        academicYearId: widget.academicYearId,
      );

      // 2. Load students by class ID (from widget parameter)
      List<dynamic> studentData;
      if (widget.classId.isNotEmpty) {
        studentData = await getIt<ApiStudentService>().getStudentByClass(
          widget.classId,
          academicYearId: widget.academicYearId,
        );
        AppLogger.info('attendance', 'Loaded ${studentData.length} students for class: ${widget.classId} in year: ${widget.academicYearId}',);
      } else {
        // Fallback: if no classId provided, try to get from attendance data
        if (attendanceData.isNotEmpty) {
          final classIdFromData = attendanceData.first['class_id']?.toString();
          if (classIdFromData != null && classIdFromData.isNotEmpty) {
            studentData = await getIt<ApiStudentService>().getStudentByClass(
              classIdFromData,
              academicYearId: widget.academicYearId,
            );
            AppLogger.info('attendance', 'Loaded ${studentData.length} students for class: $classIdFromData (from attendance data)',);
          } else {
            studentData = await getIt<ApiStudentService>().getStudent();
            AppLogger.info('attendance', 'Loaded all students (no class ID available)');
          }
        } else {
          studentData = await getIt<ApiStudentService>().getStudent();
          AppLogger.info('attendance', 'Loaded all students (no attendance data)');
        }
      }

      AppLogger.info('attendance', 'Loaded ${attendanceData.length} attendance records');

      setState(() {
        _studentList = studentData.map((s) => Student.fromJson(s)).toList();
        _attendanceData = attendanceData;

        // Initialize temp status
        _tempAttendanceStatus.clear();
        for (var s in _studentList) {
          _tempAttendanceStatus[s.id] = _getStudentStatus(s.id);
        }

        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi detail for admin: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> exportDetail() async {
    if (_attendanceData.isEmpty) {
            SnackBarUtils.showWarning(context, 'Tidak ada data kegiatan untuk diexport');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExcelPresenceService.exportPresenceToExcel(
        presenceData: _attendanceData,
        context: context,
      );
    } catch (e) {
      AppLogger.error('attendance', 'Error exporting activities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  // Method to get student's attendance status
  String _getStudentStatus(String studentId) {
    try {
      final attendanceRecord = _attendanceData.firstWhere(
        (a) => a['student_id']?.toString() == studentId.toString(),
        orElse: () => {'status': 'alpha'}, // Fallback if not found
      );
      return (attendanceRecord['status'] ?? 'alpha').toString().toLowerCase();
    } catch (e) {
      return 'alpha';
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
      case 'absent':
        return 'absent';
      default:
        return 'present';
    }
  }

  Future<void> _saveChanges() async {
    final languageProvider = ref.read(languageRiverpod);

    setState(() => _isSaving = true);

    String? teacherId;
    if (_attendanceData.isNotEmpty) {
      teacherId =
          _attendanceData.first['teacher_id']?.toString() ??
          _attendanceData.first['guru_id']?.toString();
    }

    if (teacherId == null) {
      setState(() => _isSaving = false);
            SnackBarUtils.showError(context, 'Error: Guru ID tidak ditemukan');
      return;
    }

    int successCount = 0;
    int errorCount = 0;
    String lastError = '';

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

      for (var student in _studentList) {
        try {
          final status = _tempAttendanceStatus[student.id] ?? 'alpha';

          await AttendanceService.createAttendance({
            'student_id': student.id,
            'teacher_id': teacherId,
            'subject_id': widget.subjectId,
            'class_id': widget.classId,
            'date': dateStr,
            'status': _mapStatusToBackend(status),
            'lesson_hour_id': widget.lessonHourId,
            'notes': '',
          });
          successCount++;
        } catch (e) {
          errorCount++;
          lastError = e.toString();
          AppLogger.error('attendance', 'Error saving for student ${student.name}: $e');
        }
      }

      if (successCount > 0) {
                SnackBarUtils.showInfo(context, languageProvider.getTranslatedText({
                'en':
                    'Attendance updated successfully ($successCount students)',
                'id': 'Absensi berhasil diperbarui ($successCount siswa)',
              }));

        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        _loadData(); // Reload to get fresh data from server
      } else {
        throw Exception('Gagal menyimpan semua data. Terakhir: $lastError');
      }
    } catch (e) {
      setState(() => _isSaving = false);
            SnackBarUtils.showError(context, 'Gagal menyimpan perubahan: ${ErrorUtils.getFriendlyMessage(e)}');
    }
  }

  Widget _buildStudentCard(
    Student student,
    LanguageProvider languageProvider,
    int index,
  ) {
    final status = _getStudentStatus(student.id);
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status, languageProvider);
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
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
                      SizedBox(height: 2),
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
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
            if (_isEditing) ...[
              SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStatusButton(
                      'hadir',
                      'H',
                      ColorUtils.success600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'sakit',
                      'S',
                      ColorUtils.warning600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'izin',
                      'I',
                      ColorUtils.info600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'alpha',
                      'A',
                      ColorUtils.error600,
                      student.id,
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
      case 'izin':
      case 'excused':
      case 'permission':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
      case 'sick':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
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

  // Method to calculate statistics
  Map<String, int> _calculateStatistics() {
    int hadir = 0;
    int terlambat = 0;
    int izin = 0;
    int sakit = 0;
    int alpha = 0;

    for (var student in _studentList) {
      final status = _getStudentStatus(student.id);
      switch (status.toLowerCase()) {
        case 'hadir':
        case 'present':
          hadir++;
          break;
        case 'terlambat':
        case 'late':
          terlambat++;
          break;
        case 'izin':
        case 'excused':
        case 'permission':
          izin++;
          break;
        case 'sakit':
        case 'sick':
          sakit++;
          break;
        case 'alpha':
        case 'absent':
          alpha++;
          break;
      }
    }

    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'izin': izin,
      'sakit': sakit,
      'alpha': alpha,
      'total': _studentList.length,
    };
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 90,
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
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
            SizedBox(height: AppSpacing.sm),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusButton(
    String status,
    String label,
    Color color,
    String studentId,
  ) {
    final isSelected = _tempAttendanceStatus[studentId] == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tempAttendanceStatus[studentId] = status;
        });
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        final stats = _calculateStatistics();
        final totalAbsent = stats['alpha']!;

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          bottomNavigationBar: _isEditing
              ? SafeArea(
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.slate900.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPrimaryColor(),
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              languageProvider.getTranslatedText({
                                'en': 'Save Changes',
                                'id': 'Simpan Perubahan',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                )
              : null,
          body: Column(
            children: [
              // Pattern #7 Inline Gradient Header
              Container(
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
                        GestureDetector(
                          onTap: () {
                            if (_isEditing) {
                              setState(() {
                                _isEditing = false;
                                for (var s in _studentList) {
                                  _tempAttendanceStatus[s.id] = _getStudentStatus(
                                    s.id,
                                  );
                                }
                              });
                            } else {
                              AppNavigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isEditing ? Icons.close : Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing
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
                        GestureDetector(
                          onTap: () {
                            if (_isEditing) {
                              _saveChanges();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isEditing ? Icons.check : Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        if (!_isEditing)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'refresh') _loadData();
                              if (value == 'export') exportDetail();
                            },
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download, size: 20),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Export to Excel',
                                        'id': 'Export ke Excel',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Refresh',
                                        'id': 'Refresh',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        SizedBox(width: 6),
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
              ),

              // Statistics Cards
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
                      totalAbsent,
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

              // Student List Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Student List',
                        'id': 'Daftar Siswa',
                      }),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_studentList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),

              // Student List
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        itemCount: 8,
                        infoTagCount: 1,
                        showActions: false,
                      )
                    : _studentList.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          title: languageProvider.getTranslatedText({
                            'en': 'No Students Found',
                            'id': 'Siswa Tidak Ditemukan',
                          }),
                          subtitle: languageProvider.getTranslatedText({
                            'en':
                                'No students were found matching the selected class and criteria.',
                            'id':
                                'Tidak ada siswa yang ditemukan untuk kelas dan kriteria yang dipilih.',
                          }),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: 16),
                        itemCount: _studentList.length,
                        itemBuilder: (context, index) => _buildStudentCard(
                          _studentList[index],
                          languageProvider,
                          index,
                        ),
                      ),
              ),
            ],
          ),
        );
  }
}
