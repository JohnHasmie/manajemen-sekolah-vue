import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Handles activity data loading and pagination.
mixin EmbeddedActivityDataMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  int get currentPage;
  set currentPage(int value);

  List<dynamic> get activityList;
  set activityList(List<dynamic> value);

  bool get hasMoreData;
  set hasMoreData(bool value);

  bool get isLoading;
  set isLoading(bool value);

  bool get isLoadingMore;
  set isLoadingMore(bool value);

  int get perPage;

  String? get currentTarget;
  set currentTarget(String? value);

  TextEditingController get searchController;

  String? get selectedDateFilter;

  List<dynamic> get chapterList;
  set chapterList(List<dynamic> value);

  List<dynamic> get subChapterList;
  set subChapterList(List<dynamic> value);

  // Abstract methods from other mixins
  void showActivityTypeDialog();

  void resetAndLoadActivities() {
    setState(() {
      currentPage = 1;
      activityList.clear();
      hasMoreData = true;
      isLoading = true;
    });
    loadActivities();
  }

  Future<void> loadMoreActivities() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() {
      currentPage++;
      isLoadingMore = true;
    });
    await loadActivities();
  }

  Future<void> loadActivities() async {
    if (isLoadingMore && currentPage == 1) return;

    try {
      setState(() {
        if (currentPage == 1) isLoading = true;
      });

      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            page: currentPage,
            limit: perPage,
            teacherId: widget.teacherId,
            classId: widget.classId,
            subjectId: widget.subjectId,
            target: currentTarget,
            search: searchController.text.isNotEmpty
                ? searchController.text
                : null,
            date: selectedDateFilter,
            academicYearId: academicYearId,
          );

      setState(() {
        if (currentPage == 1) {
          activityList = response['data'] ?? [];
        } else {
          activityList.addAll(response['data'] ?? []);
        }
        hasMoreData = response['pagination']?['has_next_page'] ?? false;
        isLoading = false;
        isLoadingMore = false;
      });

      if (widget.autoShowActivityDialog && currentPage == 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) showActivityTypeDialog();
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
          hasMoreData = false;
        });
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadMaterials(String subjectId) async {
    try {
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final materials = await getIt<ApiSubjectService>().getMaterials(
        subjectId: subjectId,
        academicYearId: ayId,
      );
      setState(() {
        chapterList = materials;
        subChapterList = [];
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load materials: $e');
    }
  }

  Future<void> loadSubChapterContent(String chapterId) async {
    try {
      final subMaterials = await getIt<ApiSubjectService>()
          .getSubChapterMaterials(chapterId: chapterId);
      setState(() {
        subChapterList = subMaterials;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load sub chapter materials: $e');
    }
  }
}
