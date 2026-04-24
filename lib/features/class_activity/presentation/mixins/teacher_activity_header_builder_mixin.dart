import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityHeaderBuilderMixin
    on ConsumerState<TeacherClassActivityScreen> {
  Widget buildHeader(LanguageProvider lp) {
    return TeacherPageHeader(
      title: lp.getTranslatedText({
        'en': 'Class Activity',
        'id': 'Kegiatan Kelas',
      }),
      subtitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'All activities in homeroom class',
              'id': 'Semua kegiatan di kelas perwalian',
            })
          : lp.getTranslatedText({
              'en': 'Manage your teaching activities',
              'id': 'Kelola kegiatan mengajar Anda',
            }),
      primaryColor: primaryColor,
      trailing: _buildViewToggleButton(),
      showRoleToggle: homeroomClassesList.isNotEmpty,
      isHomeroomView: isHomeroomView,
      onRoleChanged: (val) {
        updateHomeroomView(val);
        refreshGroupedActivities();
      },
      showSearchFilter: true,
      searchController: searchController,
      onSearchSubmitted: (_) => onSearch(),
      onFilterTap: () => showFilterDialog(lp),
      hasActiveFilter: hasActiveFilter,
      searchHintText: lp.getTranslatedText({
        'en': 'Search activity...',
        'id': 'Cari kegiatan...',
      }),
      activeFilters: _buildActiveFilters(lp),
      onClearAllFilters: () {
        updateFilters(
          classId: null,
          subjectId: null,
          dateOption: null,
          subjectList: [],
        );
        forceRefresh();
      },
    );
  }

  Widget _buildViewToggleButton() {
    return GestureDetector(
      onTap: toggleViewMode,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isTimelineView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  List<ActiveFilter>? _buildActiveFilters(LanguageProvider lp) {
    if (!hasActiveFilter) return null;

    final filters = <ActiveFilter>[];
    if (filterClassId != null) {
      final className =
          classList
              .firstWhere(
                (c) => c['id']?.toString() == filterClassId,
                orElse: () => {'name': 'Unknown'},
              )['name']
              ?.toString() ??
          'Unknown';
      filters.add(
        ActiveFilter(
          label: className,
          onRemove: () {
            updateFilters(classId: null, subjectId: null);
            forceRefresh();
          },
        ),
      );
    }
    if (filterSubjectId != null) {
      final subjectName =
          filterSubjectList
              .firstWhere(
                (s) => s['id']?.toString() == filterSubjectId,
                orElse: () => {'name': 'Unknown'},
              )['name']
              ?.toString() ??
          'Unknown';
      filters.add(
        ActiveFilter(
          label: subjectName,
          onRemove: () {
            updateFilters(subjectId: null);
            forceRefresh();
          },
        ),
      );
    }
    if (filterDateOption != null) {
      final label = _dateFilterLabel(lp);
      filters.add(
        ActiveFilter(
          label: label,
          onRemove: () {
            updateFilters(dateOption: null);
            forceRefresh();
          },
        ),
      );
    }
    return filters.isEmpty ? null : filters;
  }

  String _dateFilterLabel(LanguageProvider lp) {
    switch (filterDateOption) {
      case 'today':
        return lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'});
      case 'week':
        return lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'});
      case 'month':
        return lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'});
      default:
        return '';
    }
  }

  // Abstract getters and methods
  bool get isHomeroomView;
  bool get isTimelineView;
  List<dynamic> get homeroomClassesList;
  TextEditingController get searchController;
  bool get hasActiveFilter;
  Color get primaryColor;
  List<dynamic> get classList;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  List<dynamic> get filterSubjectList;

  void toggleViewMode();
  void onSearch();
  void showFilterDialog(LanguageProvider lp);
  void updateHomeroomView(bool value);
  Future<void> refreshGroupedActivities();
  void updateFilters({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  });
  Future<void> forceRefresh();
}
