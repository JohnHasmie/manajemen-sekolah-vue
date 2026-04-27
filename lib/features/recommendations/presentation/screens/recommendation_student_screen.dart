// Student selection sheet for learning recommendations.
//
// Presented as a draggable bottom sheet (flat-flow pattern) on top of the
// class list screen. Call [LearningRecommendationStudentScreen.show] — do not
// push this widget directly. Pops with a `bool` indicating whether any
// recommendation status changed during the session so the caller can decide
// whether to force-refresh its cached summary / history.
//
// Redesigned with per-student recommendation status indicators,
// summary stats bar, status filter chips, and professional card layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/mixins/tour_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Lists students in a class for the learning recommendation flow.
/// Shows per-student recommendation status (total, pending, completed).
class LearningRecommendationStudentScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> classData;

  /// Whether this sheet was opened from the Wali Kelas tab. When true the
  /// student status counts + rec list are fetched by `homeroom_class_id`
  /// (cross-teacher scope), and the result sheet disables content edits
  /// for recs the current teacher didn't author.
  final bool isHomeroomView;

  const LearningRecommendationStudentScreen({
    super.key,
    required this.teacher,
    required this.classData,
    this.isHomeroomView = false,
  });

  /// Opens the student list as a modal bottom sheet. Returns `true` when the
  /// teacher toggled at least one recommendation status during the session,
  /// so the caller can refresh cached summary + history data instead of
  /// serving stale rows.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> classData,
    bool isHomeroomView = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LearningRecommendationStudentScreen(
        teacher: teacher,
        classData: classData,
        isHomeroomView: isHomeroomView,
      ),
    );
  }

  @override
  ConsumerState<LearningRecommendationStudentScreen> createState() =>
      _LearningRecommendationStudentScreenState();
}

