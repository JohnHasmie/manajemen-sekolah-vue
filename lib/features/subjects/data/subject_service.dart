/// api_subject_services.dart - Manages subjects (mata
/// pelajaran), materials, and AI-generated content.
/// Like Laravel's SubjectController + MaterialController /
/// Vue's subject store module.
///
/// This facade service delegates to specialized helper
/// services:
/// - Subject CRUD (getSubject, addSubject, etc.)
/// - Material hierarchy (chapters, sub-chapters, content)
/// - Lesson plans / RPP management (saveRPP, import/export)
/// - AI-powered generation (via KamillLabs microservice)
/// - Material progress tracking (checked/generated state)
library;

import 'dart:io';
import 'package:dio/dio.dart';

// Imports for helper services
import 'package:manajemensekolah/features/subjects/data/subject_crud_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_material_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_lesson_plan_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_ai_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_progress_service.dart';

// Export types
export 'subject_crud_service.dart';
export 'subject_material_service.dart';
export 'subject_lesson_plan_service.dart';
export 'subject_ai_service.dart';
export 'subject_progress_service.dart';

/// Main service for subject, material, and AI content
/// management. This is a facade that delegates to
/// specialized helper services to keep concerns separated
/// and maintain testability.
///
/// Public API surface remains unchanged -- all methods are
/// available directly on ApiSubjectService as before.
class ApiSubjectService {
  // Initialize all helper services
  final SubjectCrudService _crudService = SubjectCrudService();
  final SubjectMaterialService _materialService = SubjectMaterialService();
  final SubjectLessonPlanService _lessonPlanService =
      SubjectLessonPlanService();
  final SubjectAiService _aiService = SubjectAiService();
  final SubjectProgressService _progressService = SubjectProgressService();

  // ==================== SUBJECT CRUD ====================
  // Delegates to SubjectCrudService

  Future<Map<String, dynamic>> getSubjectFilterOptions() =>
      _crudService.getSubjectFilterOptions();

