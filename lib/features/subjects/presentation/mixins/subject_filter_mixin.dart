import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/admin_subject_management_screen.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_filter_sheet.dart';

/// Mixin handling subject filtering and search functionality.
mixin SubjectFilterMixin on ConsumerState<AdminSubjectManagementScreen> {
  String? _selectedStatusFilter;
  String? _selectedClassesStatusFilter;
  String? _selectedGradeLevelFilter;
  String? _selectedClassNameFilter;
  bool _hasActiveFilter = false;

  @override
  String? get selectedStatusFilter => _selectedStatusFilter;

  @override
  String? get selectedClassesStatusFilter => _selectedClassesStatusFilter;

  @override
  String? get selectedGradeLevelFilter => _selectedGradeLevelFilter;

  @override
  String? get selectedClassNameFilter => _selectedClassNameFilter;

  bool get hasActiveFilter => _hasActiveFilter;

  void checkActiveFilter() {
    final ctrl = ref.read(adminSubjectControllerProvider);
    setState(() {
      _hasActiveFilter = ctrl.checkActiveFilter(
        selectedStatusFilter: _selectedStatusFilter,
        selectedClassesStatusFilter: _selectedClassesStatusFilter,
        selectedGradeLevelFilter: _selectedGradeLevelFilter,
        selectedClassNameFilter: _selectedClassNameFilter,
      );
    });
  }

  void clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassesStatusFilter = null;
      _selectedGradeLevelFilter = null;
      _selectedClassNameFilter = null;
      _hasActiveFilter = false;
    });
    // Note: searchController cleared in UI, loadSubjects called
  }

  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final ctrl = ref.read(adminSubjectControllerProvider);
    return ctrl.buildFilterChips(
      selectedStatusFilter: _selectedStatusFilter,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
      languageProvider: languageProvider,
      onStatusRemoved: () {
        setState(() {
          _selectedStatusFilter = null;
        });
        checkActiveFilter();
        loadSubjects();
      },
      onClassesStatusRemoved: () {
        setState(() {
          _selectedClassesStatusFilter = null;
        });
        checkActiveFilter();
        loadSubjects();
      },
      onGradeLevelRemoved: () {
        setState(() {
          _selectedGradeLevelFilter = null;
        });
        checkActiveFilter();
        loadSubjects();
      },
      onClassNameRemoved: () {
        setState(() {
          _selectedClassNameFilter = null;
        });
        checkActiveFilter();
        loadSubjects();
      },
    );
  }

  void showFilterSheet(
    List<String> availableGradeLevels,
    List<String> availableClassNames,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectFilterSheet(
        initialStatus: _selectedStatusFilter,
        initialClassStatus: _selectedClassesStatusFilter,
        initialGradeLevel: _selectedGradeLevelFilter,
        initialClassName: _selectedClassNameFilter,
        availableGradeLevels: availableGradeLevels,
        availableClassNames: availableClassNames,
        onApply: (status, classStatus, gradeLevel, className) {
          setState(() {
            _selectedStatusFilter = status;
            _selectedClassesStatusFilter = classStatus;
            _selectedGradeLevelFilter = gradeLevel;
            _selectedClassNameFilter = className;
          });
          checkActiveFilter();
          loadSubjects();
        },
      ),
    );
  }

  List<dynamic> getFilteredSubjects(List<dynamic> subjects, String searchText) {
    final ctrl = ref.read(adminSubjectControllerProvider);
    return ctrl.getFilteredSubjects(
      subjectList: subjects,
      searchText: searchText,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
    );
  }

  // Abstract method from data mixin
  Future<void> loadSubjects({bool resetPage = true, bool useCache = true});
}
