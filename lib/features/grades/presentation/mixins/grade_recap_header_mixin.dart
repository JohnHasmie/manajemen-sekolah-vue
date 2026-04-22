import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';

mixin GradeRecapHeaderMixin on ConsumerState<GradeRecapOverviewPage> {
  // State variables (declared in state class)
  late TextEditingController searchController;
  late bool isHomeroomView;
  late bool isListView;
  late String? filterClassId;
  late String? filterClassName;
  late String? filterSubjectId;
  late String? filterSubjectName;
  late Color primaryColor;
  late int activeFilterCount;

  Widget buildHeader(LanguageProvider lp) {
    final isHomeroomTeacher = ref.watch(teacherRiverpod).isHomeroomTeacher;
    return TeacherPageHeader(
      title: lp.getTranslatedText({
        'en': 'Grade Recap',
        'id': 'Rekap Nilai',
      }),
      subtitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'Homeroom class grade recap',
              'id': 'Rekap nilai kelas perwalian',
            })
          : lp.getTranslatedText({
              'en': 'Manage grade recaps',
              'id': 'Kelola rekap nilai siswa',
            }),
      primaryColor: primaryColor,
      // View toggle button
      trailing: GestureDetector(
        onTap: toggleViewMode,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isListView
                ? Icons.view_agenda_rounded
                : Icons.list_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      // Role toggle
      showRoleToggle: isHomeroomTeacher,
      isHomeroomView: isHomeroomView,
      onRoleChanged: (val) {
        setState(() {
          isHomeroomView = val;
          filterClassId = null;
          filterClassName = null;
          filterSubjectId = null;
          filterSubjectName = null;
        });
        loadData();
      },
      teachingLabel: lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}),
      homeroomLabel: lp.getTranslatedText({
        'en': 'Homeroom',
        'id': 'Wali Kelas',
      }),
      // Search + filter
      showSearchFilter: true,
      searchController: searchController,
      onSearchChanged: (_) => setState(() {}),
      onFilterTap: () => showFilterDialog(lp),
      hasActiveFilter: activeFilterCount > 0,
      searchHintText: lp.getTranslatedText({
        'en': 'Search...',
        'id': 'Cari...',
      }),
      // Active filter chips inside header
      activeFilters: _buildActiveFilters(lp),
      onClearAllFilters: () {
        setState(() {
          filterClassId = null;
          filterClassName = null;
          filterSubjectId = null;
          filterSubjectName = null;
        });
        loadData();
      },
    );
  }

  List<ActiveFilter>? _buildActiveFilters(LanguageProvider lp) {
    if (activeFilterCount == 0) return null;

    final filters = <ActiveFilter>[];
    if (filterClassName != null) {
      filters.add(ActiveFilter(
        label: filterClassName!,
        onRemove: () {
          setState(() {
            filterClassId = null;
            filterClassName = null;
          });
          loadData();
        },
      ));
    }
    if (filterSubjectName != null) {
      filters.add(ActiveFilter(
        label: filterSubjectName!,
        onRemove: () {
          setState(() {
            filterSubjectId = null;
            filterSubjectName = null;
          });
          loadData();
        },
      ));
    }
    return filters.isEmpty ? null : filters;
  }

  // Methods/getters that subclasses must provide
  Future<void> loadData({bool useCache = true});
  void showFilterDialog(LanguageProvider lp);
  void toggleViewMode();
}
