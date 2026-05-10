// Per-student recommendation detail — Frame C of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Cobalt brand header (kicker `Kelas <name> · Rekomendasi`, title
// `<student name>`), hero card with 56dp avatar + name + meta + violet
// `n REC` count pill + status row (`AI · n saran` / `n PENDING` /
// `n SELESAI`). Below: status filter chip strip, then the rec card list
// (RecommendationCard with priority accent + AI Reasoning + share
// affordances + Tandai Diterapkan).
//
// Pushes as a MaterialPageRoute (was a 92% modal bottom sheet) so the
// brand header gets its full SafeArea and the share sheet doesn't
// fight a parent sheet's scroll controller. Pops with `true` when
// any rec mutated so the student list can refresh counts.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_card.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_share_sheet.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_share_history_sheet.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/result_tour_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/result_fetch_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/result_navigation_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Shows AI-generated learning recommendations for a student in a class.
///
/// Presented as a bottom sheet — call [show] instead of pushing this widget
/// as a route. The sheet pops with a bool indicating whether any status
/// toggles happened during the session.
class LearningRecommendationResultScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> student;
  final Map<String, dynamic> classData;

  /// Whether this sheet was opened from the Wali Kelas tab. When true the
  /// rec list is fetched by `homeroom_class_id` (cross-teacher scope) and
  /// content edits are disabled — only status toggles remain available,
  /// which the backend will authorize for either the rec's author or the
  /// class's wali kelas.
  final bool isHomeroomView;

  const LearningRecommendationResultScreen({
    super.key,
    required this.teacher,
    required this.student,
    required this.classData,
    this.isHomeroomView = false,
  });

  /// Pushes this view as a full Material page route. Returns `true`
  /// when any recommendation status was toggled / shared / replied so
  /// the caller can refresh counts.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> student,
    required Map<String, dynamic> classData,
    bool isHomeroomView = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningRecommendationResultScreen(
          teacher: teacher,
          student: student,
          classData: classData,
          isHomeroomView: isHomeroomView,
        ),
      ),
    );
  }

  @override
  ConsumerState<LearningRecommendationResultScreen> createState() =>
      _LearningRecommendationResultScreenState();
}

