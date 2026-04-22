import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';

/// Mixin for import/export and file operations.
///
/// Owns methods for Excel import/export and template downloads.
mixin AdminScheduleActionsMixin
    on ConsumerState<TeachingScheduleManagementScreen> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Import schedules from Excel file.
  Future<void> importFromExcel() async {
    final lp = ref.read(languageRiverpod);
    try {
      setIsLoading(true);
      final imported = await controller.importFromExcel();
      if (!mounted) return;
      if (imported) {
        reload();
        showInfoSnackBar(
          lp.getTranslatedText({
            'en': 'Import successful',
            'id': 'Import berhasil',
          }),
        );
      } else {
        setIsLoading(false);
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      setIsLoading(false);
      showErrorSnackBar(
        '${lp.getTranslatedText({'en': 'Failed to import file: ', 'id': 'Gagal mengimpor file: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Export schedules to Excel file.
  Future<void> exportToExcel() async {
    try {
      await controller.exportToExcel(
        context: context,
        scheduleList: scheduleList,
        dayList: dayList,
        availableAcademicYears: availableAcademicYears,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Export failed: ', 'id': 'Export gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Download Excel template for import.
  Future<void> downloadTemplate() async {
    try {
      await controller.downloadTemplate(context);
    } catch (e) {
      AppLogger.error('schedule', e);
      showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Download template failed: ', 'id': 'Gagal download template: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Trigger search with debouncing for list view, immediate for table view.
  void triggerSearch() {
    if (showTableView) {
      setState(updateGridData);
    } else {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 300),
        () => loadData(
          resetPage: true,
          useCache: true,
          searchText: searchController.text,
          showTableView: false,
        ),
      );
    }
  }

  /// Methods that must be implemented or available in state.
  AdminScheduleController get controller;
  List<dynamic> get scheduleList;
  List<dynamic> get dayList;
  List<dynamic> get availableAcademicYears;
  TextEditingController get searchController;
  bool get showTableView;

  void setIsLoading(bool v);
  Future<void> reload();
  void showErrorSnackBar(String msg);
  void showInfoSnackBar(String msg);
  Future<void> loadData({
    bool resetPage,
    bool useCache,
    required String searchText,
    required bool showTableView,
  });
  void updateGridData();
}
