import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_detail_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';

/// Mixin for dialog and bottom sheet operations.
///
/// Owns all methods for displaying dialogs, forms, and managing their results.
/// Requires access to state variables via AdminScheduleStateBridgeMixin.
mixin AdminScheduleDialogsMixin
    on ConsumerState<TeachingScheduleManagementScreen> {
  /// Show schedule details in a dialog.
  void showScheduleDetail(Map<String, dynamic> schedule) {
    final controller = this.controller;
    final dayList = this.dayList;
    final classList = this.classList;

    showDialog(
      context: context,
      builder: (context) => ScheduleDetailDialog(
        schedule: schedule,
        primaryColor: controller.getPrimaryColor(),
        languageProvider: ref.read(languageRiverpod),
        isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
        formatTime: controller.formatTime,
        formatScheduleDays: (s, [p]) => controller.formatScheduleDays(
          s,
          dayList,
          (p ?? ref.read(languageRiverpod))!.currentLanguage,
        ),
        getGradeLevel: (id) => controller.getGradeLevel(id, classList),
        onEdit: editSchedule,
      ),
    );
  }

  /// Add a new schedule by showing form dialog.
  Future<void> addSchedule() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: availableTeachers,
        subjectList: subjectList,
        classList: availableClasses,
        dayList: availableDays,
        semesterList: availableSemesters,
        lessonHourList: lessonHourList,
        semester: selectedTerm,
        academicYear: selectedAcademicYear,
        academicYearList: availableAcademicYears,
        apiService: controller.apiService,
        apiTeacherService: controller.apiTeacherService,
      ),
    );
    if (result != null) await checkAndResolveConflicts(result);
  }

  /// Edit an existing schedule by showing form dialog.
  Future<void> editSchedule(dynamic schedule) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: availableTeachers,
        subjectList: subjectList,
        classList: availableClasses,
        dayList: availableDays,
        semesterList: availableSemesters,
        lessonHourList: lessonHourList,
        semester: selectedTerm,
        academicYear: selectedAcademicYear,
        academicYearList: availableAcademicYears,
        schedule: schedule,
        apiService: controller.apiService,
        apiTeacherService: controller.apiTeacherService,
      ),
    );
    if (result != null) {
      await checkAndResolveConflicts(result, editingScheduleId: schedule['id']);
    }
  }

  /// Delete a schedule with confirmation dialog.
  Future<void> deleteSchedule(String id) async {
    final lp = ref.read(languageRiverpod);
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Delete Schedule',
        'id': 'Hapus Jadwal',
      }),
      message: lp.getTranslatedText({
        'en': 'Are you sure you want to delete this schedule?',
        'id': 'Apakah Anda yakin ingin menghapus jadwal ini?',
      }),
      confirmText: lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
      isDestructive: true,
    );
    if (confirmed == true) {
      final ok = await controller.deleteSchedule(id);
      if (ok) {
        showSuccessSnackBar('Schedule successfully deleted');
        reload();
      } else {
        showErrorSnackBar(
          ref.read(languageRiverpod).getTranslatedText({
            'en': 'Failed to delete schedule',
            'id': 'Gagal menghapus jadwal',
          }),
        );
      }
    }
  }

  /// Check for conflicts and save schedule.
  Future<void> checkAndResolveConflicts(
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final saved = await controller.checkAndResolveConflicts(
        context,
        newScheduleData,
        editingScheduleId: editingScheduleId,
      );
      if (saved) {
        showSuccessSnackBar('Schedule successfully saved');
        reload();
      }
    } catch (e) {
      showErrorSnackBar('Failed to save schedule: $e');
      reload();
    }
  }

  /// Show error snackbar (if mounted).
  void showErrorSnackBar(String msg) =>
      mounted ? SnackBarUtils.showError(context, msg) : null;

  /// Show info snackbar (if mounted).
  void showInfoSnackBar(String msg) =>
      mounted ? SnackBarUtils.showInfo(context, msg) : null;

  /// Show success snackbar (if mounted).
  void showSuccessSnackBar(String msg) => mounted
      ? SnackBarUtils.showSuccess(
          context,
          ref.read(languageRiverpod).getTranslatedText({
            'en': msg,
            'id': msg.replaceAll('successfully', 'berhasil'),
          }),
        )
      : null;

  /// Reload schedule data.
  Future<void> reload() => loadData(
    resetPage: true,
    useCache: false,
    searchText: searchController.text,
    showTableView: showTableView,
  );

  /// Methods that must be implemented or available in state.
  AdminScheduleController get controller;
  List<dynamic> get scheduleList;
  List<dynamic> get subjectList;
  List<dynamic> get classList;
  List<dynamic> get dayList;
  List<dynamic> get lessonHourList;
  List<dynamic> get availableTeachers;
  List<dynamic> get availableClasses;
  List<dynamic> get availableDays;
  List<dynamic> get availableSemesters;
  List<dynamic> get availableAcademicYears;
  String get selectedTerm;
  String get selectedAcademicYear;
  TextEditingController get searchController;
  bool get showTableView;

  /// Load data method from AdminScheduleDataMixin.
  Future<void> loadData({
    bool resetPage,
    bool useCache,
    required String searchText,
    required bool showTableView,
  });
}
