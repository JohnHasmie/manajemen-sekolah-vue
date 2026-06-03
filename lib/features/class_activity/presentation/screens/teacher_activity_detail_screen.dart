// Activity detail screen — Frame A from
// `_design/teacher_class_activity_mockup.html`.
//
// Brand gradient header (kicker + title + realtime dot) over a context
// strip with the activity's subject letter avatar, title, and
// `class · subject · date · time` subtitle. A 3-cell KPI overlap card
// (Siswa · Submit · Belum) sits below the header. The body has Tipe /
// Deskripsi / Materi sections, with a sticky Hapus + Edit footer.
//
// Read-only mode (canEdit=false) flips kicker → ARSIP, dot → slate,
// hides the footer, and surfaces a download icon for export.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_context_strip.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_footer.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_kpi_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_sections.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_student_list_section.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_submission_picker_sheet.dart';

class TeacherActivityDetailScreen extends ConsumerStatefulWidget {
  /// The activity payload — same shape as the list card consumes.
  /// At minimum: `id`, `title`, `type`, `class_name`, `subject_name`.
  final Map<String, dynamic> activity;

  /// When false, render the read-only ARSIP variant (no edit footer,
  /// slate dot, download trailing icon).
  final bool canEdit;

  /// Fired when the teacher taps "Edit". Receives the **current**
  /// merged activity map (list-row payload + full detail) so the edit
  /// sheet can pre-fill from fresh data — not the stale list snapshot
  /// the screen was opened with. The parent persists changes and the
  /// returned future lets the detail screen await + re-fetch so the
  /// user sees updated values without having to pop the page.
  final Future<void> Function(Map<String, dynamic> activity)? onEdit;

  /// Fired when the teacher taps the destructive Hapus action.
  final VoidCallback? onDelete;

  /// Fired when the teacher taps the ⋯ icon — opens the quick-actions
  /// sheet (Frame D). Hidden when canEdit=false.
  final VoidCallback? onMoreActions;

  /// Fired when the teacher taps the ⤓ download icon (canEdit=false).
  final VoidCallback? onExport;

  const TeacherActivityDetailScreen({
    super.key,
    required this.activity,
    this.canEdit = true,
    this.onEdit,
    this.onDelete,
    this.onMoreActions,
    this.onExport,
  });

  @override
  ConsumerState<TeacherActivityDetailScreen> createState() =>
      _TeacherActivityDetailScreenState();
}

