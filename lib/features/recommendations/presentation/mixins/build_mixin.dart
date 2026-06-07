import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_student_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_class_card.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_class_grid_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

/// Status filter values.
const _filterActive = 'active';
const _filterEmpty = 'empty';

/// Mixin for building UI in [LearningRecommendationClassScreen].
mixin BuildMixin on ConsumerState<LearningRecommendationClassScreen> {
  /// Whether initial data is still loading.
  bool get isInitialLoading;

  /// Error message from initial load, if any.
  String? get initialErrorMessage;

  /// Gets primary color for the teacher role.
  Color getPrimaryColor();

  /// Gets subjects for a class.
  List<Map<String, String>> getSubjectsForClass(String classId);

  /// Gets the effective teacher ID.
  String get effectiveTeacherId;

  /// Gets the teacher profile ID.
  String? get teacherProfileId;

  /// Gets class summaries.
  Map<String, Map<String, dynamic>> get classSummaries;

  /// Gets loading state for summaries.
  Map<String, bool> get loadingSummaries;

  /// Gets class history.
  Map<String, List<Map<String, dynamic>>> get classHistory;

  /// Gets loading state for history.
  Map<String, bool> get loadingHistory;

  /// Gets schedules loaded flag.
  bool get schedulesLoaded;

  /// Gets generating state.
  Map<String, bool> get generating;

  /// Loads all data with cache option.
  Future<void> loadAllData({bool useCache = true});

  /// Loads class summary.
  Future<void> loadClassSummary(String classId, {bool useCache = true});

  /// Loads class history.
  Future<void> loadClassHistory(String classId, {bool useCache = true});

  /// Triggers generate for a class.
  Future<void> generateForClass(String classId, String className);

  /// Force refresh all data.
  Future<void> forceRefresh();

  /// Whether the teacher is currently viewing the Wali Kelas scope.
  /// Drives the role toggle + source-class selection + cross-teacher
  /// recommendation scope on the API.
  bool get isHomeroomView;
  set isHomeroomView(bool value);

  /// Called when the role toggle flips between Mengajar and Wali Kelas.
  /// The state class owns cache invalidation + reload — this mixin just
  /// passes the new value through.
  Future<void> onRoleToggled(bool nowHomeroom);

  // ── UI state owned by this mixin ──────────────────────────────────────

  /// Inline search query over class names.
  String _searchQuery = '';

  /// Controller for the header search field.
  final TextEditingController _searchController = TextEditingController();

  /// Active status filter (null = all, [_filterActive], [_filterEmpty]).
  String? _statusFilter;

  /// Whether to render the class list as a 2-column grid.
  bool _isGridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Computes the total active recommendation count for a class from its
  /// summary payload.
  int _totalRecsFor(String classId) {
    final byStatus = classSummaries[classId]?['by_status'];
    if (byStatus is! Map) return 0;
    var total = 0;
    for (final v in byStatus.values) {
      if (v is int) {
        total += v;
      } else if (v != null) {
        total += int.tryParse(v.toString()) ?? 0;
      }
    }
    return total;
  }

  /// Live source of classes. Switches between the teacher's perwalian
  /// (homeroom) and teaching (mengajar) rosters based on [isHomeroomView]
  /// so the same screen works for both scopes. Prefers the cached
  /// [teacherRiverpod] value so pull-to-refresh picks up fresh
  /// `students_count` after the provider refetches `/teacher/{id}/classes`.
  /// Falls back to [widget.classes] when the provider hasn't been hydrated
  /// yet (e.g., deep-linked into this screen).
  List<dynamic> get _sourceClasses {
    final provider = ref.watch(teacherRiverpod);
    final fromProvider = isHomeroomView
        ? provider.homeroomClasses
        : provider.allClasses;
    return fromProvider.isNotEmpty ? fromProvider : widget.classes;
  }

  /// Name of the teacher's homeroom class (first entry), used to label
  /// the Wali Kelas pill on the role toggle.
  String? get _homeroomClassName {
    final homeroom = ref.watch(teacherRiverpod).homeroomClasses;
    if (homeroom.isEmpty) return null;
    final first = homeroom.first;
    final raw = first['name'] ?? first['nama'];
    return raw?.toString();
  }

  /// Applies search + status filter to [_sourceClasses].
  List<dynamic> get _filteredClasses {
    final query = _searchQuery.trim().toLowerCase();
    return _sourceClasses.where((cls) {
      if (query.isNotEmpty) {
        final name = (cls['name'] ?? cls['nama'] ?? '')
            .toString()
            .toLowerCase();
        if (!name.contains(query)) return false;
      }
      if (_statusFilter != null) {
        final classId = cls['id']?.toString() ?? '';
        final total = _totalRecsFor(classId);
        if (_statusFilter == _filterActive && total == 0) return false;
        if (_statusFilter == _filterEmpty && total > 0) return false;
      }
      return true;
    }).toList();
  }

  /// Whether any filter is currently active (drives badge on filter icon).
  bool get _hasActiveFilter => _statusFilter != null;

  /// Status filter chips shown under the header when active.
  List<ActiveFilter> _buildActiveFilters() {
    final filters = <ActiveFilter>[];
    if (_statusFilter == _filterActive) {
      filters.add(
        ActiveFilter(
          label: kRecRecommendationsExist.tr,
          onRemove: () => setState(() => _statusFilter = null),
        ),
      );
    } else if (_statusFilter == _filterEmpty) {
      filters.add(
        ActiveFilter(
          label: kRecNoRecommendationsLong.tr,
          onRemove: () => setState(() => _statusFilter = null),
        ),
      );
    }
    return filters;
  }

  /// Clear all active filters (used by "Hapus" in chip row + reset button).
  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHomeroomTeacher = ref.watch(teacherRiverpod).isHomeroomTeacher;
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Brand header + 4-cell KPI overlap. Same Stack +
          // Transform.translate idiom shipped on Raport / Materi /
          // Buku Nilai so the rekomendasi hub matches the rest of
          // the teacher surfaces.
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildBrandHeader(isHomeroomTeacher),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: Transform.translate(
                  offset: const Offset(0, 22),
                  child: _buildKpiStrip(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _buildSearchBar(),
          if (_buildActiveFilters().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ActiveFilterChips(
                filters: _buildActiveFilters(),
                onClearAll: _clearAllFilters,
              ),
            ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// Frame A header — cobalt gradient, Mengajar/Wali Kelas role
  /// toggle in the bottom slot when the teacher has a perwalian,
  /// view-toggle + filter action icons on the right.
  Widget _buildBrandHeader(bool isHomeroomTeacher) {
    final filterIcon = BrandHeaderIconButton(
      icon: Icons.tune_rounded,
      onTap: _showFilterSheet,
      badgeCount: _hasActiveFilter ? 1 : null,
      badgeBorderColor: ColorUtils.brandDarkBlue,
    );
    final viewToggle = BrandHeaderIconButton(
      icon: _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
      onTap: () => setState(() => _isGridView = !_isGridView),
    );

    return BrandPageHeader(
      role: 'guru',
      subtitle: kRecHubSubtitle.tr,
      title: kRecAITitle.tr,
      isRealtimeFresh: true,
      kpiOverlayHeight: 45,
      onBackPressed: () => AppNavigator.pop(context),
      actionIcons: [viewToggle, filterIcon],
      bottomSlot: isHomeroomTeacher ? _buildRoleToggle() : null,
    );
  }

  /// Mengajar / Wali Kelas role toggle. The widget renders nothing
  /// when there's only one role available, which matches the brand
  /// pattern shipped on Materi.
  Widget _buildRoleToggle() {
    final homeroom = _homeroomClassName;
    return RoleToggleChipRow(
      roles: [
        RoleOption.mengajar(subLabel: kRecTeaching.tr),
        RoleOption.waliKelas(
          classId: homeroom ?? 'wali',
          className: homeroom ?? 'Wali',
          subLabel: homeroom != null ? kRecClass.tr : 'Wali Kelas',
        ),
      ],
      selectedRoleId: isHomeroomView
          ? 'wali:${homeroom ?? 'wali'}'
          : 'mengajar',
      onSelected: (id) {
        final nowHomeroom = id.startsWith('wali');
        if (nowHomeroom == isHomeroomView) return;
        setState(() {
          isHomeroomView = nowHomeroom;
          _statusFilter = null;
          _searchController.clear();
          _searchQuery = '';
        });
        onRoleToggled(nowHomeroom);
      },
      accentColor: ColorUtils.brandCobalt,
    );
  }

  /// Cobalt 4-cell KPI strip (Kelas / Pending / Selesai / Total AI).
  /// Aggregates across every class summary the loader has pulled.
  Widget _buildKpiStrip() {
    final kelas = _sourceClasses.length;
    var pending = 0;
    var selesai = 0;
    var total = 0;
    for (final cls in _sourceClasses) {
      final id = cls['id']?.toString() ?? '';
      final summary = classSummaries[id];
      final byStatus = _toCountMap(summary?['by_status']);
      pending += byStatus['pending'] ?? 0;
      pending += byStatus['in_progress'] ?? 0;
      selesai += byStatus['completed'] ?? 0;
      total += byStatus.values.fold<int>(0, (s, v) => s + v);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell('$kelas', 'KELAS', ColorUtils.brandCobalt),
            _kpiDivider(),
            _kpiCell('$pending', 'PENDING', ColorUtils.warning600),
            _kpiDivider(),
            _kpiCell('$selesai', 'SELESAI', ColorUtils.success600),
            _kpiDivider(),
            _kpiCell('$total', 'TOTAL AI', ColorUtils.violet700),
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
              fontSize: 18,
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
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: ColorUtils.slate100,
  );

  /// Cobalt-flat search bar matching the rest of the brand surfaces.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ColorUtils.slate200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 16, color: ColorUtils.slate400),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(fontSize: 12.5, color: ColorUtils.slate900),
                decoration: InputDecoration(
                  hintText: kRecSearchClassesOrSubjects.tr,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ColorUtils.slate400,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final emptyTitle = isHomeroomView
        ? kRecNoHomeroomClasses.tr
        : kRecNoClasses.tr;
    final emptySubtitle = isHomeroomView
        ? kRecNotAssignedAsHomeroom.tr
        : kRecNoTeachingClasses.tr;
    return TeacherAsyncView(
      isLoading: isInitialLoading,
      errorMessage: initialErrorMessage,
      isEmpty: _sourceClasses.isEmpty,
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      emptyIcon: Icons.auto_awesome_outlined,
      skeletonItemCount: 4,
      emptyBuilder: () => EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      ),
      childBuilder: () {
        final filtered = _filteredClasses;
        if (filtered.isEmpty) return _buildNoResults();
        return _isGridView ? _buildGrid(filtered) : _buildList(filtered);
      },
    );
  }

  // ── Filter sheet ──────────────────────────────────────────────────────

  void _showFilterSheet() {
    String? tStatus = _statusFilter;
    final primaryColor = getPrimaryColor();

    showFilterSheet(
      context: context,
      title: kRecFilterClasses.tr,
      primaryColor: primaryColor,
      onApply: () {
        Navigator.of(context).pop();
        setState(() => _statusFilter = tStatus);
      },
      onReset: () => FilterSheetHelpers.reset(
        context,
        () => setState(() => _statusFilter = null),
      ),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          return TeacherFilterContent(
            sections: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterSectionHeader(
                    title: kRecRecommendationStatus.tr,
                    icon: Icons.checklist_rounded,
                    primaryColor: primaryColor,
                  ),
                  FilterChipGrid<String>(
                    options: [
                      FilterOption<String>(
                        value: _filterActive,
                        label: kRecHasRecommendations.tr,
                      ),
                      FilterOption<String>(
                        value: _filterEmpty,
                        label: kRecNoRecommendationsShort.tr,
                      ),
                    ],
                    selectedValue: tStatus,
                    onSelected: (v) => setSS(() => tStatus = v),
                    selectedColor: primaryColor,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── List / Grid / No-results builders ─────────────────────────────────

  Widget _buildList(List<dynamic> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildClassCard(context, items[i]),
    );
  }

  Widget _buildGrid(List<dynamic> items) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Taller cards so the richer grid tile (status pills + last-run
        // row) has room to breathe. Previously 0.70 but that overflowed
        // by ~15px on classes with 3 status pills (diterapkan + pending +
        // penting) because the pills wrap to 3 rows on narrow tiles.
        // 0.62 gives ~22px more vertical room — enough for the worst case
        // without leaving empty tiles (8A, 7B) looking overly tall.
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildGridTile(context, items[i]),
    );
  }

  Widget _buildNoResults() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: kRecNoResults.tr,
            subtitle: _searchQuery.isNotEmpty
                ? kRecNoClassesMatch.tr
                : kRecNoClassesMatchFilter.tr,
            buttonText: kRecResetFilter.tr,
            onPressed: _clearAllFilters,
          ),
        ),
      ),
    );
  }

  // ── Card builders ─────────────────────────────────────────────────────

  Widget _buildClassCard(BuildContext context, dynamic cls) {
    final classId = cls['id']?.toString() ?? '';
    final className = cls['name'] ?? cls['nama'] ?? 'Kelas';
    final summary = classSummaries[classId];
    final isLoading = loadingSummaries[classId] == true;
    final isGenerating = generating[classId] == true;
    final history = classHistory[classId] ?? [];
    final isLoadingHistory = loadingHistory[classId] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RecommendationClassCard(
        className: className,
        classId: classId,
        classData: Map<String, dynamic>.from(cls),
        summary: summary,
        primaryColor: getPrimaryColor(),
        isLoading: isLoading,
        isGenerating: isGenerating,
        schedulesLoaded: schedulesLoaded,
        history: history,
        isLoadingHistory: isLoadingHistory,
        isHomeroom: isHomeroomView,
        onGenerate: () => generateForClass(classId, className),
        onViewStudents: () => _navigateToStudentScreen(context, cls),
        onHistoryItemTap: (entry) => _navigateToStudentScreen(context, cls),
      ),
    );
  }

  // ── Summary helpers ───────────────────────────────────────────────────

  /// Normalize a `by_status` / `by_priority` map into an int map.
  /// Summary JSON sometimes comes through as `{completed: "3"}` instead of
  /// `{completed: 3}`, so we parse defensively.
  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    }
    return {};
  }

  Widget _buildGridTile(BuildContext context, dynamic cls) {
    final classId = cls['id']?.toString() ?? '';
    final className = (cls['name'] ?? cls['nama'] ?? 'Kelas').toString();
    return RecommendationClassGridTile(
      primaryColor: getPrimaryColor(),
      classData: Map<String, dynamic>.from(cls),
      summary: classSummaries[classId],
      history: classHistory[classId] ?? const [],
      isGenerating: generating[classId] == true,
      isLoadingSummary: loadingSummaries[classId] == true,
      onTap: () => _navigateToStudentScreen(context, cls),
      onGenerate: () => generateForClass(classId, className),
    );
  }

  void _navigateToStudentScreen(BuildContext context, dynamic cls) {
    final teacherWithProfileId = Map<String, String>.from(widget.teacher);
    if (teacherProfileId != null) {
      teacherWithProfileId['teacher_id'] = teacherProfileId!;
    }
    final classId = cls['id']?.toString() ?? '';
    // Flat-flow: student list is presented as a bottom sheet stacked on top
    // of the class list rather than pushed as a full page. The sheet pops
    // with `true` when any recommendation status was toggled during the
    // session so we can bypass the local cache and re-fetch.
    //
    // `isHomeroomView` is threaded through so the student + result sheets
    // know to query by `homeroom_class_id` (cross-teacher scope) instead
    // of `teacher_id`, and so the result sheet can hide "Edit Hasil" for
    // recs the current teacher didn't author.
    LearningRecommendationStudentScreen.show(
      context: context,
      teacher: teacherWithProfileId,
      classData: Map<String, dynamic>.from(cls),
      isHomeroomView: isHomeroomView,
    ).then((statusChanged) {
      final useCache = statusChanged != true;
      loadClassSummary(classId, useCache: useCache);
      loadClassHistory(classId, useCache: useCache);
    });
  }
}
