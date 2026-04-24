import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_detail_dialog.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_add_edit_sheet.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for class-related actions (add, edit, delete, promote).
///
/// Provides methods for managing class operations. Assumes the State
/// class provides setState(), context, and ref.
mixin ClassroomActionMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields
  List<dynamic> get teachers;
  set teachers(List<dynamic> value);

  List<String> get availableGradeLevels;

  bool get isMounted => mounted;

  /// Opens add/edit dialog with fresh data and teacher list.
  Future<void> showAddEditDialog({Map<String, dynamic>? classData}) async {
    await _fetchTeachersForDialog();

    if (classData != null) {
      classData = await _getFreshClassData(classData);
      if (classData != null) {
        await _ensureHomeroomTeacherInList(classData);
      }
    }

    if (!isMounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassroomAddEditSheet(
        classData: classData,
        teachers: teachers,
        availableGradeLevels: availableGradeLevels,
        onSaved: onClassSaved,
      ),
    );
  }

  /// Fetches fresh teacher list for the dialog.
  Future<void> _fetchTeachersForDialog() async {
    final teacherList = await ref
        .read(adminClassroomControllerProvider)
        .fetchTeachers();
    if (!isMounted) return;
    setState(() => teachers = teacherList);
  }

  /// Fetches fresh class data from API.
  Future<Map<String, dynamic>?> _getFreshClassData(
    Map<String, dynamic> classData,
  ) async {
    try {
      final freshData = await getIt<ApiClassService>().getClassById(
        classData['id'].toString(),
      );
      if (freshData != null && freshData is Map<String, dynamic>) {
        return freshData;
      }
    } catch (e) {
      AppLogger.error('classroom', 'Error fetching fresh class data: $e');
    }
    return classData;
  }

  /// Ensures the assigned homeroom teacher appears in the list.
  Future<void> _ensureHomeroomTeacherInList(
    Map<String, dynamic> classData,
  ) async {
    // Classroom model's _standardizeJson already unpacks homeroom_teacher
    // whether it arrives as List (pivot), Map (legacy), or flat fields.
    final model = Classroom.fromJson(classData);
    final String? homeroomId = model.homeroomTeacherId;
    final String? homeroomName = model.homeroomTeacherName;

    if (homeroomId != null &&
        homeroomId.isNotEmpty &&
        homeroomName != null &&
        homeroomName.isNotEmpty) {
      final exists = teachers.any((t) => t['id'].toString() == homeroomId);
      if (!exists && isMounted) {
        setState(() {
          teachers.add({'id': homeroomId, 'name': homeroomName});
          teachers.sort(
            (a, b) => (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
          );
        });
      }
    }
  }

  /// Deletes a class with confirmation dialog.
  Future<void> deleteClass(Map<String, dynamic> classData) async {
    final deleted = await ref
        .read(adminClassroomControllerProvider)
        .deleteClass(classData, context);
    if (deleted) onClassDeleted();
  }

  /// Shows class detail dialog.
  void showClassDetail(Map<String, dynamic> classData) {
    final gradeText = getGradeLevelText(
      classData['grade_level'],
      ref.read(languageRiverpod),
    );

    ClassDetailDialog.show(
      context: context,
      classData: classData,
      gradeText: gradeText,
      primaryColor: getPrimaryColor(),
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
      onEdit: () => showAddEditDialog(classData: classData),
      languageProvider: ref.read(languageRiverpod),
    );
  }

  /// Gets grade level text from controller.
  String getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    return ref
        .read(adminClassroomControllerProvider)
        .getGradeLevelText(gradeLevel, languageProvider);
  }

  /// Gets primary color from controller.
  Color getPrimaryColor() {
    return ref.read(adminClassroomControllerProvider).getPrimaryColor();
  }

  /// Shows the class promotion wizard.
  void showPromotionWizard() {
    AppNavigator.push(context, const ClassPromotionWizard());
  }

  /// Called when a class is saved (hook for reload).
  void onClassSaved();

  /// Called when a class is deleted (hook for reload).
  void onClassDeleted();
}
