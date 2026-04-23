import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

/// Mixin for loading student and chapter data in AddActivityDialog
mixin ActivityDataLoadingMixin on ConsumerState<AddActivityDialog> {
  // Abstract getters/setters - bridge to state fields
  bool get isLoadingStudents;
  set isLoadingStudents(bool v);

  List<dynamic> get studentList;
  set studentList(List<dynamic> v);

  bool get isLoadingChapters;
  set isLoadingChapters(bool v);

  List<dynamic> get chapterMaterialList;
  set chapterMaterialList(List<dynamic> v);

  List<dynamic> get subChapterMaterialList;
  set subChapterMaterialList(List<dynamic> v);

  String? get selectedClassId;
  String? get selectedChapterId;
  String? get selectedSubChapterId;

  String? initialChapterId;
  String? initialSubChapterId;

  // Public methods
  Future<void> loadStudents(String classId) async {
    if (classId.isEmpty) return;

    setState(() {
      isLoadingStudents = true;
      studentList = [];
    });

    AppLogger.debug(
      'class_activity',
      '[loadStudents] Starting load for class: $classId',
    );

    try {
      final students = await getIt<ApiClassActivityService>()
          .getStudentsByClass(classId);

      if (!mounted) {
        AppLogger.debug(
          'class_activity',
          '[loadStudents] Widget unmounted, skipping setState',
        );
        return;
      }

      setState(() {
        studentList = students;
        isLoadingStudents = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('class_activity', 'Error loading students: $e');
      AppLogger.error('class_activity', stackTrace);
      if (mounted) {
        setState(() {
          studentList = [];
          isLoadingStudents = false;
        });
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadChapterContent(
    String subjectId,
    List<dynamic> subjectList,
  ) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING BAB MATERI =====');
      AppLogger.debug('class_activity', 'Subject ID: $subjectId');

      setState(() {
        isLoadingChapters = true;
        chapterMaterialList = [];
      });

      // Find Master Subject ID from the selected School Subject ID
      final subject = subjectList.firstWhere(
        (s) => s['id']?.toString() == subjectId,
        orElse: () => <String, dynamic>{},
      );
      final masterSubjectId = subject.isNotEmpty
          ? (subject['subject_id']?.toString() ??
                subject['id']?.toString() ??
                subjectId)
          : subjectId;

      final chapterList = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        AppLogger.debug(
          'class_activity',
          'API Response - Bab count: ${chapterList.length}',
        );
        if (chapterList.isNotEmpty) {
          AppLogger.debug(
            'class_activity',
            'First item structure: ${chapterList[0]}',
          );
          AppLogger.debug(
            'class_activity',
            'Available fields: ${chapterList[0].keys}',
          );
          AppLogger.debug(
            'class_activity',
            'Judul Bab: ${chapterList[0]['judul_bab']}',
          );
        }
      }

      setState(() {
        chapterMaterialList = chapterList;
        if (initialChapterId == null) {
          // Will be handled in state
        }
        if (initialSubChapterId == null) {
          subChapterMaterialList = [];
        }
        isLoadingChapters = false;
      });

      AppLogger.debug(
        'class_activity',
        'State updated - chapterMaterialList.length: ${chapterMaterialList.length}',
      );
      AppLogger.debug('class_activity', '=============================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          isLoadingChapters = false;
        });
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadSubChapterContent(String chapterId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING SUB BAB MATERI =====');
      AppLogger.debug('class_activity', 'Bab ID: $chapterId');

      final subChapterList = await getIt<ApiSubjectService>()
          .getSubChapterMaterials(chapterId: chapterId);

      if (kDebugMode) {
        AppLogger.debug(
          'class_activity',
          'API Response - Sub Bab count: ${subChapterList.length}',
        );
        if (subChapterList.isNotEmpty) {
          AppLogger.debug(
            'class_activity',
            'First item structure: ${subChapterList[0]}',
          );
          AppLogger.debug(
            'class_activity',
            'Available fields: ${subChapterList[0].keys}',
          );
          AppLogger.debug(
            'class_activity',
            'Judul Sub Bab: ${subChapterList[0]['judul_sub_bab']}',
          );
        }
      }

      setState(() {
        subChapterMaterialList = subChapterList;
        if (initialSubChapterId == null) {
          // Will be handled in state
        }
      });

      AppLogger.debug(
        'class_activity',
        'State updated - subChapterMaterialList.length: ${subChapterMaterialList.length}',
      );
      AppLogger.debug('class_activity', '==================================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading sub bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }
}