class _TeacherActivityDetailScreenState
    extends ConsumerState<TeacherActivityDetailScreen> {
  // Local merged map: starts with the list-row payload (so the header /
  // context strip render instantly) and is overlaid with the full
  // detail fetched from `GET /class-activity/{id}` once that completes.
  // The full record carries `description`, `material_title`,
  // `student_count`, and `submission_count` that the list summary
  // endpoint deliberately omits.
  late Map<String, dynamic> _merged;
  bool _detailLoading = false;

  /// Per-student submission rows for the preview section. Loaded on
  /// init for tugas/ujian/kuis activities; empty for aktivitas/catatan.
  List<Map<String, dynamic>> _submissions = const [];

  Map<String, dynamic> get a => _merged;

  /// True when the activity type tracks per-student submissions
  /// (tugas / ujian / kuis). Drives the Daftar Siswa section + the
  /// "Catat Submit" footer CTA.
  bool get _tracksSubmissions {
    final type = (a['type'] ?? a['tipe'] ?? '').toString().toLowerCase();
    return type == 'tugas' ||
        type == 'assignment' ||
        type == 'ujian' ||
        type == 'exam' ||
        type == 'kuis' ||
        type == 'quiz';
  }

  @override
  void initState() {
    super.initState();
    _merged = Map<String, dynamic>.from(widget.activity);
    _loadFullDetail();
  }

  Future<void> _loadFullDetail() async {
    final id = (widget.activity['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _detailLoading = true);
    try {
      final full = await getIt<ApiClassActivityService>().getActivity(id);
      if (!mounted) return;
      setState(() {
        // List-row fields stay as the base; the full detail's keys win
        // when both are present (description, material_title, KPI counts).
        _merged = {..._merged, ...full};
        _detailLoading = false;
      });
      // Once we know the type, conditionally fetch submissions for the
      // Daftar Siswa preview section.
      if (_tracksSubmissions) {
        _loadSubmissions();
      }
    } catch (e) {
      AppLogger.error('class_activity_detail', 'getActivity failed: $e');
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _loadSubmissions() async {
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final rows = await getIt<ApiClassActivityService>().getSubmissions(id);
      if (!mounted) return;
      // Sort: pending first, then late, submitted, excused.
      const order = ['pending', 'late', 'submitted', 'excused'];
      final sorted = [...rows]
        ..sort((x, y) {
          final xi = order.indexOf((x['status'] ?? 'pending').toString());
          final yi = order.indexOf((y['status'] ?? 'pending').toString());
          if (xi != yi) return xi.compareTo(yi);
          return (x['student_name'] ?? '').toString().compareTo(
            (y['student_name'] ?? '').toString(),
          );
        });
      setState(() => _submissions = sorted);
    } catch (e) {
      AppLogger.error('class_activity_detail', 'getSubmissions failed: $e');
    }
  }

  /// Edit handler — awaits the parent's edit flow (which opens the
  /// form sheet and persists changes), then re-fetches the activity
  /// so the displayed title / description / type / time pick up the
  /// new values without the user having to pop and re-open the page.
  /// Passes the current merged map so the edit form pre-fills from
  /// the freshly-loaded detail, not the stale list snapshot.
  Future<void> _onEditPressed() async {
    final cb = widget.onEdit;
    if (cb == null) return;
    await cb(Map<String, dynamic>.from(_merged));
    if (!mounted) return;
    await _loadFullDetail();
  }

  Future<void> _openCatatSubmit() async {
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;
    final saved = await showActivitySubmissionPickerSheet(
      context: context,
      activityId: id,
      activityTitle: (a['title'] ?? a['judul'] ?? '').toString(),
      // Drives the score input + Buku Nilai sync flag in the sheet.
      activityType: (a['type'] ?? a['tipe'] ?? '').toString(),
    );
    if (saved == true && mounted) {
      // Re-fetch detail (KPI counts) and the submissions preview.
      await _loadFullDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final canEdit = widget.canEdit;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'guru',
        header: _buildHeader(lp, canEdit),
        kpiCard: ActivityDetailKpiCard(a: a, lp: lp),
        bodyChildren: [_buildBody(lp, canEdit)],
      ),
      bottomNavigationBar: canEdit
          ? ActivityDetailFooter(
              lp: lp,
              tracksSubmissions: _tracksSubmissions,
              onDelete: widget.onDelete,
              onEdit: widget.onEdit == null ? null : _onEditPressed,
              onRecordSubmit: _openCatatSubmit,
            )
          : null,
    );
  }

  Widget _buildHeader(LanguageProvider lp, bool canEdit) {
    final kicker = canEdit
        ? lp.getTranslatedText({
            'en': 'Activity · Detail',
            'id': 'Kegiatan · Detail',
          })
        : lp.getTranslatedText({
            'en': 'Activity · Archive',
            'id': 'Kegiatan · Arsip',
          });
    final title = canEdit
        ? lp.getTranslatedText({
            'en': 'Activity Detail',
            'id': 'Detail Kegiatan',
          })
        : lp.getTranslatedText({'en': 'View Activity', 'id': 'Lihat Kegiatan'});

    return BrandPageHeader(
      role: 'guru',
      title: title,
      subtitle: kicker,
      isRealtimeFresh: canEdit,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      actionIcons: [
        if (canEdit && widget.onMoreActions != null)
          BrandHeaderIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: widget.onMoreActions!,
          )
        else if (!canEdit && widget.onExport != null)
          BrandHeaderIconButton(
            icon: Icons.download_rounded,
            onTap: widget.onExport!,
          ),
      ],
      bottomSlot: ActivityDetailContextStrip(a: a),
    );
  }

  Widget _buildBody(LanguageProvider lp, bool canEdit) {
    final type = (a['type'] ?? a['tipe'] ?? '-').toString();
    final desc = (a['description'] ?? a['deskripsi'] ?? '').toString().trim();
    final material = (a['material_title'] ?? a['materi'] ?? '')
        .toString()
        .trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        // Stretch so the section cards fill the row instead of hugging
        // their content (Tipe / Deskripsi were rendering centered &
        // pinched against the long-text Materi card below them).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canEdit) ActivityDetailArchiveBanner(lp: lp),
          ActivityDetailSection(
            label: lp.getTranslatedText({'en': 'Type', 'id': 'Tipe'}),
            child: ActivityDetailTypePill(type: type),
          ),
          if (desc.isNotEmpty)
            ActivityDetailSection(
              label: lp.getTranslatedText({
                'en': 'Description',
                'id': 'Deskripsi',
              }),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorUtils.slate800,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          if (material.isNotEmpty)
            ActivityDetailSection(
              label: lp.getTranslatedText({
                'en': 'Related material',
                'id': 'Materi terkait',
              }),
              child: Text(
                material,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorUtils.slate800,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          // Daftar Siswa preview — only for tugas/ujian/kuis. Shows the
          // first 5 rows (pending first, then late, submitted, excused)
          // with a "Lihat semua" CTA that opens the picker sheet.
          if (_tracksSubmissions && _submissions.isNotEmpty)
            ActivityStudentListSection(lp: lp, submissions: _submissions),
          // Subtle loading footer while the full detail is in flight —
          // the header and KPI strip already render from the list-row
          // payload, this just signals that description / materi are
          // still arriving.
          if (_detailLoading && desc.isEmpty && material.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorUtils.slate400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper for callers — opens the detail screen as a normal route.
Future<void> openTeacherActivityDetail({
  required BuildContext context,
  required Map<String, dynamic> activity,
  bool canEdit = true,
  Future<void> Function(Map<String, dynamic> activity)? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onMoreActions,
  VoidCallback? onExport,
}) {
  return AppNavigator.push<void>(
    context,
    TeacherActivityDetailScreen(
      activity: activity,
      canEdit: canEdit,
      onEdit: onEdit,
      onDelete: onDelete,
      onMoreActions: onMoreActions,
      onExport: onExport,
    ),
  );
}
