import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin handling data loading for lesson plan form.
///
/// Loads subjects by teacher, all subjects (fallback), and
/// classes by subject. Manages state for _subjectList and
/// _classList.
mixin LessonPlanFormDataMixin on ConsumerState<LessonPlanFormDialog> {
  late List<dynamic> _subjectList = [];
  late List<dynamic> _classList = [];

  List<dynamic> get subjectList => _subjectList;
  List<dynamic> get classList => _classList;

  /// Loads subjects this teacher actually teaches.
  /// Falls back to all subjects if API fails.
  ///
  /// `scope=teaching` drops the wali-kelas homeroom-class curriculum — a
  /// homeroom teacher would otherwise inherit every subject offered in their
  /// class, so the RPP mapel dropdown listed all subjects instead of just the
  /// ones they teach. Same param the schedule/jadwal form already uses.
  Future<void> loadSubjectsByTeacher() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran?scope=teaching',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info(
          'lesson_plan',
          'Loaded ${_subjectList.length} mata pelajaran',
        );
        if (_subjectList.isNotEmpty) {
          AppLogger.debug(
            'lesson_plan',
            'DEBUG SUBJECT ITEM: ${_subjectList.first}',
          );
        }
      }
    } catch (e) {
      AppLogger.error(
        'lesson_plan',
        'Error loading mata pelajaran by guru: $e',
      );
      loadAllSubjects();
    }
  }

  /// Loads all subjects as fallback.
  Future<void> loadAllSubjects() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  /// Loads classes for the given subject ID.
  Future<void> loadClassesBySubject(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _classList = result['data'];
        } else if (result is List) {
          _classList = result;
        } else {
          _classList = [];
        }
      });
      if (kDebugMode) {
        AppLogger.info(
          'lesson_plan',
          'Loaded ${_classList.length} kelas for mata pelajaran'
              ' $subjectId',
        );
        if (_classList.isNotEmpty) {
          AppLogger.debug(
            'lesson_plan',
            'DEBUG CLASS ITEM: ${_classList.first}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'lesson_plan',
          'Error loading kelas by mata pelajaran: $e',
        );
        setState(() {
          _classList = [];
        });
      }
    }
  }
}
