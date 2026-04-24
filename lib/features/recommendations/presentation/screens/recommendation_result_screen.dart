// Shows AI-generated learning recommendations for a student.
//
// Presented as a draggable bottom sheet (flat-flow pattern) on top of the
// student list sheet. Built from the shared [BottomSheetHeader] +
// [BottomSheetFooter] scaffolding so the header gradient, drag handle,
// close button, and footer button row stay consistent with the rest of
// the teacher bottom sheets (filter sheets, grade editor, etc.). Pops
// with a bool indicating whether any status was toggled so the student
// sheet can refresh its counts.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_card.dart';
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

  /// Opens this view as a modal bottom sheet. Returns `true` when any
  /// recommendation status was toggled so the caller can refresh counts.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> student,
    required Map<String, dynamic> classData,
    bool isHomeroomView = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LearningRecommendationResultScreen(
        teacher: teacher,
        student: student,
        classData: classData,
        isHomeroomView: isHomeroomView,
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

  @override
  Widget build(BuildContext context) {
    final primary = getPrimaryColor();
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppNavigator.pop(context, _statusChanged);
        }
      },
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
                  title: 'Rekomendasi Belajar',
                  subtitle: 'Siswa: $_studentName',
                  icon: Icons.lightbulb_rounded,
                  primaryColor: primary,
                  onClose: () => AppNavigator.pop(context, _statusChanged),
                ),
                Flexible(child: _buildBody()),
                // Wali Kelas view is read-only for rec content — the
                // aggregated list may include recs authored by other
                // teachers and the bulk-edit screen edits them together,
                // so we drop the footer entirely in that mode. Status
                // toggles stay available inline on each card (backend
                // authorizes wali kelas to toggle status cross-teacher),
                // and the header's close button still dismisses the sheet.
                if (!_isLoading &&
                    _recommendations.isNotEmpty &&
                    !widget.isHomeroomView)
                  KeyedSubtree(
                    key: _editButtonKey,
                    child: BottomSheetFooter(
                      primaryLabel: 'Edit Hasil',
                      secondaryLabel: 'Tutup',
                      primaryColor: primary,
                      onPrimary: navigateToEdit,
                      onSecondary: () =>
                          AppNavigator.pop(context, _statusChanged),
                    ),
                  ),
              ],
            ),
          ),
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
      child: Column(
        children: [
          // Summary stats bar
          _buildSummaryBar(),

          // Status filter chips
          _buildStatusFilterChips(),

          // Priority filter chips
          _buildPriorityFilterChips(),

          // Recommendation list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Tidak ada rekomendasi dengan filter ini',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate400,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 12,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final rec = filtered[index];
                      final recId = rec['id']?.toString() ?? '';
                      return RecommendationCard(
                        rec: rec,
                        listKey: index == 0 ? _recommendationListKey : null,
                        isUpdatingStatus: _updatingIds.contains(recId),
                        onToggleStatus: () => _toggleStatus(rec),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final highCount = _countByPriority('high');
    final mediumCount = _countByPriority('medium');
    final lowCount = _countByPriority('low');
    final completedCount = _countByStatus('completed');
    final primary = getPrimaryColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryStatItem(
            icon: Icons.auto_awesome_rounded,
            value: '${_recommendations.length}',
            label: 'Total',
            color: primary,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.check_circle_rounded,
            value: '$completedCount',
            label: 'Diterapkan',
            color: ColorUtils.emerald500,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.priority_high_rounded,
            value: '$highCount',
            label: 'Tinggi',
            color: ColorUtils.red500,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.remove_rounded,
            value: '$mediumCount',
            label: 'Sedang',
            color: ColorUtils.amber500,
          ),
          _verticalDivider(),
          _SummaryStatItem(
            icon: Icons.arrow_downward_rounded,
            value: '$lowCount',
            label: 'Rendah',
            color: ColorUtils.corporateBlue500,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: ColorUtils.slate100,
    );
  }

  Widget _buildStatusFilterChips() {
    final primary = getPrimaryColor();
    final pendingCount = _countByStatus('pending');
    final completedCount = _countByStatus('completed');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _FilterChip(
            label: 'Semua',
            isActive: _statusFilter == 'all',
            color: primary,
            onTap: () => setState(() => _statusFilter = 'all'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Belum Diterapkan ($pendingCount)',
            isActive: _statusFilter == 'pending',
            color: ColorUtils.amber500,
            onTap: () => setState(() => _statusFilter = 'pending'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Diterapkan ($completedCount)',
            isActive: _statusFilter == 'completed',
            color: ColorUtils.emerald500,
            onTap: () => setState(() => _statusFilter = 'completed'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Semua Prioritas',
              isActive: _priorityFilter == 'all',
              color: ColorUtils.slate500,
              outlined: true,
              onTap: () => setState(() => _priorityFilter = 'all'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Tinggi',
              isActive: _priorityFilter == 'high',
              color: ColorUtils.red500,
              outlined: true,
              onTap: () => setState(() => _priorityFilter = 'high'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Sedang',
              isActive: _priorityFilter == 'medium',
              color: ColorUtils.amber500,
              outlined: true,
              onTap: () => setState(() => _priorityFilter = 'medium'),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Rendah',
              isActive: _priorityFilter == 'low',
              color: ColorUtils.corporateBlue500,
              outlined: true,
              onTap: () => setState(() => _priorityFilter = 'low'),
            ),
          ],
        ),
      ),
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
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip for priority/status filtering.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.color,
    this.outlined = false,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
