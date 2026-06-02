import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

/// Handles dialog opening and activity changes.
mixin EmbeddedActivityDialogMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  Color get primaryColor;

  List<dynamic> get chapterList;
  List<dynamic> get subChapterList;

  String? get currentTarget;

  // Abstract methods
  Future<void> loadActivities();
  Future<void> loadMaterials(String subjectId);
  Future<void> loadSubChapterContent(String chapterId);
  String resolveActivityType(dynamic activity);

  void showActivityTypeDialog() {
    ActivityTypeBottomSheet.show(
      context: context,
      primaryColor: primaryColor,
      languageProvider: ref.read(languageRiverpod),
      onActivityTypeSelected: showAddActivityDialog,
    );
  }

  void showAddActivityDialog(String activityType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        scheduleList: const [],
        subjectList: const [],
        chapterList: chapterList,
        subChapterList: subChapterList,
        onSubjectSelected: loadMaterials,
        onChapterSelected: loadSubChapterContent,
        onActivityAdded: onActivityChanged,
        // Backend canonical: `all` (was `umum`).
        initialTarget: currentTarget ?? 'all',
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.subjectId,
        initialSubjectName: widget.subjectName,
        initialClassId: widget.classId,
        initialClassName: widget.className,
        initialChapterId: widget.initialChapterId,
        initialSubChapterId: widget.initialSubChapterId,
        initialAdditionalMaterials: widget.initialAdditionalMaterials,
        materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
        lessonHourId: widget.lessonHourId,
      ),
    );
  }

  void showEditActivityDialog(dynamic activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        scheduleList: const [],
        subjectList: const [],
        chapterList: chapterList,
        subChapterList: subChapterList,
        onSubjectSelected: loadMaterials,
        onChapterSelected: loadSubChapterContent,
        onActivityAdded: onActivityChanged,
        // Backend canonical: `all` (was `umum`).
        initialTarget: activity['target_role'] ?? 'all',
        activityType: resolveActivityType(activity),
        isEditMode: true,
        activityData: activity,
        initialDate: activity['date'] != null
            ? DateTime.tryParse(activity['date'].toString())
            : null,
        initialSubjectId: activity['subject_id']?.toString(),
        initialClassId: activity['class_id']?.toString(),
        initialChapterId: activity['chapter_id']?.toString(),
        initialSubChapterId: activity['sub_chapter_id']?.toString(),
        initialAdditionalMaterials: activity['additional_material'] is List
            ? (activity['additional_material'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList()
            : [],
      ),
    );
  }

  void onActivityChanged() {
    loadActivities();
    widget.onActivityChanged?.call();
  }
}
