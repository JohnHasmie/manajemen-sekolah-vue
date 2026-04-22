// Mixin for content list building in TeacherMaterialScreen.
//
// Extracted from material_build_mixin.dart to keep that file under 400 lines.
// Contains chapter content, content list, and related helper methods.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_content_list.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_timeline_view.dart';

/// Mixin providing content list build methods for [TeacherMaterialScreenState].
mixin MaterialBuildListMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  Map<String, bool> get expandedChapter;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get checkedSubChapter;
  Color get primaryColor;
  bool get isListView;
  TextEditingController get searchController;

  /// Get filtered chapters from search.
  List<dynamic> getFilteredChapters();

  /// Get checkbox color for chapter.
  Color getCheckboxColor(String id, {bool isSubChapter = false});

  /// Handle chapter check change.
  void handleChapterCheck(String chId, bool? checked);

  /// Handle sub-chapter check change.
  void handleSubChapterCheck(String subChId, String babId, bool? checked);

  /// Navigate to sub-chapter detail.
  void navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  );

  /// Auto-expand relevant chapter.
  void autoExpandToRelevant();

  /// Force refresh content.
  Future<void> forceRefresh();

  /// Build chapter content with chapters and sub-chapters.
  Widget buildChapterContent(LanguageProvider lp) {
    final filtered = getFilteredChapters();
    if (filtered.isEmpty) {
      return EmptyState(
        title: lp.getTranslatedText({
          'en': 'No Materials Found',
          'id': 'Materi Tidak Ditemukan',
        }),
        subtitle: lp.getTranslatedText({
          'en':
              'No results for '
              '"${searchController.text}"',
          'id':
              'Tidak ditemukan untuk '
              '"${searchController.text}"',
        }),
        icon: Icons.search,
      );
    }
    return AppRefreshIndicator(
      onRefresh: forceRefresh,
      role: 'guru',
      child: widget.embedded
          ? MaterialTimelineView(
              chapters: filtered,
              subChapterMaterialList: subChapterMaterialList,
              checkedChapter: checkedChapter,
              checkedSubChapter: checkedSubChapter,
              generatedSubChapter: generatedSubChapter,
              primaryColor: primaryColor,
              onChapterCheck: handleChapterCheck,
              onSubChapterCheck: handleSubChapterCheck,
              onSubChapterTap: navigateToSubChapterDetail,
            )
          : buildContentList(),
    );
  }

  /// Build content list with expandable chapters.
  Widget buildContentList() {
    if (widget.embedded) autoExpandToRelevant();
    return MaterialContentList(
      filteredChapterMaterials: getFilteredChapters(),
      subChapterMaterialList: subChapterMaterialList,
      expandedChapter: expandedChapter,
      checkedChapter: checkedChapter,
      checkedSubChapter: checkedSubChapter,
      generatedSubChapter: generatedSubChapter,
      getCheckboxColor: getCheckboxColor,
      onChapterExpanded: (chId, v) => setState(() => expandedChapter[chId] = v),
      onChapterCheck: handleChapterCheck,
      onSubChapterTap: navigateToSubChapterDetail,
      onSubChapterCheck: handleSubChapterCheck,
    );
  }

  /// Check if any filter is active.
  bool hasActiveFilter() => false; // Will be overridden by main mixin

  /// Get checked not generated chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedChapters() {
    return chapterMaterialList
        .where(
          (ch) =>
              checkedChapter[ch['id'].toString()] == true &&
              !(generatedChapter[ch['id'].toString()] ?? false),
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  /// Get checked not generated sub-chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedSubChapters() {
    return subChapterMaterialList
        .where(
          (sc) =>
              checkedSubChapter[sc['id'].toString()] == true &&
              !(generatedSubChapter[sc['id'].toString()] ?? false),
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  /// Get generated chapter map (required for getCheckedNotGenerated methods).
  Map<String, bool> get generatedChapter;

  /// Get generated sub-chapter map (required for getCheckedNotGenerated methods).
  Map<String, bool> get generatedSubChapter;
}
