import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_api_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_utils_mixin.dart';

mixin GenerateLessonPlanFormMixin
    on
        ConsumerState<GenerateLessonPlanFormDialog>,
        GenerateLessonPlanApiMixin,
        GenerateLessonPlanUtilsMixin {
  Future<void> submitForm() async {
    AppLogger.debug('lesson_plan', 'submitForm called');
    if (!formKey.currentState!.validate()) {
      AppLogger.error('lesson_plan', 'Validation failed');
      SnackBarUtils.showWarning(
        context,
        'Mohon lengkapi semua field yang wajib diisi',
      );
      return;
    }

    AppLogger.info('lesson_plan', 'Validation passed, starting API call');
    setState(() {
      isAutoGenerating = true;
      generationStatus = 'Sedang menghubungi AI KamillLabs...';
    });

    try {
      final token = PreferencesService().getString('token');
      final requestBody = _buildRequestBody();

      if (kDebugMode) {
        _logDebugInfo(token);
      }

      await callAiGenerationApi(requestBody, token);
    } catch (e) {
      AppLogger.error('lesson_plan', '🚨 submitForm error: $e');
      if (mounted) {
        SnackBarUtils.showInfo(context, 'Error: $e');
      }
    } finally {
      _resetSubmissionState();
    }
  }

  Map<String, dynamic> _buildRequestBody() {
    return {
      'title': titleController.text,
      'subject_id': selectedSubjectId,
      'class_id': selectedClassId,
      'chapter_id': selectedChapterId,
      'sub_chapter_id': selectedSubChapterId,
      'semester': selectedSemester,
      'academic_year': academicYearController.text,
      'teacher_id': widget.teacherId,
    };
  }

  void _logDebugInfo(String? token) {
    final prefs = PreferencesService();
    final userJson = prefs.getString('user');
    String? schoolId;

    if (userJson != null) {
      final user = json.decode(userJson);
      schoolId = user['school_id']?.toString();
    }

    AppLogger.debug(
      'lesson_plan',
      'Current ApiService.baseUrl: ${ApiService.baseUrl}',
    );
    AppLogger.debug(
      'lesson_plan',
      'Using Token: ${token != null ? "Available" : "NULL"}',
    );
    if (token != null && token.length > 5) {
      AppLogger.debug(
        'lesson_plan',
        'Token Prefix: ${token.substring(0, 5)}...',
      );
    }
    AppLogger.debug(
      'lesson_plan',
      'Using School ID: ${schoolId ?? "NULL"} '
          '(Removed from AI request headers)',
    );
  }

  void _resetSubmissionState() {
    AppLogger.debug(
      'lesson_plan',
      '🏁 submitForm finished (isAutoGenerating: false)',
    );
    if (mounted) {
      setState(() {
        isAutoGenerating = false;
        generationStatus = '';
      });
    }
  }

  @override
  Future<Map<String, dynamic>> buildPollingMetadata() async {
    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    // Backend renamed `schools.school_name` → `schools.name`.
    final schoolNameStr = schoolObj != null
        ? (schoolObj['name'] ??
              schoolObj['school_name'] ??
              schoolObj['nama_sekolah'] ??
              'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = subjectList.firstWhere(
      (m) => m['id'].toString() == selectedSubjectId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final subjectName =
        selectedSubject['name'] ?? selectedSubject['nama'] ?? 'Mata Pelajaran';

    final selectedClass = classList.firstWhere(
      (k) => k['id'].toString() == selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final className = selectedClass['name'] ?? selectedClass['nama'] ?? 'Kelas';

    final chapterMap = selectedChapterId != null
        ? chapterList.firstWhere(
            (b) => b['id'].toString() == selectedChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final chapterName = chapterMap.isNotEmpty
        ? (chapterMap['judul_bab'] ??
              chapterMap['title'] ??
              chapterMap['judul'] ??
              '')
        : '';

    final subChapterMap = selectedSubChapterId != null
        ? subChapterList.firstWhere(
            (s) => s['id'].toString() == selectedSubChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subChapterName = subChapterMap.isNotEmpty
        ? (subChapterMap['judul_sub_bab'] ??
              subChapterMap['title'] ??
              subChapterMap['judul'] ??
              '')
        : '';

    return {
      'title': titleController.text,
      'mata_pelajaran_id': selectedSubjectId,
      'mata_pelajaran_nama': subjectName,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': chapterName,
      'sub_bab_nama': subChapterName,
      'kelas_semester': '$className / ${selectedSemester ?? 'Ganjil'}',
      'alokasi_waktu': academicYearController.text,
    };
  }

  @override
  Future<void> processAndNavigate(dynamic lessonPlanResponse) async {
    if (!mounted) return;

    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    // Backend renamed `schools.school_name` → `schools.name`.
    final schoolNameStr = schoolObj != null
        ? (schoolObj['name'] ??
              schoolObj['school_name'] ??
              schoolObj['nama_sekolah'] ??
              'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = subjectList.firstWhere(
      (m) => m['id'].toString() == selectedSubjectId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final lpModel = LessonPlan.fromJson(lessonPlanResponse);
    final subjectName = (lpModel.subjectName ?? '').isNotEmpty
        ? lpModel.subjectName!
        : (selectedSubject['name'] ??
              selectedSubject['nama'] ??
              'Mata Pelajaran');

    final selectedClass = classList.firstWhere(
      (k) => k['id'].toString() == selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final className = (lpModel.className ?? '').isNotEmpty
        ? lpModel.className!
        : (selectedClass['name'] ?? selectedClass['nama'] ?? 'Kelas');

    final chapterMap = selectedChapterId != null
        ? chapterList.firstWhere(
            (b) => b['id'].toString() == selectedChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final chapterName = chapterMap.isNotEmpty
        ? (chapterMap['judul_bab'] ??
              chapterMap['title'] ??
              chapterMap['judul'] ??
              'Tanpa Nama')
        : '';

    final subChapterMap = selectedSubChapterId != null
        ? subChapterList.firstWhere(
            (s) => s['id'].toString() == selectedSubChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subChapterName = subChapterMap.isNotEmpty
        ? (subChapterMap['judul_sub_bab'] ??
              subChapterMap['title'] ??
              subChapterMap['judul'] ??
              'Tanpa Nama')
        : '';

    final mappedLessonPlanData = {
      'id': lessonPlanResponse['id'],
      'judul': lessonPlanResponse['title'] ?? titleController.text,
      'mata_pelajaran_id': selectedSubjectId,
      'mata_pelajaran_nama': subjectName,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': chapterName,
      'sub_bab_nama': subChapterName,
      'kelas_semester':
          '$className / ${lessonPlanResponse['semester'] ?? selectedSemester}',
      'tema': lessonPlanResponse['title'],
      'sub_tema': '',
      'pembelajaran_ke': '',
      'alokasi_waktu': academicYearController.text,
      'waktu_pendahuluan': '15',
      'waktu_inti': '140',
      'waktu_penutup': '15',
      'kompetensi_inti': stripHtml(
        lessonPlanResponse['core_competence'] as String? ?? '',
      ),
      'kompetensi_dasar': stripHtml(
        lessonPlanResponse['basic_competence'] as String? ?? '',
      ),
      'tujuan_pembelajaran': stripHtml(
        lessonPlanResponse['learning_objective'] as String? ?? '',
      ),
      'kegiatan_pendahuluan':
          '• Melakukan Pembukaan dengan Salam dan '
          'Membaca Doa\n• Mengaitkan Materi Sebelumnya '
          'dengan Materi yang akan dipelajari',
      'kegiatan_inti': stripHtml(
        lessonPlanResponse['learning_activities'] as String? ?? '',
      ),
      'kegiatan_penutup':
          '• Siswa membuat resume dengan bimbingan guru\n'
          '• Guru memeriksa pekerjaan siswa\n'
          '• Pemberian hadiah/pujian untuk pekerjaan '
          'yang benar',
      'penilaian': stripHtml(lessonPlanResponse['assessment'] as String? ?? ''),
      'is_ai_generated': true,
    };

    if (!mounted) return;
    _navigateToResultScreen(mappedLessonPlanData);
  }

  void _navigateToResultScreen(Map<String, dynamic> data) {
    // Capture values before popping the bottom sheet
    final parentContext = Navigator.of(context, rootNavigator: true).context;
    final tId = widget.teacherId;
    final onSavedCb = widget.onSaved;

    // Pop the bottom sheet first to avoid _dependents.isEmpty assertion
    Navigator.of(context).pop();

    // Present the result sheet after the generate-form sheet is fully
    // disposed. Flat-flow: sheet → sheet handoff over the list screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LessonPlanAiResultScreen.show(
        context: parentContext,
        lessonPlanData: data,
        teacherId: tId,
        onSaved: onSavedCb,
      );
    });
  }

  // Abstract getters
  GlobalKey<FormState> get formKey;
  TextEditingController get titleController;
  TextEditingController get academicYearController;
  String? get selectedSubjectId;
  String? get selectedClassId;
  String? get selectedChapterId;
  String? get selectedSubChapterId;
  String? get selectedSemester;
  bool get isAutoGenerating;
  set isAutoGenerating(bool value);
  String get generationStatus;
  set generationStatus(String value);
  List<dynamic> get subjectList;
  List<dynamic> get classList;
  List<dynamic> get chapterList;
  List<dynamic> get subChapterList;
}
