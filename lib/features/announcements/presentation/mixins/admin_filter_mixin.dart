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
      final priorityLabel = languageProvider.getTranslatedText({
        'en': 'Priority',
        'id': 'Prioritas',
      });
      filterChips.add({
        'label': '$priorityLabel: $selectedPriorityFilter',
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
      final targetLabel = languageProvider.getTranslatedText({
        'en': 'Target',
        'id': 'Target',
      });
      filterChips.add({
        'label': '$targetLabel: $selectedTargetFilter',
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
      final statusLabel = languageProvider.getTranslatedText({
        'en': 'Status',
        'id': 'Status',
      });
      filterChips.add({
        'label': '$statusLabel: $selectedStatusFilter',
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
    // Backend canonical priorities: `low` / `normal` / `high` / `urgent`
    // (was `biasa` / `penting` / `important`).
    if (value == 'Mendesak' || value == 'Urgent') return 'urgent';
    if (value == 'Penting' || value == 'Important') return 'high';
    if (value == 'Biasa' || value == 'Normal') return 'normal';
    if (value == 'Rendah' || value == 'Low') return 'low';
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
