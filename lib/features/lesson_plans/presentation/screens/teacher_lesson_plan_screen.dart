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
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/widgets/view_toggle_button.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_summary_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/add_lesson_plan_action_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_filter_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_tour_mixin.dart';
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
        LessonPlanTourMixin,
        LessonPlanStatusMixin,
        LessonPlanCrudMixin {
  List<dynamic> _lessonPlanList = [];
  List<Map<String, dynamic>>? _summaryData; // From /rpp/summary API
  bool _isLoading = true;
  bool _isSummaryView = true; // Default to summary/grouped view
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  String? _selectedStatusFilter;
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
  bool get hasActiveFilter => _hasActiveFilter;

  @override
  set hasActiveFilter(bool value) {
    _hasActiveFilter = value;
  }

  @override
  GlobalKey get filterKey => _filterKey;

  @override
  GlobalKey get addRppKey => _addRppKey;

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
      _hasActiveFilter = _selectedStatusFilter != null;
    });
  }

  @override
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('rpp_');
    _summaryData = null; // Force re-fetch from API
    loadLessonPlans(useCache: false);
  }

  /// Loads exact RPP counts grouped by subject+status from `/rpp/summary`.
  /// Runs concurrently with paginated list load — does not block the UI.
  Future<void> _loadSummaryData() async {
    try {
      final data = await LessonPlanService.getLessonPlanSummary(
        teacherId: widget.teacherId,
        academicYearId: _getAcademicYearId(),
        status: _selectedStatusFilter,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      if (mounted) {
        setState(() {
          _summaryData = data;
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
          checkAndShowTour();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) checkAndShowTour();
      });
    }
  }

  void _addLessonPlan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddLessonPlanActionSheet(
        primaryColor: getPrimaryColor(),
        onUploadManual: showLessonPlanFormDialog,
        onGenerateAI: showGenerateLessonPlanFormDialog,
      ),
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
    final languageProvider = ref.read(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          LessonPlanHeader(
            searchController: _searchController,
            onSearch: loadLessonPlans,
            onFilter: showFilterSheet,
            hasActiveFilter: _hasActiveFilter,
            primaryColor: getPrimaryColor(),
            filterKey: _filterKey,
            filterSummary: buildFilterSummary(languageProvider),
            onClearFilters: clearAllFilters,
            trailing: ViewToggleButton(
              currentMode: _isSummaryView ? ViewMode.grid : ViewMode.list,
              availableModes: const [ViewMode.grid, ViewMode.list],
              onChanged: (mode) => setState(() {
                _isSummaryView = mode == ViewMode.grid;
              }),
            ),
          ),
          Expanded(child: _buildBody(languageProvider)),
        ],
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

  /// Builds the body content: loading → error → empty → list.
  /// Uses TeacherAsyncView for consistent state management.
  Widget _buildBody(LanguageProvider languageProvider) {
    return TeacherAsyncView(
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isEmpty: _lessonPlanList.isEmpty,
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: languageProvider.getTranslatedText({
        'en': 'No Lesson Plans Yet',
        'id': 'Belum Ada RPP',
      }),
      emptySubtitle: languageProvider.getTranslatedText({
        'en': _searchController.text.isNotEmpty || _hasActiveFilter
            ? 'No lesson plans match your search and filters'
            : 'Tap the "+" button to create your first lesson plan',
        'id': _searchController.text.isNotEmpty || _hasActiveFilter
            ? 'Tidak ada RPP yang sesuai dengan pencarian dan filter'
            : 'Ketuk tombol "+" untuk membuat RPP pertama Anda',
      }),
      emptyIcon: Icons.description_outlined,
      emptyActionLabel: _searchController.text.isNotEmpty || _hasActiveFilter
          ? languageProvider.getTranslatedText({
              'en': 'Clear Filters',
              'id': 'Hapus Filter',
            })
          : null,
      onEmptyAction: _searchController.text.isNotEmpty || _hasActiveFilter
          ? () {
              _searchController.clear();
              clearAllFilters();
            }
          : null,
      childBuilder: () => AppRefreshIndicator(
        onRefresh: forceRefresh,
        role: 'guru',
        child: _isSummaryView ? _buildSummaryView() : _buildLessonPlanList(),
      ),
    );
  }

  /// Fetches all RPPs for a given subject (no page limit) for expanded view.
  Future<List<Map<String, dynamic>>> _loadSubjectItems(String subjectId) async {
    final result = await LessonPlanService.getLessonPlansPaginated(
      teacherId: widget.teacherId,
      subjectId: subjectId,
      academicYearId: _getAcademicYearId(),
      status: _selectedStatusFilter,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      page: 1,
      limit: 200, // Fetch all items for this subject
    );
    final items = List<dynamic>.from(result['data'] ?? []);
    return items.cast<Map<String, dynamic>>();
  }

  Widget _buildSummaryView() {
    return LessonPlanSummaryView(
      summaryData: _summaryData,
      lessonPlans: _lessonPlanList,
      primaryColor: getPrimaryColor(),
      statusLabel: getStatusLabel,
      statusColor: getStatusColor,
      onView: viewLessonPlanDetail,
      onEdit: editLessonPlan,
      onDelete: deleteLessonPlan,
      onLoadSubjectItems: _loadSubjectItems,
    );
  }

  Widget _buildLessonPlanList() {
    return ListView.builder(
      controller: paginationScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 100, left: 4, right: 4),
      itemCount: _lessonPlanList.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _lessonPlanList.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: getPrimaryColor(),
                ),
              ),
            ),
          );
        }

        final lessonPlan = _lessonPlanList[index] as Map<String, dynamic>;
        final model = LessonPlan.fromJson(lessonPlan);

        return LessonPlanCard(
          lessonPlan: lessonPlan,
          statusColor: getStatusColor(model.status),
          statusLabel: getStatusLabel(model.status),
          primaryColor: getPrimaryColor(),
          onView: () => viewLessonPlanDetail(lessonPlan),
          onEdit: () => editLessonPlan(lessonPlan),
          onDelete: () => deleteLessonPlan(lessonPlan),
        );
      },
    );
  }
}
