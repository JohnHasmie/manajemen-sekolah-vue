import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityUIBuilderMixin
    on ConsumerState<TeacherClassActivityScreen> {
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  Widget buildActiveFilterBar(LanguageProvider lp) {
    if (!hasActiveFilter) return const SizedBox.shrink();

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
          color: primaryColor,
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
          color: primaryColor,
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
          color: primaryColor,
        ),
      );
    }

    return ActiveFilterChips(
      filters: filters,
      primaryColor: primaryColor,
      leadingIcon: null,
      padding: EdgeInsets.zero,
    );
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

  // Abstract getters
  bool get hasActiveFilter;
  List<dynamic> get classList;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  List<dynamic> get filterSubjectList;

  void updateFilters({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  });

  Future<void> forceRefresh();
}
