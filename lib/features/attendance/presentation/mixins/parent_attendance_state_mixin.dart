import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

/// Manages core state properties for parent attendance screen.
mixin ParentAttendanceStateMixin on ConsumerState<ParentAttendanceScreen> {
  late List<Attendance> attendanceData;
  late Student? student;
  late bool isLoading;
  late String? selectedMonthFilter;
  late String? selectedSemesterFilter;
  late String? selectedStatusFilter;
  late bool hasActiveFilter;
  late TextEditingController searchController;
  late Map<String, int> monthlySummary;

  /// The student id currently rendered. Defaults to [widget.studentId]
  /// (the value the screen was constructed with) but the screen can
  /// override this getter to support in-place sibling switching via
  /// the chip selector — bumping this value + reloading swaps the
  /// body without a Navigator.pushReplacement.
  String get currentStudentId => widget.studentId;

  /// The academic year currently rendered. Same rationale as
  /// [currentStudentId] — the screen overrides this to react to
  /// in-place academic-year changes without a navigation roundtrip.
  String? get currentAcademicYearId => widget.academicYearId;

  @override
  void initState() {
    super.initState();
    attendanceData = [];
    student = null;
    isLoading = true;
    selectedMonthFilter = null;
    selectedSemesterFilter = null;
    selectedStatusFilter = null;
    hasActiveFilter = false;
    searchController = TextEditingController();
    monthlySummary = {
      'hadir': 0,
      'terlambat': 0,
      'izin': 0,
      'sakit': 0,
      'alpha': 0,
    };
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void setLoading(bool value) {
    setState(() => isLoading = value);
  }

  void setAttendanceData(List<Attendance> data) {
    setState(() => attendanceData = data);
  }

  void setStudent(Student? s) {
    setState(() => student = s);
  }

  void updateAttendanceRead(List<String> ids) {
    setState(() {
      attendanceData = attendanceData.map((item) {
        return ids.contains(item.id) ? item.copyWith(isRead: true) : item;
      }).toList();
    });
  }
}
