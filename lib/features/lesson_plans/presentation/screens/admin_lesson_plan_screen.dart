// Admin RPP (lesson plan) management screen.
// Drill-down: Teacher list -> RPP list with status filtering.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/admin_lesson_plan_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/admin_lesson_plan_tour_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/filter_management_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/navigation_helper_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/build_helper_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/admin_lesson_plan_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/update_status_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/teacher_select_card.dart';

/// Admin lesson plan (RPP) review screen.
class AdminLessonPlanScreen extends ConsumerStatefulWidget {
  final String? teacherId;
  final String? teacherName;

  /// Optional status filter seeded before the first build.
  ///
  /// When the admin dashboard's PendingInboxCard taps "RPP menunggu review",
  /// this is set to `'pending_review'` so the admin lands on a pre-scoped
  /// list instead of having to open the filter sheet. Valid values mirror the
  /// lesson-plan `status` column on the backend.
  final String? initialStatusFilter;

  const AdminLessonPlanScreen({
    super.key,
    this.teacherId,
    this.teacherName,
    this.initialStatusFilter,
  });

  @override
  ConsumerState<AdminLessonPlanScreen> createState() =>
      _AdminLessonPlanScreenState();
}

class _AdminLessonPlanScreenState extends ConsumerState<AdminLessonPlanScreen>
    with
        AdminLessonPlanDataMixin,
        AdminLessonPlanTourMixin,
        FilterManagementMixin,
        NavigationHelperMixin,
        BuildHelperMixin {
  // ── State fields (bridged to mixins) ─────────
  @override
  List<dynamic> lessonPlanList = [];
  @override
  List<dynamic> teacherList = [];
  @override
  bool isLoading = true;
  @override
  String? errorMessage;
  @override
  int currentPage = 1;
  @override
  int get perPage => 10;
  @override
  bool isLoadingMore = false;
  @override
  bool hasMoreData = true;

  bool _showTeacherList = true;
  @override
  bool get showTeacherList => _showTeacherList;

  String? _selectedTeacherId;
  String? _selectedTeacherName;
  @override
  String? get selectedTeacherId => _selectedTeacherId;
  @override
  String? get selectedTeacherName => _selectedTeacherName;
  @override
  String? get selectedStatusFilter => getSelectedStatusFilter();

  @override
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  final GlobalKey menuKey = GlobalKey();
  @override
  final GlobalKey searchKey = GlobalKey();
  @override
  final GlobalKey filterKey = GlobalKey();

  // ── Lifecycle ────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Seed the status filter up-front when deep-linked from the admin
    // dashboard inbox so the first fetch already returns scoped data.
    initStatusFilter(widget.initialStatusFilter);

    if (widget.teacherId != null) {
      _showTeacherList = false;
      _selectedTeacherId = widget.teacherId;
      _selectedTeacherName = widget.teacherName;
      loadLessonPlansPaginated(reset: true);
    } else {
      _showTeacherList = true;
      loadTeachersPaginated(reset: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkAndShowTour();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMoreData &&
        !isLoading) {
      if (_showTeacherList && widget.teacherId == null) {
        loadTeachersPaginated();
      } else {
        loadLessonPlansPaginated();
      }
    }
  }

  void _updateStatus(String id, String status) {
    final lp = lessonPlanList.firstWhere((p) => p['id'] == id);
    showDialog(
      context: context,
      builder: (_) => UpdateStatusDialog(
        lessonPlanId: id,
        currentStatus: lp['status'],
        currentNote: lp['catatan'],
        onStatusUpdated: loadAllLessonPlans,
      ),
    );
  }

  void _viewDetail(Map<String, dynamic> plan) async {
    // Flat-flow bottom sheet (#145/RPP refactor) — approve/reject now
    // happens in a sheet over the admin list instead of a separate route.
    await LessonPlanAdminDetailPage.show(context: context, lessonPlan: plan);
    if (!_showTeacherList || _selectedTeacherName != null) {
      loadLessonPlansByTeacher();
    }
  }

  void _selectTeacherLocal(Map<String, dynamic> t) {
    _selectedTeacherId = t['user_id']?.toString() ?? t['id'].toString();
    _selectedTeacherName = t['name'];
    _showTeacherList = false;
    lessonPlanList = [];
    searchController.clear();
    currentPage = 1;
    loadLessonPlansPaginated(reset: true);
  }

  void _backToTeacherListLocal() {
    _selectedTeacherId = null;
    _selectedTeacherName = null;
    _showTeacherList = true;
    lessonPlanList = [];
    searchController.clear();
    currentPage = 1;
    loadTeachersPaginated(reset: true);
  }

  void _handleSearchLocal() {
    if (_showTeacherList && widget.teacherId == null) {
      loadTeachersPaginated(reset: true);
    } else {
      loadLessonPlansPaginated(reset: true);
    }
  }

  Color _getPrimaryColorForFilter() => getPrimaryColor();

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);

    if (errorMessage != null) {
      return ErrorScreen(
        errorMessage: errorMessage!,
        onRetry: _showTeacherList ? loadTeachersPaginated : loadAllLessonPlans,
      );
    }

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(lp),
          Expanded(
            child: isLoading
                ? const SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                : _showTeacherList
                ? _buildTeacherList(lp)
                : _buildLessonPlanList(lp),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    return AdminLessonPlanHeader(
      primaryColor: getPrimaryColor(),
      gradient: getGradient(),
      title: buildHeaderTitle(lp),
      subtitle: buildHeaderSubtitle(lp),
      showTeacherList: _showTeacherList,
      hasActiveFilter: hasActiveFilter,
      filterSummary: buildFilterSummary(lp),
      menuKey: menuKey,
      searchKey: searchKey,
      filterKey: filterKey,
      searchController: searchController,
      searchHint: _showTeacherList
          ? lp.getTranslatedText({
              'en': 'Search Teacher...',
              'id': 'Cari Guru...',
            })
          : lp.getTranslatedText({'en': 'Search RPP...', 'id': 'Cari RPP...'}),
      exportLabel: lp.getTranslatedText({
        'en': 'Export to Excel',
        'id': 'Export ke Excel',
      }),
      updateDataLabel: AppLocalizations.updateData.tr,
      filterTooltip: lp.getTranslatedText({'en': 'Filter', 'id': 'Filter'}),
      onBack: () {
        if (_showTeacherList || widget.teacherId != null) {
          AppNavigator.pop(context);
        } else {
          _backToTeacherListLocal();
        }
      },
      onSearch: _handleSearchLocal,
      onExport: exportToExcel,
      onRefresh: forceRefresh,
      onShowFilter: showFilterSheetLocal,
      onClearFilter: clearFilterLocal,
    );
  }

  Widget _buildTeacherList(LanguageProvider lp) {
    final query = searchController.text.toLowerCase();
    final filtered = teacherList.where((t) {
      if (query.isEmpty) return true;
      final name = t['name']?.toString().toLowerCase() ?? '';
      return name.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        title: lp.getTranslatedText({
          'en': 'No Teachers',
          'id': 'Tidak ada Guru',
        }),
        subtitle: searchController.text.isNotEmpty
            ? lp.getTranslatedText({
                'en': 'No teachers found',
                'id': 'Guru tidak ditemukan',
              })
            : lp.getTranslatedText({
                'en': 'No teacher data available',
                'id': 'Tidak ada data guru',
              }),
        icon: Icons.people,
      );
    }

    return RefreshIndicator(
      onRefresh: forceRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: filtered.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return TeacherSelectCard(
            teacher: filtered[i] as Map<String, dynamic>,
            index: i,
            onTap: () => _selectTeacherLocal(filtered[i]),
          );
        },
      ),
    );
  }

  Widget _buildLessonPlanList(LanguageProvider lp) {
    final query = searchController.text.toLowerCase();
    final filtered = lessonPlanList.where((p) {
      final model = LessonPlan.fromJson(p);
      final matchSearch =
          query.isEmpty ||
          (model.title.toLowerCase().contains(query)) ||
          ((model.subjectName ?? '').toLowerCase().contains(query)) ||
          ((model.teacherName ?? '').toLowerCase().contains(query)) ||
          ((model.className ?? '').toLowerCase().contains(query));
      final matchStatus =
          getSelectedStatusFilter() == null ||
          p['status'] == getSelectedStatusFilter();
      return matchSearch && matchStatus;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        title: lp.getTranslatedText({'en': 'No RPP', 'id': 'Tidak ada RPP'}),
        subtitle: query.isEmpty && !hasActiveFilter
            ? lp.getTranslatedText({
                'en': 'No RPP data available',
                'id': 'Tidak ada data RPP',
              })
            : lp.getTranslatedText({
                'en': 'No search results found',
                'id': 'Tidak ditemukan hasil',
              }),
        icon: Icons.description,
      );
    }

    return RefreshIndicator(
      onRefresh: forceRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: filtered.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final plan = filtered[i];
          return LessonPlanAdminCard(
            lessonPlan: plan as Map<String, dynamic>,
            index: i,
            primaryColor: getPrimaryColor(),
            onTap: () => _viewDetail(plan),
            onUpdateStatus: () => _updateStatus(plan['id'], plan['status']),
          );
        },
      ),
    );
  }
}