  Future<Map<String, dynamic>> getSubjectsPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
    String? gradeLevel,
    List<String>? subjectIds,
    String? academicYearId,
  }) => _crudService.getSubjectsPaginated(
    page: page,
    limit: limit,
    status: status,
    search: search,
    gradeLevel: gradeLevel,
    subjectIds: subjectIds,
    academicYearId: academicYearId,
  );

  Future<List<dynamic>> getSubject({String? status}) =>
      _crudService.getSubject(status: status);

  Future<dynamic> addSubject(Map<String, dynamic> data) =>
      _crudService.addSubject(data);

  Future<void> updateSubject(String id, Map<String, dynamic> data) =>
      _crudService.updateSubject(id, data);

  Future<void> deleteSubject(String id) => _crudService.deleteSubject(id);

  Future<void> attachClass(String subjectId, String classId) =>
      _crudService.attachClass(subjectId, classId);

  Future<void> detachClass(String subjectId, String classId) =>
      _crudService.detachClass(subjectId, classId);

  Future<Map<String, dynamic>> bulkAttachClasses(
    String subjectId,
    List<String> classIds,
  ) => _crudService.bulkAttachClasses(subjectId, classIds);

  Future<List<dynamic>> getAllMasterSubjects() =>
      _crudService.getAllMasterSubjects();

  // ==================== MATERIAL HIERARCHY ====================
  // Delegates to SubjectMaterialService

  Future<List<dynamic>> getContentMaterials({required String subChapterId}) =>
      _materialService.getContentMaterials(subChapterId: subChapterId);

  Future<List<dynamic>> getChapterMaterials({
    String? subjectId,
    String? search,
  }) => _materialService.getChapterMaterials(
    subjectId: subjectId,
    search: search,
  );

  Future<List<dynamic>> getSubChapterMaterials({required String chapterId}) =>
      _materialService.getSubChapterMaterials(chapterId: chapterId);

  Future<dynamic> addChapterMaterial(Map<String, dynamic> data) =>
      _materialService.addChapterMaterial(data);

  Future<dynamic> addSubChapterMaterial(Map<String, dynamic> data) =>
      _materialService.addSubChapterMaterial(data);

  Future<dynamic> addContentMaterial(Map<String, dynamic> data) =>
      _materialService.addContentMaterial(data);

  Future<void> updateChapterMaterial(String id, Map<String, dynamic> data) =>
      _materialService.updateChapterMaterial(id, data);

  Future<void> updateSubChapterMaterial(String id, Map<String, dynamic> data) =>
      _materialService.updateSubChapterMaterial(id, data);

  Future<void> updateContentMaterial(String id, Map<String, dynamic> data) =>
      _materialService.updateContentMaterial(id, data);

  Future<void> deleteChapterMaterial(String id) =>
      _materialService.deleteChapterMaterial(id);

  Future<void> deleteSubChapterMaterial(String id) =>
      _materialService.deleteSubChapterMaterial(id);

  Future<void> deleteContentMaterial(String id) =>
      _materialService.deleteContentMaterial(id);

  Future<List<dynamic>> getMaterials({
    String? teacherId,
    String? subjectId,
    String? academicYearId,
  }) => _materialService.getMaterials(
    teacherId: teacherId,
    subjectId: subjectId,
    academicYearId: academicYearId,
  );

  Future<dynamic> addMaterial(Map<String, dynamic> data) =>
      _materialService.addMaterial(data);

  // ==================== LESSON PLANS ====================
  // Delegates to SubjectLessonPlanService

  Future<dynamic> saveRPP(Map<String, dynamic> data) =>
      _lessonPlanService.saveRPP(data);

  Future<List<dynamic>> getLessonPlansByTeacher(String teacherId) =>
      _lessonPlanService.getLessonPlansByTeacher(teacherId);

  Future<Map<String, dynamic>> importSubjectFromExcel(File file) =>
      _lessonPlanService.importSubjectFromExcel(file);

  Future<String> downloadTemplate() => _lessonPlanService.downloadTemplate();

  // ==================== AI GENERATION ====================
  // Delegates to SubjectAiService

  Future<dynamic> generateLessonPlanViaAI({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String chapterId,
    String? subChapterId,
    String? timeAllocation,
  }) => _aiService.generateLessonPlanViaAI(
    teacherId: teacherId,
    subjectId: subjectId,
    classId: classId,
    chapterId: chapterId,
    subChapterId: subChapterId,
    timeAllocation: timeAllocation,
  );

  Future<Response<dynamic>> generateMaterialRaw(Map<String, dynamic> data) =>
      _aiService.generateMaterialRaw(data);

  Future<dynamic> generateMaterial(Map<String, dynamic> data) =>
      _aiService.generateMaterial(data);

  Future<Response<dynamic>> pollAiJob(String jobId, String token) =>
      _aiService.pollAiJob(jobId, token);

  Future<dynamic> getGeneratedMaterial(String materialId, {String? classId}) =>
      _aiService.getGeneratedMaterial(materialId, classId: classId);

  Future<dynamic> cloneQuizForClass(String materialId, String classId) =>
      _aiService.cloneQuizForClass(materialId, classId);

  Future<dynamic> checkMaterialCache({
    String? teacherId,
    required String chapterId,
    String? subChapterId,
  }) => _aiService.checkMaterialCache(
    teacherId: teacherId,
    chapterId: chapterId,
    subChapterId: subChapterId,
  );

  Future<dynamic> listGeneratedMaterials({
    required String teacherId,
    String? subjectId,
    String? chapterId,
  }) => _aiService.listGeneratedMaterials(
    teacherId: teacherId,
    subjectId: subjectId,
    chapterId: chapterId,
  );

  Future<dynamic> regenerateMaterialContent(String materialId) =>
      _aiService.regenerateMaterialContent(materialId);

  Future<Response<dynamic>> regenerateQuizRaw(String materialId) =>
      _aiService.regenerateQuizRaw(materialId);

  Future<Response<dynamic>> regenerateReferencesRaw(String materialId) =>
      _aiService.regenerateReferencesRaw(materialId);

  Future<Response<dynamic>> regenLessonPlanFieldRaw(
    String lessonPlanId,
    String field, {
    String? additionalText,
  }) => _aiService.regenLessonPlanFieldRaw(
    lessonPlanId,
    field,
    additionalText: additionalText,
  );

  Future<dynamic> getLessonPlanRegenLimits(String lessonPlanId) =>
      _aiService.getLessonPlanRegenLimits(lessonPlanId);

  Future<dynamic> updateLessonPlanFields(
    String lessonPlanId,
    Map<String, dynamic> fields,
  ) => _aiService.updateLessonPlanFields(lessonPlanId, fields);

  Future<dynamic> getLessonPlanDetail(String lessonPlanId) =>
      _aiService.getLessonPlanDetail(lessonPlanId);

  // ==================== MATERIAL PROGRESS ====================
  // Delegates to SubjectProgressService

  Future<List<dynamic>> getMaterialTeacherSummary({
    required String teacherId,
    String? academicYearId,
  }) => _progressService.getMaterialTeacherSummary(
    teacherId: teacherId,
    academicYearId: academicYearId,
  );

  Future<Map<String, dynamic>> getMaterialTeacherSummaryWithSchedules({
    required String teacherId,
    String? academicYearId,
    String view = 'mengajar',
    String? search,
  }) => _progressService.getMaterialTeacherSummaryWithSchedules(
    teacherId: teacherId,
    academicYearId: academicYearId,
    view: view,
    search: search,
  );

  Future<List<dynamic>> getMaterialProgress({
    required String teacherId,
    required String subjectId,
    String? classId,
  }) => _progressService.getMaterialProgress(
    teacherId: teacherId,
    subjectId: subjectId,
    classId: classId,
  );

  Future<dynamic> saveMateriProgress(Map<String, dynamic> data) =>
      _progressService.saveMateriProgress(data);

  Future<dynamic> batchSaveMateriProgress(Map<String, dynamic> data) =>
      _progressService.batchSaveMateriProgress(data);

  Future<dynamic> markMaterialGenerated(Map<String, dynamic> data) =>
      _progressService.markMaterialGenerated(data);

  Future<dynamic> resetMaterialGenerated(Map<String, dynamic> data) =>
      _progressService.resetMaterialGenerated(data);
}
