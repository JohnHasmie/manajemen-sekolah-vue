// Per-class student list — Frame B of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Cobalt brand header (kicker `Kelas <name> · Rekomendasi`, title
// `Daftar Siswa`), 4-cell KPI overlap (Siswa / Rekomendasi / Pending /
// Selesai), search bar + status filter chip strip, then a list of
// student rows. Each row carries:
//   • 40dp avatar (cobalt; red-tinted when the student has zero recs
//     to flag attention).
//   • Name + `NIS · No <urutan>` meta.
//   • Pillrow of status counts (PENDING amber / PROSES cobalt /
//     SELESAI green / Belum ada rec slate).
//   • Boxed `n REC` count pill on the right (red tint when ≥3 pending).
//   • Slate chevron-right indicator.
//
// Tapping a row pushes the per-student rec detail screen
// ([LearningRecommendationResultScreen]). When the detail pops with
// a status change we propagate that back so the class hub can refresh
// summary + history caches.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/mixins/tour_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class LearningRecommendationStudentScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> classData;

  /// Whether this screen was opened from the Wali Kelas tab. When true
  /// the status counts + rec list are fetched by `homeroom_class_id`
  /// (cross-teacher scope), and the detail screen disables content
  /// edits for recs the current teacher didn't author.
  final bool isHomeroomView;

  const LearningRecommendationStudentScreen({
    super.key,
    required this.teacher,
    required this.classData,
    this.isHomeroomView = false,
  });

  /// Pushes the student list as a full Material page route. Returns
  /// `true` when the teacher toggled at least one rec status during
  /// the session so the caller can refresh cached summary / history.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> classData,
    bool isHomeroomView = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningRecommendationStudentScreen(
          teacher: teacher,
          classData: classData,
          isHomeroomView: isHomeroomView,
        ),
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
  final TextEditingController _searchController = TextEditingController();

  /// Per-student counts: { studentId: { total, pending, completed } }.
  Map<String, Map<String, int>> _statusCounts = {};
  bool _isLoadingStatus = false;

  /// 'all' / 'has_recs' / 'has_pending' / 'all_completed'.
  String _statusFilter = 'all';

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

  String get _className =>
      (widget.classData['name'] ?? widget.classData['nama'] ?? '').toString();

  // ── Filtering ────────────────────────────────────────────────────

  List<dynamic> get _filteredStudents {
    var filtered = _students.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final model = Student.fromJson(s as Map<String, dynamic>);
        return model.name.toLowerCase().contains(q) ||
            model.studentNumber.toLowerCase().contains(q);
      }).toList();
    }
    if (_statusFilter != 'all') {
      filtered = filtered.where((s) {
        final id = (s as Map<String, dynamic>)['id']?.toString() ?? '';
        final c = _statusCounts[id];
        final total = c?['total'] ?? 0;
        final completed = c?['completed'] ?? 0;
        final pending = c?['pending'] ?? 0;
        switch (_statusFilter) {
          case 'has_recs':
            return total > 0;
          case 'has_pending':
            return pending > 0;
          case 'all_completed':
            return total > 0 && completed == total;
          default:
            return true;
        }
      }).toList();
    }
    return filtered;
  }

  // ── KPI bundle ───────────────────────────────────────────────────

  int get _totalRecs =>
      _statusCounts.values.fold(0, (s, c) => s + (c['total'] ?? 0));
  int get _totalPending =>
      _statusCounts.values.fold(0, (s, c) => s + (c['pending'] ?? 0));
  int get _totalCompleted =>
      _statusCounts.values.fold(0, (s, c) => s + (c['completed'] ?? 0));
  int get _studentsWithRecs =>
      _statusCounts.values.where((c) => (c['total'] ?? 0) > 0).length;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    loadStudents();
    _loadStatusCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppNavigator.pop(context, _statusChanged);
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                BrandPageHeader(
                  role: 'guru',
                  subtitle: _className.isNotEmpty
                      ? 'Kelas $_className · Rekomendasi'
                      : 'Rekomendasi',
                  title: 'Daftar Siswa',
                  kpiOverlayHeight: 45,
                  onBackPressed: () =>
                      AppNavigator.pop(context, _statusChanged),
                ),
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
            if (!_isLoadingStatus && _statusCounts.isNotEmpty)
              _buildStatusChipStrip(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiStrip() {
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
            _kpiCell('${_students.length}', 'SISWA', ColorUtils.brandCobalt),
            _kpiDivider(),
            _kpiCell('$_totalRecs', 'REKOMENDASI', ColorUtils.violet700),
            _kpiDivider(),
            _kpiCell('$_totalPending', 'PENDING', ColorUtils.warning600),
            _kpiDivider(),
            _kpiCell('$_totalCompleted', 'SELESAI', ColorUtils.success600),
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
                  hintText: 'Cari nama atau NIS…',
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

  Widget _buildStatusChipStrip() {
    final cobalt = ColorUtils.brandCobalt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _StatusChip(
              label: 'Semua',
              count: _students.length,
              active: _statusFilter == 'all',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'all'),
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'Punya rec',
              count: _studentsWithRecs,
              active: _statusFilter == 'has_recs',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'has_recs'),
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'Pending',
              count: _totalPending,
              active: _statusFilter == 'has_pending',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'has_pending'),
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'Selesai',
              count: _totalCompleted,
              active: _statusFilter == 'all_completed',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'all_completed'),
            ),
          ],
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
        onRetry: _refreshAll,
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
          _buildSectionHead(filtered.length),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptySearch()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildStudentRow(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHead(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'SISWA · $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            'urut absen',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(dynamic student) {
    final raw = Map<String, dynamic>.from(student as Map);
    final model = Student.fromJson(raw);
    final id = raw['id']?.toString() ?? '';
    final counts = _statusCounts[id];
    final total = counts?['total'] ?? 0;
    final pending = counts?['pending'] ?? 0;
    final completed = counts?['completed'] ?? 0;
    final inProgress = (total - pending - completed).clamp(0, total);
    final hasRecs = total > 0;
    final orderNo =
        raw['urutan']?.toString() ??
        raw['no_urut']?.toString() ??
        raw['order']?.toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onStudentTap(raw, model.name),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(name: model.name, hasRecs: hasRecs),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.name.isNotEmpty ? model.name : 'Siswa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(model.studentNumber, orderNo),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusPills(
                      pending: pending,
                      inProgress: inProgress,
                      completed: completed,
                      total: total,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RecCountPill(value: total, isAlert: pending >= 3),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaLine(String nis, String? orderNo) {
    final bits = <String>[
      if (nis.isNotEmpty) 'NIS · $nis',
      if (orderNo != null && orderNo.isNotEmpty)
        'No ${orderNo.padLeft(2, '0')}',
    ];
    return bits.isEmpty ? '-' : bits.join(' · ');
  }

  Widget _buildStatusPills({
    required int pending,
    required int inProgress,
    required int completed,
    required int total,
  }) {
    final pills = <Widget>[];
    if (total == 0) {
      pills.add(
        _StatusMiniPill(label: 'Belum ada rec', color: ColorUtils.slate500),
      );
    } else {
      if (pending > 0) {
        pills.add(
          _StatusMiniPill(
            label: '$pending PENDING',
            color: ColorUtils.warning600,
          ),
        );
      }
      if (inProgress > 0) {
        pills.add(
          _StatusMiniPill(
            label: '$inProgress PROSES',
            color: ColorUtils.brandCobalt,
          ),
        );
      }
      if (completed > 0) {
        pills.add(
          _StatusMiniPill(
            label: '$completed SELESAI',
            color: ColorUtils.success600,
          ),
        );
      }
    }
    return Wrap(spacing: 4, runSpacing: 4, children: pills);
  }

  Widget _buildEmptySearch() {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Tidak Ada Hasil',
      subtitle: _searchQuery.isNotEmpty
          ? 'Tidak ada siswa cocok dengan "$_searchQuery"'
          : 'Tidak ada siswa yang cocok dengan filter',
      buttonText: 'Reset Filter',
      onPressed: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _statusFilter = 'all';
        });
      },
    );
  }

  Future<void> _onStudentTap(Map<String, dynamic> student, String name) async {
    final result = await LearningRecommendationResultScreen.show(
      context: context,
      teacher: widget.teacher,
      student: student,
      classData: widget.classData,
      isHomeroomView: widget.isHomeroomView,
    );
    if (result == true && mounted) {
      _statusChanged = true;
      await _loadStatusCounts();
    }
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final bool hasRecs;

  const _Avatar({required this.name, required this.hasRecs});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = hasRecs ? ColorUtils.brandCobalt : ColorUtils.violet700;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }
}

class _StatusMiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusMiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }
}

class _RecCountPill extends StatelessWidget {
  final int value;
  final bool isAlert;

  const _RecCountPill({required this.value, required this.isAlert});

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == 0;
    final color = isEmpty
        ? ColorUtils.slate500
        : (isAlert ? ColorUtils.error600 : ColorUtils.slate900);
    final bg = isEmpty
        ? ColorUtils.slate50
        : (isAlert
              ? ColorUtils.error600.withValues(alpha: 0.06)
              : Colors.white);
    final border = isEmpty
        ? ColorUtils.slate200
        : (isAlert
              ? ColorUtils.error600.withValues(alpha: 0.18)
              : ColorUtils.slate200);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEmpty ? '—' : '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'REC',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? color : ColorUtils.slate200,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? color : ColorUtils.slate600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white : ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active ? color : ColorUtils.slate600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
