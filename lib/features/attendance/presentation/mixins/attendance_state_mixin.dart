import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Manages state accessor bridges and initialization lifecycle
/// for the attendance screen. Provides getters/setters for all
/// internal state fields and manages view preference loading.
mixin AttendanceStateMixin on ConsumerState<AttendancePage> {
  // State accessors that implementations provide
  Color get primaryColor;
  bool get isTimelineView;
  List<dynamic> get timelineAttendance;

  // Initialization helpers
  Future<void> initializeAttendanceScreen() async {
    _applyInitialParams();
    _attachScrollListeners();
    await _loadViewPref();
    if (widget.embedded) {
      await _loadEmbeddedTeacherData();
      loadEmbeddedData();
    } else {
      loadUserData();
    }
  }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('absensi_view_preference');
      if (c is Map && mounted) {
        setState(() => setIsTimelineView(c['is_timeline'] ?? false));
      }
    } catch (_) {}
  }

  Future<void> _loadEmbeddedTeacherData() async {
    final model = Teacher.fromJson(widget.teacher);
    setTeacherId(model.id);
    setTeacherNama(model.name);
  }

  void _applyInitialParams();
  void _attachScrollListeners();

  // Error state for inline error display with retry
  String? _attendanceErrorMessage;
  String? get attendanceErrorMessage => _attendanceErrorMessage;
  void setAttendanceError(String? message) {
    if (mounted) setState(() => _attendanceErrorMessage = message);
  }

  // State getters/setters (to be implemented by state class)
  String get teacherId;
  set teacherId(String v);

  String get teacherNama;
  set teacherNama(String v);

  void setTeacherId(String v) => teacherId = v;
  void setTeacherNama(String v) => teacherNama = v;
  void setIsTimelineView(bool v);

  // Data loading methods from mixins
  void loadUserData();
  void loadEmbeddedData();
}
