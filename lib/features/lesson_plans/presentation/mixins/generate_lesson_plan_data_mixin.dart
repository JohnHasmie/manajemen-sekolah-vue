import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';

mixin GenerateLessonPlanDataMixin
    on ConsumerState<GenerateLessonPlanFormDialog> {
  Future<void> loadSubjectsByTeacher() async {
    try {
      final apiService = ApiService();
      // scope=teaching drops the wali-kelas homeroom-class curriculum so the
      // AI-generate RPP picker only lists subjects this teacher teaches.
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran?scope=teaching',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          subjectList = result['data'];
        } else if (result is List) {
          subjectList = result;
        } else {
          subjectList = [];
        }
      });
    } catch (e) {
      loadAllSubjects();
    }
  }

  Future<void> loadAllSubjects() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        if (result is Map && result['data'] is List) {
          subjectList = result['data'];
        } else if (result is List) {
          subjectList = result;
        } else {
          subjectList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  Future<void> loadClassesBySubject(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          classList = result['data'];
        } else if (result is List) {
          classList = result;
        } else {
          classList = [];
        }
      });
    } catch (e) {
      setState(() {
        classList = [];
      });
    }
  }

  Future<void> loadChaptersBySubject(String subjectId) async {
    try {
      final result = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: subjectId,
      );
      setState(() {
        chapterList = result;
      });
    } catch (e) {
      setState(() {
        chapterList = [];
      });
    }
  }

  Future<void> loadSubChaptersByChapter(String chapterId) async {
    try {
      final result = await getIt<ApiSubjectService>().getSubChapterMaterials(
        chapterId: chapterId,
      );
      setState(() {
        subChapterList = result;
      });
    } catch (e) {
      setState(() {
        subChapterList = [];
      });
    }
  }

  // Abstract getters for state variables (implement in main state)
  List<dynamic> get subjectList;
  set subjectList(List<dynamic> value);

  List<dynamic> get classList;
  set classList(List<dynamic> value);

  List<dynamic> get chapterList;
  set chapterList(List<dynamic> value);

  List<dynamic> get subChapterList;
  set subChapterList(List<dynamic> value);
}
