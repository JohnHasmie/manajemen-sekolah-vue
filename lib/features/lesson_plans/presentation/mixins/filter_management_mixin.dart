import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_filter_sheet.dart';

/// Mixin for filter-related state and behavior.
mixin FilterManagementMixin {
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

  String? getSelectedStatusFilter() => _selectedStatusFilter;
  bool get hasActiveFilter => _hasActiveFilter;

  void setState(VoidCallback fn);
  BuildContext get context;
  WidgetRef get ref;

  void showFilterSheetLocal() {
    final lp = ref.read(languageRiverpod);
    showLessonPlanFilterSheet(
      context: context,
      primaryColor: _getPrimaryColorForFilter(),
      languageProvider: lp,
      currentStatus: _selectedStatusFilter,
      onApply: (status) {
        setState(() {
          _selectedStatusFilter = status;
          _hasActiveFilter = status != null;
        });
      },
    );
  }

  void clearFilterLocal() {
    setState(() {
      _selectedStatusFilter = null;
      _hasActiveFilter = false;
    });
  }

  String buildFilterSummary(LanguageProvider languageProvider) {
    if (_selectedStatusFilter == null) return '';
    final label = languageProvider.getTranslatedText({
      'en': 'Status',
      'id': 'Status',
    });
    return '$label: $_selectedStatusFilter';
  }

  Color _getPrimaryColorForFilter();
}
