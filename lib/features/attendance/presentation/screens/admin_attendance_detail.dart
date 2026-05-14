// Admin attendance detail page - shows per-student attendance for a specific
// subject/class/date combination, with edit capability.
//
// Extracted from admin_attendance_report_screen.dart to keep the report screen
// focused on the list/table overview. This page is navigated to when an admin
// taps a specific attendance summary row.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_export_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_save_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_status_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_style_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_ui_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_ui_list_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_detail_ui_stats_mixin.dart';

class AdminAttendanceDetailPage extends ConsumerStatefulWidget {
  final String subjectId;
  final String classId;
  final DateTime date;
  final String subjectName;
  final String className;
  final String? lessonHourId;
  final String? lessonHourName;
  final String? academicYearId;

  const AdminAttendanceDetailPage({
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
  ConsumerState<AdminAttendanceDetailPage> createState() =>
      _AdminAttendanceDetailPageState();
}

class _AdminAttendanceDetailPageState
    extends ConsumerState<AdminAttendanceDetailPage>
    with
        admin_detail_data_mixin,
        admin_detail_status_mixin,
        admin_detail_save_mixin,
        admin_detail_export_mixin,
        admin_detail_style_mixin,
        admin_detail_ui_mixin,
        admin_detail_ui_list_mixin,
        admin_detail_ui_stats_mixin {
  List<Attendance> _attendanceData = [];
  List<Student> _studentList = [];
  bool _isLoading = true;
  bool _isEditing = false;
  final Map<String, String> _tempAttendanceStatus = {};
  bool _isSaving = false;

  // Implement mixin abstract properties
  @override
  List<Attendance> get attendanceData => _attendanceData;
  @override
  set attendanceData(List<Attendance> value) => _attendanceData = value;

  @override
  List<Student> get studentList => _studentList;
  @override
  set studentList(List<Student> value) => _studentList = value;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  Map<String, String> get tempAttendanceStatus => _tempAttendanceStatus;

  @override
  bool get isSaving => _isSaving;
  @override
  set isSaving(bool value) => _isSaving = value;

  @override
  bool get isEditing => _isEditing;
  @override
  set isEditing(bool value) => _isEditing = value;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Implement mixin abstract methods for admin_detail_ui_mixin
  @override
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  LinearGradient getCardGradient() {
    return ColorUtils.headerFadeGradient(getPrimaryColor());
  }

  @override
  String getStudentStatusFromData(String studentId) {
    try {
      final attendanceRecord = _attendanceData.firstWhere(
        (a) => a.studentId.toString() == studentId.toString(),
        orElse: () => Attendance(
          id: '',
          studentId: studentId,
          date: widget.date,
          status: 'alpha',
        ),
      );
      return attendanceRecord.status.toLowerCase();
    } catch (e) {
      return 'alpha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final stats = calculateStatistics();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      bottomNavigationBar: _isEditing
          ? _buildSaveButton(languageProvider)
          : null,
      body: Column(
        children: [
          buildHeader(context, languageProvider),
          buildStatsCards(languageProvider, stats),
          buildStudentListHeader(languageProvider),
          buildStudentList(languageProvider),
        ],
      ),
    );
  }

  Widget _buildSaveButton(LanguageProvider languageProvider) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: getPrimaryColor(),
            minimumSize: const Size(double.infinity, 50),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
