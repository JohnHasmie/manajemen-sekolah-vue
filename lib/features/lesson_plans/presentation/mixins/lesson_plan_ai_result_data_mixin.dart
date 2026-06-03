import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_utils_mixin.dart';

mixin LessonPlanAiResultDataMixin
    on State<LessonPlanAiResultScreen>, LessonPlanAiResultUtilsMixin {
  // Controllers - protected via getters
  late quill.QuillController objectivesController;
  late quill.QuillController coreActivityController;
  late quill.QuillController assessmentController;
  late quill.QuillController coreCompetencyController;
  late quill.QuillController basicCompetencyController;

  late TextEditingController titleController;
  late TextEditingController educationUnitController;
  late TextEditingController subjectNameController;
  late TextEditingController chapterController;
  late TextEditingController subChapterController;
  late TextEditingController lessonNumberController;
  late TextEditingController classSemesterController;
  late TextEditingController timeAllocationController;

  void initControllers(Map<String, dynamic> data) {
    _initTextControllers(data);
    _initQuillControllers(data);
  }

  void _initTextControllers(Map<String, dynamic> data) {
    final model = LessonPlan.fromJson(data);
    titleController = TextEditingController(
      text: model.title.isNotEmpty ? model.title : 'Lesson Plan AI',
    );
    educationUnitController = TextEditingController(
      text: data['education_unit'] ?? data['satuan_pendidikan'] ?? 'SD/MI',
    );
    subjectNameController = TextEditingController(
      text: model.subjectName ?? '',
    );
    chapterController = TextEditingController(
      text: data['chapter_name'] ?? data['bab_nama'] ?? '',
    );
    subChapterController = TextEditingController(
      text: data['sub_chapter_name'] ?? data['sub_bab_nama'] ?? '',
    );
    lessonNumberController = TextEditingController(
      text: data['lesson_number'] ?? data['pembelajaran_ke'] ?? '',
    );
    classSemesterController = TextEditingController(
      text: data['class_semester'] ?? data['kelas_semester'] ?? '',
    );
    timeAllocationController = TextEditingController(
      text: data['time_allocation'] ?? data['alokasi_waktu'] ?? '',
    );
  }

  void _initQuillControllers(Map<String, dynamic> data) {
    coreCompetencyController = quill.QuillController(
      document: convertHtmlToQuill(
        data['core_competency'] ?? data['kompetensi_inti'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    basicCompetencyController = quill.QuillController(
      document: convertHtmlToQuill(
        data['basic_competency'] ?? data['kompetensi_dasar'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    objectivesController = quill.QuillController(
      document: convertHtmlToQuill(
        data['learning_objectives'] ??
            data['tujuan_pembelajaran'] ??
            data['learning_objective'] ??
            '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    coreActivityController = quill.QuillController(
      document: convertHtmlToQuill(
        data['core_activity'] ??
            data['kegiatan_inti'] ??
            data['learning_activities'] ??
            '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    assessmentController = quill.QuillController(
      document: convertHtmlToQuill(
        data['assessment'] ?? data['penilaian'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void disposeControllers() {
    coreCompetencyController.dispose();
    basicCompetencyController.dispose();
    objectivesController.dispose();
    coreActivityController.dispose();
    assessmentController.dispose();
    titleController.dispose();
    educationUnitController.dispose();
    subjectNameController.dispose();
    chapterController.dispose();
    subChapterController.dispose();
    lessonNumberController.dispose();
    classSemesterController.dispose();
    timeAllocationController.dispose();
  }
}
