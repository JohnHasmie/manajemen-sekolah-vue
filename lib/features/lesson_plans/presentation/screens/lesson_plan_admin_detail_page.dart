// Admin-side RPP detail view, now presented as a flat-flow bottom sheet
// (#145-pattern) so approval/rejection happens over the list screen instead
// of pushing a new route. Call [LessonPlanAdminDetailPage.show] instead of
// pushing this widget as a route — the Scaffold shell was replaced with a
// sheet-shaped Container to match the teacher detail sheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/status_utils_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/ui_builders_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/file_operations_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/dialog_management_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/card_builders_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/header_builder_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/content_card_builder_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_action_bar.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_review_history_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';

class LessonPlanAdminDetailPage extends StatefulWidget {
  final Map<String, dynamic> lessonPlan;

  const LessonPlanAdminDetailPage({super.key, required this.lessonPlan});

  /// Opens the admin RPP detail view as a modal bottom sheet.
  ///
  /// Matches the teacher flow — sheet takes ~95% of screen height and
  /// adjusts for keyboard inset so any approve/reject dialogs launched
  /// from inside keep their TextField visible.
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlan,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LessonPlanAdminDetailPage(lessonPlan: lessonPlan),
    );
  }

  @override
  State<LessonPlanAdminDetailPage> createState() =>
      _LessonPlanAdminDetailPageState();
}

class _LessonPlanAdminDetailPageState extends State<LessonPlanAdminDetailPage>
    with
        StatusUtilsMixin,
        UIBuildersMixin,
        FileOperationsMixin,
        DialogManagementMixin,
        CardBuildersMixin,
        HeaderBuilderMixin,
        ContentCardBuilderMixin {
  @override
  late Map<String, dynamic> lessonPlan;

  late final ScrollController _scrollController;
  final GlobalKey _historyKey = GlobalKey();
  List<Map<String, dynamic>> _reviews = const [];
  bool _loadingReviews = false;
  String? _reviewsErrorMessage;

  /// Hydrate the sheet with the FULL lesson plan record (including
  /// fresh `file_path` + `file_name` + content sections). The list
  /// endpoint sometimes returns a thinner summary, so we always
  /// re-fetch via `/rpp/{id}` to be safe.
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    lessonPlan = widget.lessonPlan;
    _refreshFromBackend();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromBackend() async {
    final id = widget.lessonPlan['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _loadingReviews = true;
      _reviewsErrorMessage = null;
    });

    // Fetch lesson plan details
    try {
      final fresh = await LessonPlanService.getLessonPlanById(id);
      if (mounted && fresh.isNotEmpty) {
        setState(() {
          // Merge — preserve any keys the list payload had that the
          // detail might not (cosmetic class/subject names, etc.).
          lessonPlan = {...lessonPlan, ...fresh};
        });
      }
    } catch (e) {
      AppLogger.warning('lesson_plan', 'admin detail refresh failed: $e');
    }

    // Fetch review history
    try {
      final reviews = await LessonPlanService.getLessonPlanReviews(id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      AppLogger.warning('lesson_plan', 'admin detail reviews fetch failed: $e');
      if (mounted) {
        setState(() {
          _reviewsErrorMessage = e.toString();
          _loadingReviews = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = LessonPlan.fromJson(lessonPlan);
    final statusColor = getStatusColor(model.status);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    // Setujui / Kembalikan / Tolak action bar at the foot of the
    // sheet. Hidden for Draft rows (teacher hasn't submitted yet) so
    // the bar doesn't show up before there's anything for the admin to
    // act on. Pulls display strings off the model so the confirmation
    // sheets render their summary card without an extra refetch.
    final formatLabel = LessonPlanFormat.fromMap(lessonPlan).shortLabel;
    final actionBar = LessonPlanAdminActionBar.maybeBuild(
      lessonPlanId: model.id,
      status: model.status,
      currentNote: model.adminNotes,
      onStatusChanged: _onStatusChanged,
      title: model.title.isNotEmpty ? model.title : 'RPP tanpa judul',
      format: model.format,
      formatLabel: formatLabel,
      subjectLabel: (model.subjectName ?? '').isNotEmpty
          ? model.subjectName!
          : '—',
      classLabel: (model.className ?? '').isNotEmpty ? model.className! : '—',
      teacherName: (model.teacherName ?? '').isNotEmpty
          ? model.teacherName!
          : '—',
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildHeader(context, statusColor),
                Expanded(child: buildScrollableBody()),
                if (actionBar != null) actionBar,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Flip status + note locally after a successful PATCH so the KPI
  /// badge updates and the buttons re-evaluate which side of the bar
  /// is visible — no list refetch needed.
  void _onStatusChanged(String newStatus, String? newNote) {
    setState(() {
      lessonPlan['status'] = newStatus;
      if (newNote != null) {
        lessonPlan['note_admin'] = newNote;
        lessonPlan['catatan_admin'] = newNote;
        lessonPlan['admin_notes'] = newNote;
      }
    });
    _refreshFromBackend();
  }



  Widget _buildReviewsError() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ColorUtils.errorLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.errorLight),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: ColorUtils.error600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gagal memuat riwayat persetujuan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                Text(
                  _reviewsErrorMessage ?? '',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ColorUtils.slate500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _refreshFromBackend,
          ),
        ],
      ),
    );
  }

  Widget buildScrollableBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStatusCard(),
          const SizedBox(height: AppSpacing.lg),
          buildInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          buildContentCard(),
          if (lessonPlan['file_path'] != null) ...[
            const SizedBox(height: AppSpacing.lg),
            buildAttachmentCard(context),
          ],
          if (_loadingReviews) ...[
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
          ] else if (_reviewsErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildReviewsError(),
          ] else if (_reviews.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            TimelineCard(
              key: _historyKey,
              rows: _reviews,
            ),
          ],
        ],
      ),
    );
  }
}
