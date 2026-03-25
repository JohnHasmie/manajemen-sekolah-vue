// Student attendance detail screen — extracted from teacher_attendance_screen.dart.
// Allows a teacher to edit attendance status for each student in a specific
// subject/class/date. Like a Vue sub-page for per-student attendance editing.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

// ========== HELPER FUNCTIONS UNTUK STYLING ==========
Color _getPrimaryColor() {
  return ColorUtils.getRoleColor('guru');
}

// ========== ABSENSI DETAIL PAGE ==========
class AbsensiDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final String? classId;

  const AbsensiDetailPage({
    super.key,
    required this.teacher,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    this.classId,
  });

  @override
  State<AbsensiDetailPage> createState() => _AbsensiDetailPageState();
}

class _AbsensiDetailPageState extends State<AbsensiDetailPage> {
  List<dynamic> _absensiData = [];
  List<Student> _studentList = [];
  List<dynamic> _classList = [];
  final Map<String, String> _absensiStatus = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load siswa, absensi, dan kelas data
      final [studentData, absensiData, classData] = await Future.wait([
        ApiStudentService.getStudent(),
        ApiService.getAttendance(
          teacherId: widget.teacher['id'],
          subjectId: widget.subjectId,
          date: DateFormat('yyyy-MM-dd').format(widget.date),
        ),
        ApiClassService.getClass(),
      ]);

      setState(() {
        // Filter siswa by class if classId is provided
        List<Student> allStudent = studentData
            .map((s) => Student.fromJson(s))
            .toList();
        if (widget.classId != null && widget.classId!.isNotEmpty) {
          _studentList = allStudent
              .where((siswa) => siswa.classId == widget.classId)
              .toList();
        } else {
          _studentList = allStudent;
        }

        _classList = classData;
        _absensiData = absensiData;

        // Map status absensi only for students in this class
        for (var absen in _absensiData) {
          final studentId = absen['student_id']?.toString();
          if (studentId != null && _studentList.any((s) => s.id == studentId)) {
            _absensiStatus[studentId] = absen['status'];
          }
        }

        // Set default untuk siswa yang belum ada data absensi
        for (var student in _studentList) {
          _absensiStatus[student.id] ??= 'hadir';
        }

        _isLoading = false;
      });

      AppLogger.info('attendance', 'Loaded ${_absensiData.length} absensi records for ${_studentList.length} students in class ${widget.classId ?? "all"}',);
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi detail: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStudentItem(Student student, LanguageProvider languageProvider) {
    final status = _absensiStatus[student.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);
    final String statusText = _mapStatusToDisplay(status, languageProvider);
    final avatarColor = _getAvatarColor(student.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
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
                  ),
                  _buildQuickStatusButton(
                    'terlambat',
                    'T',
                    const Color(0xFF7C3AED),
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
    final isSelected =
        _absensiStatus[studentId]?.toLowerCase() == status.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _absensiStatus[studentId] = status;
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

  String _mapStatusToDisplay(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'terlambat':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'alpha':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      default:
        return status;
    }
  }

  Future<void> _updateAbsensi() async {
    final languageProvider = context.read<LanguageProvider>();

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;

      for (var student in _studentList) {
        final status = _absensiStatus[student.id]!;

        await ApiService.createAttendance({
          'student_id': student.id,
          'teacher_id': widget.teacher['id'],
          'subject_id': widget.subjectId,
          'class_id': student.classId,
          'date': DateFormat('yyyy-MM-dd').format(widget.date),
          'status': _mapStatusToBackend(status),
          'notes': '',
        });

        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Successfully updated $successCount attendance records',
                'id': 'Berhasil update $successCount absensi',
              }),
            ),
            backgroundColor: ColorUtils.success600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
            ),
            backgroundColor: ColorUtils.error600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  Color _getAvatarColor(String nama) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    final index = nama.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  String _getKelasName(String classId) {
    try {
      final kelas = _classList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'nama': 'Unknown Class'},
      );
      return kelas['nama'] ?? 'Unknown Class';
    } catch (e) {
      return 'Unknown Class';
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
        return 'absent';
      default:
        return 'present';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Edit Attendance',
                'id': 'Edit Absensi',
              }),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.black),
                onPressed: _loadData,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Refresh',
                  'id': 'Muat Ulang',
                }),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: ColorUtils.slate300),
            ),
          ),
          body: _isLoading
              ? SkeletonListLoading(itemCount: 5, infoTagCount: 2)
              : Column(
                  children: [
                    // Header Info
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: ColorUtils.slate900.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.subjectName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.classId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getKelasName(widget.classId!),
                              style: TextStyle(
                                color: ColorUtils.getRoleColor("guru"),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                              'id_ID',
                            ).format(widget.date),
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_studentList.length} ${languageProvider.getTranslatedText({'en': 'Students', 'id': 'Siswa'})}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Student List Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Student List',
                              'id': 'Daftar Siswa',
                            }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Status',
                              'id': 'Status',
                            }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Student List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _studentList.length,
                        itemBuilder: (context, index) => _buildStudentItem(
                          _studentList[index],
                          languageProvider,
                        ),
                      ),
                    ),
                    // Update Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _updateAbsensi,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.update, size: 20),
                          label: Text(
                            _isSubmitting
                                ? languageProvider.getTranslatedText({
                                    'en': 'Updating...',
                                    'id': 'Mengupdate...',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Update Absensi',
                                    'id': 'Update Absensi',
                                  }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