class _LearningRecommendationResultScreenState
    extends ConsumerState<LearningRecommendationResultScreen>
    with ResultTourMixin, ResultFetchMixin, ResultNavigationMixin {
  bool _isLoading = true;
  List<dynamic> _recommendations = [];
  String _errorMessage = '';
  final GlobalKey _recommendationListKey = GlobalKey();
  final GlobalKey _editButtonKey = GlobalKey();
  String _priorityFilter = 'all';
  String _statusFilter = 'all'; // 'all', 'pending', 'completed'

  /// Tracks which recommendation IDs are currently updating status.
  final Set<String> _updatingIds = {};

  /// Whether any recommendation status was changed during this session.
  /// Returned to the caller on dismiss so it can refresh data.
  bool _statusChanged = false;

  @override
  void initState() {
    super.initState();
    fetchRecommendations();
  }

  @override
  GlobalKey get recommendationListKey => _recommendationListKey;

  @override
  GlobalKey get editButtonKey => _editButtonKey;

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String get errorMessage => _errorMessage;

  @override
  set errorMessage(String value) => _errorMessage = value;

  @override
  List<dynamic> get recommendations => _recommendations;

  @override
  set recommendations(List<dynamic> value) => _recommendations = value;

  String get _studentName => Student.fromJson(widget.student).name;

  List<dynamic> get _filteredRecommendations {
    var filtered = _recommendations.toList();

    // Filter by status
    if (_statusFilter != 'all') {
      filtered = filtered.where((rec) {
        final status = rec['status']?.toString().toLowerCase() ?? 'pending';
        return status == _statusFilter;
      }).toList();
    }

    // Filter by priority
    if (_priorityFilter != 'all') {
      filtered = filtered.where((rec) {
        final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
        return priority == _priorityFilter;
      }).toList();
    }

    return filtered;
  }

  int _countByPriority(String priority) {
    return _recommendations.where((rec) {
      return (rec['priority']?.toString().toLowerCase() ?? 'low') == priority;
    }).length;
  }

  int _countByStatus(String status) {
    return _recommendations.where((rec) {
      return (rec['status']?.toString().toLowerCase() ?? 'pending') == status;
    }).length;
  }

  /// Toggles a recommendation's status between pending and completed.
  Future<void> _toggleStatus(Map<String, dynamic> rec) async {
    final recId = rec['id']?.toString();
    if (recId == null || recId.isEmpty) return;

    final currentStatus = rec['status']?.toString().toLowerCase() ?? 'pending';
    final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';

    setState(() => _updatingIds.add(recId));

    try {
      // The backend now requires `teacher_id` — it verifies the teacher
      // belongs to the authenticated user and then authorizes the update
      // only if that teacher is either the rec's author OR the wali kelas
      // of the rec's class. In wali-kelas mode this is what lets the user
      // toggle status on recs authored by other teachers.
      final teacherId = widget.teacher['id'] ?? '';
      await getIt<ApiRecommendationService>().updateStatus(
        recommendationId: recId,
        status: newStatus,
        teacherId: teacherId,
      );

      // Update local state
      if (mounted) {
        setState(() {
          rec['status'] = newStatus;
          if (newStatus == 'completed') {
            rec['completed_at'] = DateTime.now().toIso8601String();
          } else {
            rec['completed_at'] = null;
          }
          _updatingIds.remove(recId);
          _statusChanged = true;
        });

        // Invalidate caches so the flow back up the stack (student list,
        // class summary cards, and history strip) all reflect the new
        // "diterapkan" counts on the next read.
        //
        // - recommendation_result_*: this student's rec list cache.
        // - recommendation_summary_$classId: drives the class card totals
        //   + the by_status/by_priority badges on the class screen.
        // - recommendation_history_${classId}_*: drives the date-grouped
        //   history strip on the class screen (by_status counts).
        final teacherId = widget.teacher['id'] ?? '';
        final classId = widget.classData['id']?.toString() ?? '';
        final studentId = widget.student['id']?.toString() ?? '';
        await Future.wait([
          LocalCacheService.invalidate(
            'recommendation_result_${teacherId}_${classId}_$studentId',
          ),
          LocalCacheService.clearStartingWith(
            'recommendation_summary_$classId',
          ),
          LocalCacheService.clearStartingWith(
            'recommendation_history_$classId',
          ),
        ]);

        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            newStatus == 'completed'
                ? 'Rekomendasi ditandai sudah diterapkan'
                : 'Rekomendasi dikembalikan ke belum diterapkan',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingIds.remove(recId));
        SnackBarUtils.showError(context, 'Gagal memperbarui status');
      }
    }
  }

  /// Open the Bagikan ke Wali sheet for [rec]. Pulls the wali roster
  /// from the rec's student payload (eager-loaded by the backend on
  /// the wali-kelas scope) and falls back to a single placeholder
  /// when the parent details aren't denormalised.
  Future<void> _openShareSheet(Map<String, dynamic> rec) async {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    final parents = _resolveAvailableParents();

    final ok = await showRecommendationShareSheet(
      context: context,
      recommendation: rec,
      teacherId: teacherId,
      availableParents: parents,
    );
    if (ok == true && mounted) {
      // Refetch so the rec card flips to TERKIRIM with the right counts.
      await fetchRecommendations(useCache: false);
      setState(() => _statusChanged = true);
    }
  }

  /// Open the Riwayat Pengiriman sheet for [rec]. The sheet refreshes
  /// after Tarik / Edit & Kirim Ulang internally; we just need to
  /// re-fetch when it pops with a dirty flag.
  Future<void> _openShareHistorySheet(Map<String, dynamic> rec) async {
    final dirty = await showRecommendationShareHistorySheet(
      context: context,
      recommendation: rec,
      onShareAgain: () => _openShareSheet(rec),
    );
    if (dirty == true && mounted) {
      await fetchRecommendations(useCache: false);
      setState(() => _statusChanged = true);
    }
  }

  /// Best-effort recipient list from the rec's student payload. The
  /// student may carry `parents: [{user_id, name, phone, relation}, …]`
  /// when the wali roster is denormalised, otherwise we generate a
  /// minimal Ibu/Ayah placeholder so the sheet still functions and the
  /// teacher can fill in details.
  List<Map<String, dynamic>> _resolveAvailableParents() {
    final raw = widget.student['parents'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (p) => {
              'parent_user_id':
                  p['user_id']?.toString() ?? p['parent_user_id']?.toString(),
              'parent_name': (p['name'] ?? p['parent_name'] ?? 'Wali')
                  .toString(),
              'parent_phone': (p['phone'] ?? p['parent_phone'])?.toString(),
              'parent_relation':
                  (p['relation'] ?? p['parent_relation'] ?? 'wali')
                      .toString()
                      .toLowerCase(),
            },
          )
          .toList();
    }
    // Fallback: surface a single editable placeholder so the wali
    // kelas can still hit the share flow when the API hasn't denormed
    // the wali roster yet.
    final motherName = widget.student['mother_name']?.toString();
    final fatherName = widget.student['father_name']?.toString();
    final fallback = <Map<String, dynamic>>[];
    if (motherName != null && motherName.isNotEmpty) {
      fallback.add({
        'parent_user_id': null,
        'parent_name': motherName,
        'parent_phone': widget.student['mother_phone']?.toString(),
        'parent_relation': 'ibu',
      });
    }
    if (fatherName != null && fatherName.isNotEmpty) {
      fallback.add({
        'parent_user_id': null,
        'parent_name': fatherName,
        'parent_phone': widget.student['father_phone']?.toString(),
        'parent_relation': 'ayah',
      });
    }
    return fallback;
  }

  // ── KPI / hero counters ─────────────────────────────────────────

  int get _pendingCount => _countByStatus('pending');
  int get _inProgressCount => _countByStatus('in_progress');
  int get _completedCount => _countByStatus('completed');
  int get _totalRecs => _recommendations.length;
  int get _shareReadCount {
    var read = 0;
    for (final rec in _recommendations) {
      final n = (rec['share_read_count'] as num?)?.toInt() ?? 0;
      if (n > 0) read++;
    }
    return read;
  }

  String? get _className {
    final raw = widget.classData['name'] ?? widget.classData['nama'];
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get _nis {
    final raw = widget.student['student_number'] ?? widget.student['nis'];
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get _orderNo {
    final raw =
        widget.student['urutan'] ??
        widget.student['no_urut'] ??
        widget.student['order'];
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s.padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppNavigator.pop(context, _statusChanged);
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            // Brand header + hero card overlap. The hero is bigger
            // than a KPI strip (avatar + name + meta + count pill +
            // status row), so we keep the gradient's reserved
            // overlap zone small (36dp) and Transform.translate the
            // hero down enough that only its top 36dp sits inside
            // the gradient — the rest hangs below the rounded
            // gradient edge. Same idiom as the raport hero card.
            Stack(
              clipBehavior: Clip.none,
              children: [
                BrandPageHeader(
                  role: 'guru',
                  subtitle: _className != null
                      ? 'Kelas $_className · Rekomendasi'
                      : 'Rekomendasi',
                  title: _studentName,
                  kpiOverlayHeight: 36,
                  onBackPressed: () =>
                      AppNavigator.pop(context, _statusChanged),
                  // Header-level "Edit" pencil retired — each rec
                  // card now owns its own edit affordance, so the
                  // wali edits one rec at a time instead of opening a
                  // bulk-edit page from the header.
                  actionIcons: const [],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: Transform.translate(
                    // Push the hero down so it overlaps the gradient
                    // by only ~36dp at the top (the rest sits on
                    // the slate-50 scaffold below). Without this the
                    // hero hides the brand title.
                    offset: const Offset(0, 86),
                    child: _buildHeroCard(),
                  ),
                ),
              ],
            ),
            // Reserve the space the hero takes below the gradient.
            // Roughly 86dp + a small breathing margin.
            const SizedBox(height: 96),
            if (!_isLoading && _recommendations.isNotEmpty)
              _buildStatusFilterStrip(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final cobalt = ColorUtils.brandCobalt;
    final violet = ColorUtils.violet700;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeroAvatar(name: _studentName, color: cobalt),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _studentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (_nis != null) 'NIS $_nis',
                        if (_orderNo != null) 'No $_orderNo',
                        if (_className != null) 'Kelas $_className',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeroCountPill(value: _totalRecs, color: violet),
            ],
          ),
          if (_totalRecs > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _HeroPill(label: 'AI · $_totalRecs saran', color: violet),
                if (_pendingCount > 0)
                  _HeroPill(
                    label: '$_pendingCount PENDING',
                    color: ColorUtils.warning600,
                  ),
                if (_inProgressCount > 0)
                  _HeroPill(label: '$_inProgressCount PROSES', color: cobalt),
                if (_completedCount > 0)
                  _HeroPill(
                    label: '$_completedCount SELESAI',
                    color: ColorUtils.success600,
                  ),
                if (_shareReadCount > 0)
                  _HeroPill(
                    label: '$_shareReadCount DIBACA WALI',
                    color: ColorUtils.success600,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilterStrip() {
    final cobalt = ColorUtils.brandCobalt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _ChipPill(
              label: 'Semua',
              count: _totalRecs,
              active: _statusFilter == 'all',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'all'),
            ),
            const SizedBox(width: 6),
            _ChipPill(
              label: 'Pending',
              count: _pendingCount,
              active: _statusFilter == 'pending',
              color: ColorUtils.warning600,
              onTap: () => setState(() => _statusFilter = 'pending'),
            ),
            const SizedBox(width: 6),
            _ChipPill(
              label: 'Proses',
              count: _inProgressCount,
              active: _statusFilter == 'in_progress',
              color: cobalt,
              onTap: () => setState(() => _statusFilter = 'in_progress'),
            ),
            const SizedBox(width: 6),
            _ChipPill(
              label: 'Selesai',
              count: _completedCount,
              active: _statusFilter == 'completed',
              color: ColorUtils.success600,
              onTap: () => setState(() => _statusFilter = 'completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonListLoading(itemCount: 3, infoTagCount: 2);
    }
    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: forceRefresh,
        role: 'guru',
      );
    }
    if (_recommendations.isEmpty) {
      return const EmptyState(
        icon: Icons.lightbulb_outline,
        title: 'Belum Ada Rekomendasi',
        subtitle: 'Generate rekomendasi dari halaman kelas terlebih dahulu',
      );
    }
    final filtered = _filteredRecommendations;
    return AppRefreshIndicator(
      onRefresh: forceRefresh,
      role: 'guru',
      child: filtered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Tidak ada rekomendasi dengan filter ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate400),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final rec = filtered[index];
                final recId = rec['id']?.toString() ?? '';
                return RecommendationCard(
                  rec: rec,
                  listKey: index == 0 ? _recommendationListKey : null,
                  isUpdatingStatus: _updatingIds.contains(recId),
                  onToggleStatus: () => _toggleStatus(rec),
                  onShareToParent: () => _openShareSheet(rec),
                  onViewShareHistory: () => _openShareHistorySheet(rec),
                  // Per-rec edit pencil — replaces the bulk edit
                  // action that used to live on the page header.
                  onEdit: widget.isHomeroomView
                      ? null
                      : () => navigateToEditRec(
                          Map<String, dynamic>.from(rec as Map),
                        ),
                );
              },
            ),
    );
  }
}

// ─── Hero + chip pill helpers ──────────────────────────────────────

class _HeroAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _HeroAvatar({required this.name, required this.color});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HeroCountPill extends StatelessWidget {
  final int value;
  final Color color;

  const _HeroCountPill({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
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

class _HeroPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HeroPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ChipPill({
    required this.label,
    required this.count,
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
        ),
      ),
    );
  }
}
