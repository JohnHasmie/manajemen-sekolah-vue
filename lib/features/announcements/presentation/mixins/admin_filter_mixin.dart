import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_filter_sheet.dart';

/// Mixin for admin announcement filtering logic.
///
/// Handles filter state, filter chips, and filter-related operations.
mixin AdminFilterMixin on ConsumerState<AdminAnnouncementScreen> {
  String? selectedPriorityFilter;
  String? selectedTargetFilter;
  String? selectedStatusFilter;
  bool hasActiveFilter = false;

  int get currentPage;

  set currentPage(int value);

  Color getPrimaryColor();

  TextEditingController get searchController;

  Future<void> loadData({bool resetPage = true, bool useCache = true});

  void checkActiveFilter() {
    setState(() {
      hasActiveFilter =
          selectedPriorityFilter != null ||
          selectedTargetFilter != null ||
          selectedStatusFilter != null;
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedPriorityFilter = null;
      selectedTargetFilter = null;
      selectedStatusFilter = null;
      hasActiveFilter = false;
    });
    loadData();
  }

  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    if (selectedPriorityFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Priority', 'id': 'Prioritas'})}: $selectedPriorityFilter',
        'onRemove': () {
          setState(() {
            selectedPriorityFilter = null;
          });
          checkActiveFilter();
          loadData();
        },
      });
    }

    if (selectedTargetFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Target', 'id': 'Target'})}: $selectedTargetFilter',
        'onRemove': () {
          setState(() {
            selectedTargetFilter = null;
          });
          checkActiveFilter();
          loadData();
        },
      });
    }

    if (selectedStatusFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $selectedStatusFilter',
        'onRemove': () {
          setState(() {
            selectedStatusFilter = null;
          });
          checkActiveFilter();
          loadData();
        },
      });
    }

    return filterChips;
  }

  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnouncementFilterSheet(
        initialPriority: selectedPriorityFilter,
        initialTarget: selectedTargetFilter,
        initialStatus: selectedStatusFilter,
        primaryColor: getPrimaryColor(),
        languageProvider: languageProvider,
        onApply: (priority, target, status) {
          setState(() {
            selectedPriorityFilter = priority;
            selectedTargetFilter = target;
            selectedStatusFilter = status;
          });
          checkActiveFilter();
          loadData();
        },
      ),
    );
  }

  String? mapPriorityFilter(String? value) {
    if (value == null) return null;
    if (value == 'Penting' || value == 'Important') return 'important';
    if (value == 'Biasa' || value == 'Normal') return 'normal';
    return value.toLowerCase();
  }

  String? mapTargetFilter(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'Semua':
      case 'All':
        return 'all';
      case 'Guru':
      case 'Teachers':
        return 'teacher';
      case 'Siswa':
      case 'Students':
        return 'student';
      case 'Orang Tua':
      case 'Parents':
        return 'parent';
      default:
        return value.toLowerCase();
    }
  }

  String? mapStatusFilter(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'Aktif':
      case 'Active':
        return 'aktif';
      case 'Terjadwal':
      case 'Scheduled':
        return 'terjadwal';
      case 'Kedaluwarsa':
      case 'Expired':
        return 'kedaluwarsa';
      default:
        return value.toLowerCase();
    }
  }
}
