// Mixin for build methods in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Contains all UI building logic for header, content, filter chips,
// FAB, and various view states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_generate_sheet.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_overview_view.dart';

/// Mixin providing build methods for [TeacherMaterialScreenState].
mixin MaterialBuildMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  String? get selectedClassId;
  String? get selectedClassName;
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  List<dynamic> get overviewSummary;
  set overviewSummary(List<dynamic> v);
  bool get isLoading;
  bool get isLoadingBab;
  bool get isLoadingProgress;
  bool get isLoadingOverview;
  set isLoadingOverview(bool v);
  bool get isListView;
  set isListView(bool v);
  bool get isHomeroomView;
  set isHomeroomView(bool v);
  Map<String, bool> get expandedChapter;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get checkedSubChapter;
  TextEditingController get searchController;
  GlobalKey get filterKey;
  GlobalKey get searchKey;
  Color get primaryColor;
  Map<String, bool> get generatedChapter;
  Map<String, bool> get generatedSubChapter;

  /// Get filtered chapters from search.
  List<dynamic> getFilteredChapters();

  /// Get checkbox color for chapter.
  Color getCheckboxColor(String id, {bool isSubChapter = false});

  /// Handle chapter check change.
  void handleChapterCheck(String chId, bool? checked);

  /// Handle sub-chapter check change.
  void handleSubChapterCheck(String subChId, String babId, bool? checked);

  /// Open generate activity sheet.
  void openGenerateActivitySheet();

  /// Show filter dialog.
  Future<void> showFilterDialog(LanguageProvider lp);

  /// Clear all filters.
  void clearAllFilters();

  /// Get checked but not generated chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedChapters();

  /// Get checked but not generated sub-chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedSubChapters();

  /// Get selected subject name.
  String getSelectedSubjectName();

  /// Clear class filter.
  void clearClassFilter();

  /// Clear subject filter.
  void clearSubjectFilter();

  /// Navigate to sub-chapter detail.
  void navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  );

  /// Open chapter sheet.
  void openChapterSheet(String classId, String cn, String subjectId, String sn);

  /// Auto-expand relevant chapter.
  void autoExpandToRelevant();

  /// Force refresh content.
  Future<void> forceRefresh();

  /// Load chapter content (with optional search).
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache,
    String? search,
  });

  /// Load overview and schedules (with optional search).
  Future<void> loadOverviewAndSchedules(
    String teacherId,
    List<dynamic> classes, {
    String? search,
  });

  /// Get teacher ID from widget.
  String get _teacherId => widget.teacher['id']?.toString() ?? '';

  /// Perform search — calls backend API with search term.
  void performSearch() {
    final term = searchController.text.trim();
    if (selectedSubject != null) {
      // Search within chapter content
      setState(() {
        isLoadingBab = true;
        chapterMaterialList = [];
        subChapterMaterialList = [];
      });
      loadChapterContent(
        selectedSubject!,
        useCache: false,
        search: term.isEmpty ? null : term,
      );
    } else {
      // Search within overview
      setState(() => isLoadingOverview = true);
      loadOverviewAndSchedules(
        _teacherId,
        [],
        search: term.isEmpty ? null : term,
      );
    }
  }

  // ignore: annotate_overrides
  set isLoadingBab(bool v);

  // ignore: annotate_overrides
  set chapterMaterialList(List<dynamic> v);

  // ignore: annotate_overrides
  set subChapterMaterialList(List<dynamic> v);

  // ── Build methods ──

  /// Build main screen with header.
  ///
  /// Layout (Materi Q.2 redesign — May 2026):
  ///   • [BrandPageHeader] — cobalt gradient, kicker `Materi
  ///     Pembelajaran`, title `Bab & Sub-Bab` (or class+subject when
  ///     drilled in), live dot, RoleToggleChipRow (Mengajar / Wali
  ///     · NN), BrandFilterChipStrip in bottom slot for active
  ///     class/subject filters, view-toggle + filter icon trailing.
  ///   • Pinned 4-cell KPI strip — Bab / Tercatat / Belum / AI Siap
  ///     (computed client-side from overviewSummary or chapter list).
  ///   • Body: [TeacherAsyncView] wrapping the existing chapter or
  ///     overview content.
  Widget buildMain(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            // Header + KPI overlap. The header reserves 45dp of
            // bottom padding via `kpiOverlayHeight` (matches
            // BrandPageLayout.kpiOverlapHeight). The Stack lets the
            // KPI hang halfway out of the gradient: top half inside
            // the cobalt, bottom half on the slate-50 body — same
            // visual idiom shipped on Presensi / Rekap Nilai /
            // Kegiatan Kelas. Stack itself doesn't grow because the
            // KPI is in `Positioned`, so layout is identical to a
            // bare header with extra padding.
            Stack(
              clipBehavior: Clip.none,
              children: [
                buildBrandHeader(lp),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: Transform.translate(
                    offset: const Offset(0, 22),
                    child: buildKpiStrip(lp),
                  ),
                ),
              ],
            ),
            // Spacer that absorbs the 22dp the KPI hangs below the
            // header; without this the body would overlap the KPI.
            const SizedBox(height: 32),
            Expanded(child: buildContent(lp)),
          ],
        ),
        floatingActionButton: buildFab(lp),
      ),
    );
  }

  /// Build the embedded view used inside an `AppDraggableSheet` (e.g.
  /// when opened from a Jadwal session card's "Materi" action).
  ///
  /// Brand-aligned drag-sheet shell:
  ///   • Cobalt-gradient header with a translucent drag-handle, close
  ///     button, kicker `Materi · <class>`, and bold subject title.
  ///   • Same chapter content body as the full screen.
  Widget buildEmbedded(LanguageProvider lp) {
    final subjectName = widget.initialSubjectName ?? '-';
    final className = widget.initialClassName ?? '';
    final cobalt = ColorUtils.brandCobalt;
    final dark = ColorUtils.brandDarkBlue;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            // Cobalt-gradient sheet header — matches the brand chrome
            // shipped on every other teacher screen sheet (Buku Nilai
            // edit / RPP regen / Jadwal session detail).
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [dark, cobalt],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  // Drag handle.
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'MATERI${className.isNotEmpty ? ' · ${className.toUpperCase()}' : ''}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.78),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subjectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ],
              ),
            ),
            AppSpacing.v8,
            Expanded(child: buildContent(lp)),
          ],
        ),
      ),
    );
  }

  /// Build the brand-aligned hero header.
  ///
  /// The Mengajar / Wali Kelas toggle was intentionally removed:
  /// materi belongs to a (teacher · subject · class) teaching
  /// assignment, not to a homeroom role. A wali kelas doesn't write
  /// materi for *every* subject in 8B — only for the subjects they
  /// personally teach, which the Mengajar view already covers.
  /// Same reasoning as RPP. This also fixes the stuck-skeleton on
  /// "Wali 8B": that view returned an empty payload but the loading
  /// gate could be left dangling on slow / unresolved responses.
  Widget buildBrandHeader(LanguageProvider lp) {
    final hasFilters = hasActiveFilter();

    final title = selectedSubject != null
        ? getSelectedSubjectName()
        : lp.getTranslatedText({
            'en': 'Chapters & Sub-chapters',
            'id': 'Bab & Sub-Bab',
          });

    final kicker = selectedSubject != null && selectedClassName != null
        ? '${selectedClassName!.toUpperCase()} · MATERI'
        : lp.getTranslatedText({
            'en': 'Teaching Materials',
            'id': 'Materi Pembelajaran',
          });

    return BrandPageHeader(
      role: 'guru',
      subtitle: kicker,
      title: title,
      isRealtimeFresh: true,
      kpiOverlayHeight: 45,
      actionIcons: [
        BrandHeaderIconButton(
          icon: isListView
              ? Icons.grid_view_rounded
              : Icons.view_agenda_rounded,
          onTap: toggleViewMode,
        ),
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterDialog(lp),
          badgeCount: hasFilters ? _activeFilterCount() : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      bottomSlot: hasFilters ? _buildBrandFilterStrip(lp) : null,
    );
  }

  // _onRoleSelected was the role-toggle handler. The wali toggle was
  // removed from the materi header (a wali kelas doesn't write materi
  // for every subject in the homeroom — same reasoning as RPP), so
  // the handler is no longer wired up.

  /// Build the BrandFilterChipStrip for the bottom slot — surfaces
  /// active class/subject filters as cobalt-tinted pills inside the
  /// gradient header. Returns null when no filters are active.
  Widget? _buildBrandFilterStrip(LanguageProvider lp) {
    final chips = <BrandFilterChip>[];
    if (selectedClassId != null) {
      chips.add(
        BrandFilterChip(
          label: 'Kelas',
          value: selectedClassName ?? '-',
          showChevron: false,
          onTap: clearClassFilter,
        ),
      );
    }
    if (selectedSubject != null) {
      chips.add(
        BrandFilterChip(
          label: 'Mapel',
          value: getSelectedSubjectName(),
          showChevron: false,
          onTap: clearSubjectFilter,
        ),
      );
    }
    if (chips.isEmpty) return null;
    return BrandFilterChipStrip(chips: chips);
  }

  int _activeFilterCount() {
    var n = 0;
    if (selectedClassId != null) n++;
    if (selectedSubject != null) n++;
    return n;
  }

  /// Build the 3-cell KPI strip (Bab / Sub-Bab / Tercatat).
  ///
  /// Dropped "AI Siap" (M3.3) — the AI count was deemed noise in the
  /// header strip; teachers care about chapter coverage at a glance,
  /// not how many bab have AI-generated material ready. The
  /// `generated` field still ships in `_computeKpiStats()` because
  /// other surfaces (FAB pendingCount, generate sheet) read it.
  ///
  /// Computes totals client-side from `overviewSummary` (or from the
  /// chapter content + checked maps when a subject is selected).
  Widget buildKpiStrip(LanguageProvider lp) {
    final stats = _computeKpiStats();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell('${stats.totalChapters}', 'BAB', ColorUtils.brandCobalt),
            _kpiDivider(),
            _kpiCell(
              '${stats.totalSubChapters}',
              'SUB-BAB',
              ColorUtils.slate800,
            ),
            _kpiDivider(),
            _kpiCell('${stats.checked}', 'TERCATAT', ColorUtils.success600),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: ColorUtils.slate100,
    );
  }

  ({int totalChapters, int totalSubChapters, int checked, int generated})
  _computeKpiStats() {
    if (selectedSubject != null) {
      // In subject-detail mode, count from the loaded chapter list.
      final totalCh = chapterMaterialList.length;
      final totalSub = subChapterMaterialList.length;
      final checked =
          checkedChapter.values.where((v) => v).length +
          checkedSubChapter.values.where((v) => v).length;
      final generated =
          generatedChapter.values.where((v) => v).length +
          generatedSubChapter.values.where((v) => v).length;
      return (
        totalChapters: totalCh,
        totalSubChapters: totalSub,
        checked: checked,
        generated: generated,
      );
    }
    var totalCh = 0;
    var totalSub = 0;
    var checked = 0;
    var generated = 0;
    for (final row in overviewSummary) {
      if (row is! Map) continue;
      final t = (row['total_chapters'] is num)
          ? (row['total_chapters'] as num).toInt()
          : 0;
      final s = (row['total_sub_chapters'] is num)
          ? (row['total_sub_chapters'] as num).toInt()
          : 0;
      final c = (row['checked'] is num) ? (row['checked'] as num).toInt() : 0;
      final g = (row['generated'] is num)
          ? (row['generated'] as num).toInt()
          : 0;
      totalCh += t;
      totalSub += s;
      checked += c;
      generated += g;
    }
    return (
      totalChapters: totalCh,
      totalSubChapters: totalSub,
      checked: checked,
      generated: generated,
    );
  }

  /// Toggle between list and grid view.
  void toggleViewMode() {
    setState(() {
      isListView = !isListView;
      LocalCacheService.save('materi_view_preference', {
        'is_list_view': isListView,
      });
    });
  }

  /// Build the violet "Generate AI" FAB.
  ///
  /// Violet (`#7C3AED`) is the brand's reserved AI affordance color —
  /// matches the AI sub-pill, AI-empty CTA on sub-chapter detail, and
  /// the violet header on the generate sheet. Cobalt is the teacher
  /// primary; we never use it for AI actions.
  ///
  /// The FAB only appears when a subject is selected AND there's at
  /// least one bab/sub-bab marked-as-taught that hasn't been
  /// generated yet — otherwise the action would do nothing.
  Widget? buildFab(LanguageProvider lp) {
    if (selectedSubject == null) return null;
    final pendingCount =
        getCheckedNotGeneratedChapters().length +
        getCheckedNotGeneratedSubChapters().length;
    if (pendingCount == 0) return null;

    const violet = Color(0xFF7C3AED);

    return FloatingActionButton.extended(
      onPressed: () => MaterialGenerateSheet.show(
        context: context,
        checkedChapters: getCheckedNotGeneratedChapters(),
        checkedSubChapters: getCheckedNotGeneratedSubChapters(),
        chapterMaterialList: chapterMaterialList,
        subjectName: getSelectedSubjectName(),
        className: selectedClassName ?? '',
        primaryColor: violet,
        languageProvider: lp,
        onGenerate: openGenerateActivitySheet,
      ),
      backgroundColor: violet,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lp.getTranslatedText({'en': 'Generate AI', 'id': 'Generate AI'}),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$pendingCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? get materialErrorMessage;

  /// Build main content area.
  Widget buildContent(LanguageProvider lp) {
    // When subject is selected, show chapter content with async wrapper
    if (selectedSubject != null) {
      return TeacherAsyncView(
        isLoading: isLoadingBab || isLoadingProgress,
        errorMessage: null,
        isEmpty: chapterMaterialList.isEmpty,
        onRefresh: forceRefresh,
        role: 'guru',
        emptyTitle: lp.getTranslatedText({
          'en': 'No Materials',
          'id': 'Tidak Ada Materi',
        }),
        emptySubtitle: lp.getTranslatedText({
          'en': 'No materials available for this subject',
          'id': 'Tidak ada materi untuk mapel ini',
        }),
        emptyIcon: Icons.menu_book,
        childBuilder: () => buildChapterContent(lp),
        loadingBuilder: () => const SkeletonListLoading(
          padding: EdgeInsets.only(top: 8, bottom: 80),
          showActions: false,
        ),
      );
    }
    // Otherwise show overview with its own async wrapper
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: materialErrorMessage,
      isEmpty: false, // Overview handles empty state internally
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: '',
      emptySubtitle: '',
      emptyIcon: Icons.inbox,
      childBuilder: () => MaterialOverviewView(
        overviewSummary: overviewSummary,
        isLoading: isLoadingOverview,
        isListView: isListView,
        isHomeroomView: isHomeroomView,
        primaryColor: primaryColor,
        languageProvider: lp,
        onRefresh: forceRefresh,
        onOpenChapter: openChapterSheet,
        searchText: searchController.text,
      ),
    );
  }

  /// Build chapter content with chapters and sub-chapters (delegated to MaterialBuildListMixin).
  Widget buildChapterContent(LanguageProvider lp);

  /// Build content list with expandable chapters (delegated to MaterialBuildListMixin).
  Widget buildContentList();

  /// Check if any filter is active.
  bool hasActiveFilter() => selectedClassId != null || selectedSubject != null;
}
