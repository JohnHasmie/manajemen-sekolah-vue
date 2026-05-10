// Mixin for content list building in TeacherMaterialScreen.
//
// Extracted from material_build_mixin.dart to keep that file under 400 lines.
// Contains chapter content, content list, and related helper methods.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
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
  ///
  /// Layout matches the bab-list mockup:
  ///   • persistent "Cari bab atau sub-bab…" search bar
  ///   • "DAFTAR BAB" section label + "X / Y sub-bab" tally
  ///   • expandable bab list (with empty / search-empty state)
  ///
  /// Embedded mode keeps the legacy timeline view; the search +
  /// section header are skipped there since the slate-50 chrome and
  /// dialog header drive the discovery in that flow.
  Widget buildChapterContent(LanguageProvider lp) {
    if (widget.embedded) {
      final filtered = getFilteredChapters();
      if (filtered.isEmpty) return _buildEmptySearchState(lp);
      return AppRefreshIndicator(
        onRefresh: forceRefresh,
        role: 'guru',
        child: MaterialTimelineView(
          chapters: filtered,
          subChapterMaterialList: subChapterMaterialList,
          checkedChapter: checkedChapter,
          checkedSubChapter: checkedSubChapter,
          generatedSubChapter: generatedSubChapter,
          primaryColor: primaryColor,
          onChapterCheck: handleChapterCheck,
          onSubChapterCheck: handleSubChapterCheck,
          onSubChapterTap: navigateToSubChapterDetail,
        ),
      );
    }

    final filtered = getFilteredChapters();
    final isSearchEmpty = filtered.isEmpty;
    final totalSub = subChapterMaterialList.length;
    final checkedSub = checkedSubChapter.values.where((v) => v).length;

    return AppRefreshIndicator(
      onRefresh: forceRefresh,
      role: 'guru',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _buildSearchBar(lp),
          _buildSectionHeader(checkedSub, totalSub),
          if (isSearchEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: _buildEmptySearchState(lp),
            )
          else
            buildContentList(),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(LanguageProvider lp) {
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

  /// Persistent search bar above the bab list — matches the mockup's
  /// "Cari bab atau sub-bab…" affordance. Wired straight to
  /// [searchController] so the existing client-side filter inside
  /// [getFilteredChapters] picks up the keystrokes.
  Widget _buildSearchBar(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: 13.5, color: ColorUtils.slate900),
          decoration: InputDecoration(
            hintText: 'Cari bab atau sub-bab...',
            hintStyle: TextStyle(
              color: ColorUtils.slate400,
              fontSize: 13.5,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: ColorUtils.slate400,
            ),
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  /// "DAFTAR BAB · {checkedSub}/{totalSub} sub-bab" header strip.
  /// Matches the mockup's section label + tally row.
  Widget _buildSectionHeader(int checked, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          Text(
            'DAFTAR BAB',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorUtils.slate600,
            ),
          ),
          const Spacer(),
          if (total > 0)
            Text(
              '$checked / $total sub-bab',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate500,
              ),
            ),
        ],
      ),
    );
  }

  /// Build content list with expandable chapters.
  ///
  /// Shrink-wraps so it can sit inline inside the search + section-
  /// header outer ListView from [buildChapterContent] without
  /// triggering a nested-scrollable layout assertion. The outer
  /// ListView owns the scroll viewport.
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
      shrinkWrap: true,
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

  /// Generated sub-chapter map — drives the AI-ready badge and is also
  /// read by the getCheckedNotGenerated* helpers.
  Map<String, bool> get generatedSubChapter;
}
