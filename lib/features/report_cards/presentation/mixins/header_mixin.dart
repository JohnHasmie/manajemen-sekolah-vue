import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

mixin HeaderMixin on ConsumerState<ReportCardOverviewPage> {
  Color get primaryColor => ColorUtils.getRoleColor('guru');
  TextEditingController get searchController;
  bool get isTableView;
  int get activeFilterCount;

  Widget buildHeader(LanguageProvider lp) {
    return TeacherPageHeader(
      title: lp.getTranslatedText({'en': 'Report Cards', 'id': 'Raport'}),
      subtitle: lp.getTranslatedText({
        'en': 'Manage student report cards',
        'id': 'Kelola raport siswa',
      }),
      primaryColor: primaryColor,
      trailing: buildViewToggleButton(),
      // Search + filter
      showSearchFilter: true,
      searchController: searchController,
      onSearchChanged: (_) => setState(() {}),
      onFilterTap: buildFilterButtonOnTap,
      hasActiveFilter: activeFilterCount > 0,
      searchHintText: lp.getTranslatedText({
        'en': 'Search class...',
        'id': 'Cari kelas...',
      }),
      // Active filter chips inside header
      activeFilters: _buildActiveFilters(lp),
      onClearAllFilters: clearFilters,
    );
  }

  List<ActiveFilter>? _buildActiveFilters(LanguageProvider lp) {
    if (activeFilterCount == 0) return null;

    final label = getFilterStatusLabel();
    if (label.isEmpty) return null;

    return [
      ActiveFilter(
        label: label,
        onRemove: clearFilters,
      ),
    ];
  }

  Widget buildViewToggleButton();
  void buildFilterButtonOnTap();
  void clearFilters();
  String getFilterStatusLabel();
}
