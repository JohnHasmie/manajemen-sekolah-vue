// RPP (Rencana Pelaksanaan Pembelajaran / Lesson Plan) list screen.
// Like `pages/teacher/LessonPlan/Index.vue` in a Vue app.
//
// Displays a list of RPPs with search, filter by status,
// CRUD operations, AI generation, and Word/PDF download.
// In Laravel terms: `LessonPlanController@index`, `@store`, `@update`, `@destroy`.
//
// Follows the same UI patterns as TeachingScheduleScreen and
// TeacherClassActivityScreen for consistency across teacher pages.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_format_chooser_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_setup_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_upload_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_brand_header_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_filter_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_status_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_crud_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';

/// RPP (lesson plan) list screen with CRUD, search, filter, and AI generation.
///
/// Props (like Vue props): [teacherId], [teacherName].
/// Contains the main list view and navigation to detail/AI screens.
class LessonPlanScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;

  const LessonPlanScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  LessonPlanScreenState createState() => LessonPlanScreenState();
}

/// State for [LessonPlanScreen].
///
/// Manages the RPP list, search, status filter, pagination, and CRUD operations.
/// Uses shared widgets (AppErrorState, EmptyState, AppRefreshIndicator) for
/// consistency with TeachingScheduleScreen and TeacherClassActivityScreen.
class LessonPlanScreenState extends ConsumerState<LessonPlanScreen>
    with
        PaginationMixin<LessonPlanScreen>,
        LessonPlanFilterMixin,
        LessonPlanBrandHeaderMixin,
        LessonPlanStatusMixin,
        LessonPlanCrudMixin {
  List<dynamic> _lessonPlanList = [];
  List<Map<String, dynamic>>? _summaryData; // From /rpp/summary API
  // Server-computed KPI aggregates (weekly / monthly / open / ai /
  // approved / rejected / total). Populated alongside _summaryData;
  // null until the first load completes. The brand header KPI overlay
  // reads through this — falls back to the loaded-list tally when
  // null, so cold-cache renders aren't blank.
  Map<String, int>? _kpiData;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  String? _selectedStatusFilter;
  Set<LessonPlanFormat> _selectedFormats = <LessonPlanFormat>{};
  String? _selectedMethod;
  bool _hasActiveFilter = false;

  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _addRppKey = GlobalKey();

  @override
  String? get selectedStatusFilter => _selectedStatusFilter;

  @override
  set selectedStatusFilter(String? value) {
    _selectedStatusFilter = value;
  }

  @override
  Set<LessonPlanFormat> get selectedFormats => _selectedFormats;

  @override
  set selectedFormats(Set<LessonPlanFormat> value) {
    _selectedFormats = value;
  }

  @override
  String? get selectedMethod => _selectedMethod;

  @override
  set selectedMethod(String? value) {
    _selectedMethod = value;
  }

  @override
  bool get hasActiveFilter => _hasActiveFilter;

  @override
  set hasActiveFilter(bool value) {
    _hasActiveFilter = value;
  }

  @override
  GlobalKey get filterKey => _filterKey;

  @override
  GlobalKey get addRppKey => _addRppKey;

  // ── Bridges for LessonPlanBrandHeaderMixin ──

  @override
  List<dynamic> get lessonPlanList => _lessonPlanList;

  @override
  List<Map<String, dynamic>>? get summaryData => _summaryData;

  @override
  Map<String, int>? get kpiData => _kpiData;

  @override
  void initState() {
    super.initState();
    initPagination();
    loadLessonPlans();
  }

  @override
  void dispose() {
    disposePagination();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> loadPage(int page) async {
    try {
      final result = await LessonPlanService.getLessonPlansPaginated(
        teacherId: widget.teacherId,
        page: page,
        search: _searchController.text,
        status: _selectedStatusFilter,
        academicYearId: _getAcademicYearId(),
        formats: _selectedFormats.isEmpty
            ? null
            : _selectedFormats.map((f) => f.value).toList(),
        method: _selectedMethod,
      );
      final newItems = List<dynamic>.from(result['data'] ?? []);
      if (mounted) {
        setState(() {
          if (page == 1) {
            _lessonPlanList = newItems;
          } else {
            _lessonPlanList = [..._lessonPlanList, ...newItems];
          }
        });
        updatePaginationFromMeta(result['pagination'] as Map<String, dynamic>?);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'loadPage($page) error: $e');
      if (page == 1) rethrow;
    }
  }

  @override
  void checkActiveFilter() {
    setState(() {
      _hasActiveFilter = computeHasActiveFilter();
    });
  }

  @override
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('rpp_');
    _summaryData = null; // Force re-fetch from API
    _kpiData = null;
    loadLessonPlans(useCache: false);
  }

  /// Loads exact RPP counts grouped by subject+status AND the global
  /// KPI block (weekly / monthly / open / ai / approved / rejected)
  /// from `/rpp/summary`. Runs concurrently with the paginated list
  /// load — does not block the UI.
  Future<void> _loadSummaryData() async {
    try {
      final result = await LessonPlanService.getLessonPlanSummaryWithKpi(
        teacherId: widget.teacherId,
        academicYearId: _getAcademicYearId(),
        status: _selectedStatusFilter,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      if (mounted) {
        setState(() {
          _summaryData = result.groups;
          _kpiData = result.kpi.isEmpty ? null : result.kpi;
        });
      }
    } catch (e) {
      // Non-fatal — summary view falls back to client-side grouping
      AppLogger.error('lesson_plan', 'Load summary error: $e');
    }
  }

  @override
  Future<void> loadLessonPlans({bool useCache = true}) async {
    final isFilteredOrSearched =
        _searchController.text.isNotEmpty || _selectedStatusFilter != null;
    final lessonPlanCacheKey = _buildLessonPlanCacheKey();

    bool showedCached = false;
    if (useCache && !isFilteredOrSearched) {
      final cached = await LocalCacheService.load(
        lessonPlanCacheKey,
        ttl: const Duration(hours: 1),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lessonPlanList = List<dynamic>.from(cached);
            _isLoading = false;
            _errorMessage = null;
          });
        }
        AppLogger.debug(
          'lesson_plan',
          'LessonPlanScreen: Data from cache (${cached.length})',
        );
        showedCached = true;
      }
    }

    resetPagination();
    if (!showedCached && mounted) {
      setState(() {
        _lessonPlanList = [];
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Load paginated list and summary counts concurrently
      await Future.wait([loadPage(1), _loadSummaryData()]);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasActiveFilter = _selectedStatusFilter != null;
        });
      }

      if (!isFilteredOrSearched && _lessonPlanList.isNotEmpty) {
        await LocalCacheService.save(lessonPlanCacheKey, _lessonPlanList);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Load RPP error: $e');
      if (mounted && _lessonPlanList.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    } finally {
      endPaginationReset();
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  /// FAB tap entry point — drives the format-first flow:
  ///   1. Frame B chooser (K13 / 1 Hal / Modul Ajar / Upload File)
  ///   2a. Structured formats → Frame C setup sheet (with AI/Manual
  ///       segmented toggle + class/subject/bab/alokasi chip selects)
  ///   2b. File format → upload sheet
  ///   3. After successful generate / blank-draft / upload, push the
  ///       new row's detail screen via the format-aware dispatcher.
  ///
  /// Cancel-from-sub-sheet → reopen the chooser. Sequential sheet
  /// flows on Flutter close the chooser before the sub-sheet opens
  /// (they share the modal layer), so dismissing the sub-sheet would
  /// otherwise drop the user back to the bare list. Looping here lets
  /// the teacher pick a different format without retapping the FAB.
  Future<void> _addLessonPlan() async {
    Map<String, dynamic>? newRow;

    while (true) {
      final format = await showLessonPlanFormatChooserSheet(context);
      if (format == null || !mounted) return;

      if (format == LessonPlanFormat.file) {
        final uploadResult = await showLessonPlanUploadSheet(
          context: context,
          teacherId: widget.teacherId,
        );
        if (!mounted) return;
        if (uploadResult == null) {
          // User cancelled the upload sheet — reopen the chooser so
          // they can switch formats instead of being kicked back to
          // the list.
          continue;
        }
        newRow = uploadResult.lessonPlan;
        break;
      }

      final result = await showLessonPlanSetupSheet(
        context: context,
        format: format,
        teacherId: widget.teacherId,
      );
      if (!mounted) return;
      if (result == null) {
        continue; // same loop-back behavior for setup sheet
      }
      newRow = result.lessonPlan;
      break;
    }

    if (!mounted) return;

    // Refresh the list so the new row appears, then immediately open
    // it so the teacher can review the AI draft / start filling
    // sections in manual mode / view their uploaded file.
    await forceRefresh();
    if (!mounted) return;
    await RPPDetailPage.show(
      context: context,
      lessonPlanData: newRow,
      isNew: true,
    );
  }

  String? _getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String _buildLessonPlanCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'rpp_list_${widget.teacherId}_$academicYearId';
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'guru',
        onRefresh: forceRefresh,
        header: buildBrandHeader(languageProvider),
        kpiCard: buildBrandKpiCard(languageProvider),
        bodyChildren: [_buildBody(languageProvider)],
      ),
      floatingActionButton: FloatingActionButton(
        key: _addRppKey,
        onPressed: _addLessonPlan,
        backgroundColor: getPrimaryColor(),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Builds the body content for BrandPageLayout's bodyChildren.
  ///
  /// Returns a non-scrollable widget — BrandPageLayout owns the outer
  /// ListView and pull-to-refresh, so this body just emits a Column
  /// of section heads + cards (or skeleton / error / empty state).
  Widget _buildBody(LanguageProvider languageProvider) {
    if (_isLoading && _lessonPlanList.isEmpty && _errorMessage == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SkeletonListLoading(
          itemCount: 4,
          infoTagCount: 2,
          showActions: false,
          shrinkWrap: true,
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AppErrorState(
          message: _errorMessage,
          onRetry: forceRefresh,
          role: 'guru',
        ),
      );
    }

    if (_lessonPlanList.isEmpty) {
      final hasFilter = _searchController.text.isNotEmpty || _hasActiveFilter;
      // Wrap in a bounded SizedBox: BrandPageLayout's outer ListView
      // gives bodyChildren unbounded height, and EmptyState uses
      // `Center` + `MainAxisAlignment.center` which collapses to zero
      // size in that environment. A fixed minimum height anchors the
      // layout so the icon/title/subtitle/button actually render.
      return SizedBox(
        height: 420,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: EmptyState(
            title: languageProvider.getTranslatedText({
              'en': 'No Lesson Plans Yet',
              'id': 'Belum Ada RPP',
            }),
            subtitle: hasFilter
                ? languageProvider.getTranslatedText({
                    'en': 'No lesson plans match your search and filters',
                    'id': 'Tidak ada RPP yang sesuai pencarian dan filter',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Tap the "+" button to create your first lesson plan',
                    'id': 'Ketuk tombol "+" untuk membuat RPP pertama Anda',
                  }),
            icon: Icons.description_outlined,
            buttonText: hasFilter
                ? languageProvider.getTranslatedText({
                    'en': 'Clear Filters',
                    'id': 'Hapus Filter',
                  })
                : null,
            onPressed: hasFilter
                ? () {
                    _searchController.clear();
                    clearAllFilters();
                  }
                : null,
          ),
        ),
      );
    }

    // Frame A is a flat list grouped by date, not by subject. The
    // legacy `LessonPlanSummaryView` (rotating multi-color subject
    // groups) was retired together with the legacy header — its
    // colors didn't fit the cobalt-themed brand layout.
    return _buildLessonPlanList();
  }

  /// Renders the list as a Column inside BrandPageLayout's outer
  /// ListView. The legacy ListView.builder + scroll-controller-driven
  /// pagination is replaced by a "Load more" footer button — the
  /// outer scroll is owned by BrandPageLayout and doesn't expose a
  /// listener.
  Widget _buildLessonPlanList() {
    // Bucket entries into "today" and "earlier" by `created_at` date
    // so we can render mockup-style section headers
    // ("HARI INI · SENIN" / "SEBELUMNYA") instead of a flat list.
    final today = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    final todayStr = _todayDateString();
    for (final raw in _lessonPlanList) {
      if (raw is! Map<String, dynamic>) continue;
      final d = LessonPlan.fromJson(raw).createdAtDate;
      if (d == todayStr) {
        today.add(raw);
      } else {
        earlier.add(raw);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (today.isNotEmpty) ...[
            _sectionHeader(
              'HARI INI · ${_todayDayName().toUpperCase()}',
              '${today.length} RPP',
            ),
            for (final raw in today)
              Builder(
                builder: (context) {
                  final model = LessonPlan.fromJson(raw);
                  return LessonPlanCard(
                    lessonPlan: raw,
                    statusColor: getStatusColor(model.status),
                    statusLabel: getStatusLabel(model.status),
                    primaryColor: getPrimaryColor(),
                    onView: () => viewLessonPlanDetail(raw),
                    onEdit: () => editLessonPlan(raw),
                    onDelete: () => deleteLessonPlan(raw),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
          if (earlier.isNotEmpty) ...[
            _sectionHeader('SEBELUMNYA', '${earlier.length} RPP'),
            for (final raw in earlier)
              Builder(
                builder: (context) {
                  final model = LessonPlan.fromJson(raw);
                  return LessonPlanCard(
                    lessonPlan: raw,
                    statusColor: getStatusColor(model.status),
                    statusLabel: getStatusLabel(model.status),
                    primaryColor: getPrimaryColor(),
                    onView: () => viewLessonPlanDetail(raw),
                    onEdit: () => editLessonPlan(raw),
                    onDelete: () => deleteLessonPlan(raw),
                  );
                },
              ),
          ],
          if (isLoadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: getPrimaryColor(),
                  ),
                ),
              ),
            )
          else if (hasMoreData)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _loadMoreLessonPlans,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  'Muat lebih banyak',
                  style: TextStyle(color: getPrimaryColor()),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: getPrimaryColor()),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Public load-more helper — replaces the legacy scroll-listener
  /// pagination since BrandPageLayout owns the outer ListView and
  /// doesn't expose a scroll controller. The "Muat lebih banyak"
  /// button at the bottom of the list calls this.
  Future<void> _loadMoreLessonPlans() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);
    try {
      currentPage++;
      await loadPage(currentPage);
    } finally {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  // ── Date grouping helpers (used by _buildLessonPlanList) ──

  /// Today's date in `YYYY-MM-DD` form — same shape as
  /// `LessonPlan.createdAtDate` so we can compare with `==`.
  String _todayDateString() {
    final n = DateTime.now();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  /// Indonesian day name for today, e.g. "Senin".
  String _todayDayName() {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return days[DateTime.now().weekday - 1];
  }

  /// Section header for grouped lists (HARI INI / SEBELUMNYA).
  /// Left: section label + dot separator + day name. Right: count.
  Widget _sectionHeader(String left, String right) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }
}
