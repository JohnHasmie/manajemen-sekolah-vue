import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_student_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_class_card.dart';
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
        final name =
            (cls['name'] ?? cls['nama'] ?? '').toString().toLowerCase();
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
          label: 'Sudah ada rekomendasi',
          onRemove: () => setState(() => _statusFilter = null),
        ),
      );
    } else if (_statusFilter == _filterEmpty) {
      filters.add(
        ActiveFilter(
          label: 'Belum ada rekomendasi',
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
    final primaryColor = getPrimaryColor();
    final isHomeroomTeacher = ref.watch(teacherRiverpod).isHomeroomTeacher;
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          TeacherPageHeader(
            title: 'Rekomendasi Belajar',
            subtitle: isHomeroomView
                ? 'Rekomendasi kelas perwalian'
                : 'Pilih kelas untuk melihat rekomendasi',
            primaryColor: primaryColor,
            onBackPressed: () => AppNavigator.pop(context),
            // Role toggle (only visible if teacher has a perwalian).
            showRoleToggle: isHomeroomTeacher,
            isHomeroomView: isHomeroomView,
            onRoleChanged: (val) {
              setState(() {
                isHomeroomView = val;
                // Filters are scope-specific — reset them on switch so
                // users don't land on an apparently-empty list because
                // the "empty" filter was still active from the other tab.
                _statusFilter = null;
                _searchController.clear();
                _searchQuery = '';
              });
              onRoleToggled(val);
            },
            teachingLabel: 'Mengajar',
            homeroomLabel: 'Wali Kelas',
            homeroomClassName: _homeroomClassName,
            // Search + filter bar inside the gradient header.
            showSearchFilter: true,
            searchController: _searchController,
            searchHintText: 'Cari kelas...',
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onFilterTap: _showFilterSheet,
            hasActiveFilter: _hasActiveFilter,
            // Active filter chip row below header.
            activeFilters: _buildActiveFilters(),
            onClearAllFilters: _clearAllFilters,
            // View toggle pinned to the title row.
            trailing: _buildViewToggleTrailing(),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// View-toggle icon button that sits in the header title row.
  Widget _buildViewToggleTrailing() {
    return GestureDetector(
      onTap: () => setState(() => _isGridView = !_isGridView),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final emptyTitle = isHomeroomView ? 'Belum Ada Kelas Perwalian' : 'Belum Ada Kelas';
    final emptySubtitle = isHomeroomView
        ? 'Anda belum ditugaskan sebagai wali kelas'
        : 'Tidak ada kelas mengajar yang ditugaskan';
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
      title: 'Filter Kelas',
      primaryColor: primaryColor,
      onApply: () {
        Navigator.of(context).pop();
        setState(() => _statusFilter = tStatus);
      },
      onReset: () {
        setState(() => _statusFilter = null);
      },
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          return TeacherFilterContent(
            sections: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterSectionHeader(
                    title: 'Status Rekomendasi',
                    icon: Icons.checklist_rounded,
                    primaryColor: primaryColor,
                  ),
                  FilterChipGrid<String>(
                    options: [
                      FilterOption<String>(
                        value: _filterActive,
                        label: 'Sudah ada',
                      ),
                      FilterOption<String>(
                        value: _filterEmpty,
                        label: 'Belum ada',
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
            title: 'Tidak Ada Hasil',
            subtitle: _searchQuery.isNotEmpty
                ? 'Tidak ada kelas cocok dengan "$_searchQuery"'
                : 'Tidak ada kelas yang cocok dengan filter',
            buttonText: 'Reset Filter',
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
        onGenerate: () => generateForClass(classId, className),
        onViewStudents: () => _navigateToStudentScreen(context, cls),
        onHistoryItemTap: (entry) =>
            _navigateToStudentScreen(context, cls),
      ),
    );
  }

  // ── Grid tile helpers ─────────────────────────────────────────────────

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

  /// Flattened summary view for a class — drives the grid tile badges.
  ({int total, int completed, int pending, int highPriority}) _summaryFor(
    String classId,
  ) {
    final summary = classSummaries[classId];
    final byStatus = _toCountMap(summary?['by_status']);
    final byPriority = _toCountMap(summary?['by_priority']);
    final total = byStatus.values.fold<int>(0, (s, v) => s + v);
    return (
      total: total,
      completed: byStatus['completed'] ?? 0,
      pending: byStatus['pending'] ?? 0,
      highPriority: byPriority['high'] ?? 0,
    );
  }

  /// Most recent generation date for a class, formatted "12 Apr" (id_ID),
  /// or null if there's no history yet.
  String? _latestHistoryLabel(String classId) {
    final entries = classHistory[classId];
    if (entries == null || entries.isEmpty) return null;
    final raw = entries.first['date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      // Short form: "12 Apr" fits inside the narrow grid tile.
      return DateFormat('d MMM', 'id_ID').format(parsed);
    } catch (_) {
      return null;
    }
  }

  Widget _buildGridTile(BuildContext context, dynamic cls) {
    final primaryColor = getPrimaryColor();
    final classId = cls['id']?.toString() ?? '';
    final className = (cls['name'] ?? cls['nama'] ?? 'Kelas').toString();
    final isGenerating = generating[classId] == true;
    final isLoadingSummary = loadingSummaries[classId] == true;
    final studentCount = _readStudentCount(cls);

    final s = _summaryFor(classId);
    final hasActivity = s.total > 0;
    final lastRun = _latestHistoryLabel(classId);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToStudentScreen(context, cls),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            // Stronger border + shadow: slate100 on white cards over a
            // slate50 scaffold blends nearly invisibly. slate200 + a deeper
            // shadow clearly separates each tile.
            border: Border.all(
              color: hasActivity
                  ? primaryColor.withValues(alpha: 0.22)
                  : ColorUtils.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGridTopRow(
                  primaryColor: primaryColor,
                  total: s.total,
                  hasActivity: hasActivity,
                  isLoadingSummary: isLoadingSummary,
                ),
                const SizedBox(height: 12),
                Text(
                  className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentCount > 0
                      ? '$studentCount siswa'
                      : 'Siswa belum tersedia',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: ColorUtils.slate100,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildGridSummaryBlock(
                    primaryColor: primaryColor,
                    isLoadingSummary: isLoadingSummary,
                    hasActivity: hasActivity,
                    completed: s.completed,
                    pending: s.pending,
                    highPriority: s.highPriority,
                    lastRun: lastRun,
                  ),
                ),
                const SizedBox(height: 10),
                _buildGridCta(
                  primaryColor: primaryColor,
                  hasActivity: hasActivity,
                  isGenerating: isGenerating,
                  onTap: isGenerating
                      ? null
                      : () => generateForClass(classId, className),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top row: class icon + total-count badge (or "AI" hint when loading).
  Widget _buildGridTopRow({
    required Color primaryColor,
    required int total,
    required bool hasActivity,
    required bool isLoadingSummary,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.15),
                primaryColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Icon(
            Icons.school_rounded,
            size: 18,
            color: primaryColor,
          ),
        ),
        const Spacer(),
        if (isLoadingSummary)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          )
        else if (hasActivity)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 10,
                  color: primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Summary block (between divider and CTA).
  /// - While the summary is still loading: skeleton lines so users know data
  ///   is coming.
  /// - When the class has activity: status pills + "Terakhir: X" row.
  /// - When empty: tiny encouragement copy instead of blank space.
  Widget _buildGridSummaryBlock({
    required Color primaryColor,
    required bool isLoadingSummary,
    required bool hasActivity,
    required int completed,
    required int pending,
    required int highPriority,
    required String? lastRun,
  }) {
    if (isLoadingSummary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gridSkeletonLine(width: 90),
          const SizedBox(height: 6),
          _gridSkeletonLine(width: 60),
        ],
      );
    }

    if (!hasActivity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 14,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Belum ada rekomendasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Tap Generate untuk mulai',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status pills row: Diterapkan / Pending / High-priority flag.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _gridStatusPill(
              icon: Icons.check_circle_rounded,
              label: '$completed diterapkan',
              color: const Color(0xFF16A34A), // green-600
            ),
            if (pending > 0)
              _gridStatusPill(
                icon: Icons.schedule_rounded,
                label: '$pending pending',
                color: const Color(0xFFD97706), // amber-600
              ),
            if (highPriority > 0)
              _gridStatusPill(
                icon: Icons.priority_high_rounded,
                label: '$highPriority penting',
                color: const Color(0xFFDC2626), // red-600
              ),
          ],
        ),
        const Spacer(),
        if (lastRun != null)
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 11,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Terakhir: $lastRun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _gridStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridSkeletonLine({required double width}) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    );
  }

  Widget _buildGridCta({
    required Color primaryColor,
    required bool hasActivity,
    required bool isGenerating,
    required VoidCallback? onTap,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isGenerating)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: hasActivity ? Colors.white : primaryColor,
            ),
          )
        else
          Icon(
            hasActivity
                ? Icons.auto_awesome_rounded
                : Icons.auto_awesome_outlined,
            size: 13,
            color: hasActivity ? Colors.white : primaryColor,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isGenerating ? 'Memproses...' : 'Generate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasActivity ? Colors.white : primaryColor,
            ),
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: hasActivity
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.9),
                  ],
                )
              : null,
          color: hasActivity ? null : primaryColor.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: hasActivity
              ? null
              : Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                ),
        ),
        child: child,
      ),
    );
  }

  int _readStudentCount(dynamic cls) {
    final candidates = [
      cls['students_count'],
      cls['student_count'],
      cls['jumlah_siswa'],
    ];
    for (final c in candidates) {
      if (c is int) return c;
      if (c != null) {
        final parsed = int.tryParse(c.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
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