class _LearningRecommendationStudentScreenState
    extends ConsumerState<LearningRecommendationStudentScreen>
    with DataLoadingMixin, TourMixin {
  bool _isLoading = true;
  List<dynamic> _students = [];
  String _errorMessage = '';
  final GlobalKey _studentListKey = GlobalKey();
  String _searchQuery = '';
  final FocusNode _searchFocus = FocusNode();

  /// Per-student recommendation status counts: { studentId: { total, pending, completed } }
  Map<String, Map<String, int>> _statusCounts = {};
  bool _isLoadingStatus = false;

  /// Filter: 'all', 'has_recommendations', 'all_completed', 'has_pending'
  String _statusFilter = 'all';

  /// Whether any recommendation status changed during this student-screen
  /// session (bubbled up from the result screen). Propagated back to the
  /// class screen on pop so it can force-refresh summary + history instead
  /// of serving stale cache.
  bool _statusChanged = false;

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  List<dynamic> get students => _students;

  @override
  set students(List<dynamic> value) => _students = value;

  @override
  String get errorMessage => _errorMessage;

  @override
  set errorMessage(String value) => _errorMessage = value;

  @override
  GlobalKey get studentListKey => _studentListKey;

  @override
  Map<String, dynamic> get classData => widget.classData;

  @override
  String? get academicYearId =>
      ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

  @override
  Map<String, String> get teacher => widget.teacher;

  Color get _primaryColor =>
      ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');

  String get _className =>
      widget.classData['name'] ?? widget.classData['nama'] ?? 'Daftar Siswa';

  List<dynamic> get _filteredStudents {
    var filtered = _students.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final model = Student.fromJson(s as Map<String, dynamic>);
        return model.name.toLowerCase().contains(q) ||
            model.studentNumber.toLowerCase().contains(q);
      }).toList();
    }

    // Status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((s) {
        final studentId = (s as Map<String, dynamic>)['id']?.toString() ?? '';
        final counts = _statusCounts[studentId];
        final total = counts?['total'] ?? 0;
        final completed = counts?['completed'] ?? 0;
        final pending = counts?['pending'] ?? 0;

        switch (_statusFilter) {
          case 'has_recommendations':
            return total > 0;
          case 'all_completed':
            return total > 0 && completed == total;
          case 'has_pending':
            return pending > 0;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  // Avatar tinting: previously rotated through 8 pastel hues which made the
  // list feel like a parade of colored dots. The redesign uses a single
  // neutral slate scheme — identity is carried by the initials, and the
  // meaningful color (emerald all-done / amber has-pending) is reserved for
  // the status ring + inline status row. Less chroma = easier to scan.

  @override
  void initState() {
    super.initState();
    loadStudents();
    _loadStatusCounts();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && students.isNotEmpty) checkAndShowTour();
    });
  }

  Future<void> _loadStatusCounts() async {
    setState(() => _isLoadingStatus = true);
    try {
      final classId = widget.classData['id']?.toString() ?? '';
      final teacherId = widget.teacher['id'] ?? '';
      // In wali kelas mode scope the counts by `homeroom_class_id` so we
      // aggregate recs from every authoring teacher in the homeroom. In
      // mengajar mode scope by teacher so the counts reflect only the
      // current teacher's authored recs.
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final counts = await getIt<ApiRecommendationService>()
          .getStudentStatusCounts(
            classId: classId,
            teacherId: widget.isHomeroomView ? null : teacherId,
            homeroomClassId: widget.isHomeroomView ? classId : null,
            academicYearId: ayId,
          );
      if (mounted) {
        setState(() {
          _statusCounts = counts;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      AppLogger.error('recommendation', 'Failed to load status counts: $e');
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([forceRefresh(), _loadStatusCounts()]);
  }

  /// Summary counts across all students
  int get _totalRecommendations {
    int sum = 0;
    for (final c in _statusCounts.values) {
      sum += c['total'] ?? 0;
    }
    return sum;
  }

  int get _totalCompleted {
    int sum = 0;
    for (final c in _statusCounts.values) {
      sum += c['completed'] ?? 0;
    }
    return sum;
  }

  int get _totalPending {
    int sum = 0;
    for (final c in _statusCounts.values) {
      sum += c['pending'] ?? 0;
    }
    return sum;
  }

  int get _studentsWithRecommendations {
    return _statusCounts.values.where((c) => (c['total'] ?? 0) > 0).length;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return PopScope(
      // Intercept system back / swipe-back so we can pass `_statusChanged`
      // back to the class screen even when the user doesn't tap the header
      // close button.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppNavigator.pop(context, _statusChanged);
        }
      },
      child: GestureDetector(
        onTap: () => _searchFocus.unfocus(),
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Container(
            constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BottomSheetHeader(
                    title: _className,
                    subtitle: 'Pilih siswa untuk melihat rekomendasi',
                    icon: Icons.people_rounded,
                    primaryColor: _primaryColor,
                    // Pass _statusChanged back so the class screen can decide
                    // whether to force-refresh its summary + history caches.
                    onClose: () => AppNavigator.pop(context, _statusChanged),
                  ),
                  Flexible(
                    child: Container(
                      color: ColorUtils.slate50,
                      child: _buildBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: () => _refreshAll(),
        role: 'guru',
      );
    }

    if (_students.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Tidak Ada Siswa',
        subtitle: 'Belum ada data siswa di kelas ini',
      );
    }

    final filtered = _filteredStudents;

    return AppRefreshIndicator(
      onRefresh: _refreshAll,
      role: 'guru',
      child: Column(
        children: [
          // Summary stats bar — always visible (shows 0s or loading)
          _buildSummaryBar(),

          // Status filter chips — show once status data is loaded
          if (!_isLoadingStatus) _buildStatusFilterChips(),

          // Search bar
          _buildSearchBar(),

          // Count indicator
          _buildCountBar(filtered.length),

          // Student list
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptySearch()
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Sheet has no FAB — just a small bottom breathing
                    // room so the last tile doesn't butt against the
                    // sheet's safe-area edge.
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 16,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final isFirst = index == 0;
                      final isLast = index == filtered.length - 1;
                      return _buildStudentTile(student, index, isFirst, isLast);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        // slate200 so this white bar reads as a distinct surface over the
        // slate50 scaffold rather than bleeding into the background.
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryStatItem(
            icon: Icons.people_alt_rounded,
            value: '${_students.length}',
            label: 'Siswa',
            color: _primaryColor,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.auto_awesome_rounded,
            value: '$_totalRecommendations',
            label: 'Rekomendasi',
            color: ColorUtils.corporateBlue500,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.check_circle_rounded,
            value: '$_totalCompleted',
            label: 'Diterapkan',
            color: ColorUtils.emerald500,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.schedule_rounded,
            value: '$_totalPending',
            label: 'Belum',
            color: ColorUtils.amber500,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: ColorUtils.slate100,
    );
  }

  Widget _buildStatusFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Semua Siswa',
              isActive: _statusFilter == 'all',
              color: _primaryColor,
              onTap: () => setState(() => _statusFilter = 'all'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Ada Rekomendasi ($_studentsWithRecommendations)',
              isActive: _statusFilter == 'has_recommendations',
              color: ColorUtils.corporateBlue500,
              onTap: () =>
                  setState(() => _statusFilter = 'has_recommendations'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Ada Belum Diterapkan',
              isActive: _statusFilter == 'has_pending',
              color: ColorUtils.amber500,
              onTap: () => setState(() => _statusFilter = 'has_pending'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Semua Diterapkan',
              isActive: _statusFilter == 'all_completed',
              color: ColorUtils.emerald500,
              onTap: () => setState(() => _statusFilter = 'all_completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          focusNode: _searchFocus,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: TextStyle(fontSize: 12.5, color: ColorUtils.slate700),
          decoration: InputDecoration(
            hintText: 'Cari nama atau NIS...',
            hintStyle: TextStyle(fontSize: 12.5, color: ColorUtils.slate400),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Icon(
                Icons.search_rounded,
                size: 18,
                color: _searchQuery.isNotEmpty
                    ? _primaryColor
                    : ColorUtils.slate400,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 0,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: ColorUtils.slate400,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_alt_rounded, size: 11, color: _primaryColor),
                const SizedBox(width: 3),
                Text(
                  '$count siswa${_searchQuery.isNotEmpty ? ' ditemukan' : ''}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_isLoadingStatus)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: ColorUtils.slate400,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Memuat status...',
                  style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
                ),
              ],
            )
          else if (_searchQuery.isEmpty)
            Text(
              'Ketuk untuk lihat rekomendasi',
              style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: ColorUtils.slate300,
            ),
            const SizedBox(height: 10),
            Text(
              'Tidak ada siswa cocok',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Coba kata kunci atau filter lain',
              style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(
    dynamic student,
    int index,
    bool isFirst,
    bool isLast,
  ) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    final studentId = model.id;
    final counts = _statusCounts[studentId];
    final total = counts?['total'] ?? 0;
    final completed = counts?['completed'] ?? 0;
    final pending = counts?['pending'] ?? 0;
    final allDone = total > 0 && completed == total;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 14 : 2),
      topRight: Radius.circular(isFirst ? 14 : 2),
      bottomLeft: Radius.circular(isLast ? 14 : 2),
      bottomRight: Radius.circular(isLast ? 14 : 2),
    );

    return Material(
      key: index == 0 ? _studentListKey : null,
      color: Colors.white,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: () async {
          final statusChanged = await LearningRecommendationResultScreen.show(
            context: context,
            teacher: widget.teacher,
            student: student,
            classData: widget.classData,
            isHomeroomView: widget.isHomeroomView,
          );
          // Refresh status counts when returning if any status was toggled.
          // Also remember the change so we can propagate it to the class
          // screen on pop — once dirty, stay dirty until we pop.
          if (mounted && statusChanged == true) {
            _statusChanged = true;
            _loadStatusCounts();
          }
        },
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // slate200 so tiles read as a stack of distinct rows rather than
            // a single slab over the slate50 background.
            border: Border(
              left: BorderSide(color: ColorUtils.slate200),
              right: BorderSide(color: ColorUtils.slate200),
              top: isFirst
                  ? BorderSide(color: ColorUtils.slate200)
                  : BorderSide.none,
              bottom: BorderSide(color: ColorUtils.slate200),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                // Numbered position
                SizedBox(
                  width: 20,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate400,
                    ),
                  ),
                ),

                // Avatar with status ring
                _buildAvatar(model, allDone, total > 0),
                const SizedBox(width: 10),

                // Name + NIS + status pills
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name.isNotEmpty ? model.name : 'Siswa Tanpa Nama',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // NIS row
                      Text(
                        'NIS: ${model.studentNumber.isNotEmpty ? model.studentNumber : '-'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate400,
                        ),
                      ),
                      // Status row — always visible
                      const SizedBox(height: 3),
                      _buildInlineStatus(total, completed, pending, allDone),
                    ],
                  ),
                ),

                // Right side: mini progress or chevron
                const SizedBox(width: 6),
                if (total > 0)
                  _buildMiniProgress(completed, total, allDone)
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ColorUtils.slate300,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Student model, bool allDone, bool hasRecs) {
    // Neutral slate tile for every student. Identity sits in the initials;
    // meaningful color (emerald / amber) is reserved for the status ring so
    // a glance down the list reads as "done / pending / empty", not a
    // rainbow.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.slate200, ColorUtils.slate100],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: hasRecs
            ? Border.all(
                color: allDone
                    ? ColorUtils.emerald500.withValues(alpha: 0.55)
                    : ColorUtils.amber500.withValues(alpha: 0.45),
                width: 1.5,
              )
            : Border.all(color: ColorUtils.slate200),
      ),
      child: Center(
        child: Text(
          model.initials,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineStatus(
    int total,
    int completed,
    int pending,
    bool allDone,
  ) {
    // No recommendations yet
    if (total == 0) {
      if (_isLoadingStatus) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.2,
                color: ColorUtils.slate400,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Memuat...',
              style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
            ),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 11,
            color: ColorUtils.slate400,
          ),
          const SizedBox(width: 3),
          Text(
            'Belum ada rekomendasi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      );
    }

    // All completed
    if (allDone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 11,
            color: ColorUtils.emerald500,
          ),
          const SizedBox(width: 3),
          Text(
            '$total rekomendasi • Semua diterapkan',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ColorUtils.emerald500,
            ),
          ),
        ],
      );
    }

    // Has pending
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 11,
          color: pending > 0 ? ColorUtils.amber500 : ColorUtils.slate400,
        ),
        const SizedBox(width: 3),
        Text(
          '$completed/$total diterapkan',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: pending > 0 ? ColorUtils.amber500 : ColorUtils.slate400,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniProgress(int completed, int total, bool allDone) {
    final progress = total > 0 ? completed / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                backgroundColor: ColorUtils.slate100,
                color: allDone ? ColorUtils.emerald500 : ColorUtils.amber500,
              ),
              Text(
                '$completed',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: allDone ? ColorUtils.emerald500 : ColorUtils.amber500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single stat item in the summary bar.
class _SummaryStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip for status filtering.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: isActive ? color : ColorUtils.slate200),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : ColorUtils.slate500,
            ),
          ),
        ),
      ),
    );
  }
}
