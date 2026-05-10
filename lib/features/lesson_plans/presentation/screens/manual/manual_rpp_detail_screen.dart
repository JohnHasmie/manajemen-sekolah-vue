// File-format RPP detail (Frame H) — replaces the legacy "Mengetahui
// / NIP" signature view.
//
// This screen owns the lifecycle for `format=file` lesson plans: a
// teacher uploads a PDF/DOCX and fills in the metadata via the upload
// sheet. There is no per-field structured editor and no AI
// regeneration — edits happen in [LessonPlanFormDialog], which
// handles file re-upload + metadata save against /rpp.
//
// Layout matches Frame H from `_design/teacher_rpp_mockup.html`:
//   • Slate-branded BrandPageLayout header with file kicker + title
//   • ctx-strip showing subject · class · upload metadata
//   • 3-cell KPI overlap (Tipe · MB · Status)
//   • read-only banner explaining the row is non-editable in-app
//   • file-card preview with download button
//   • 4-cell metadata grid (Bab / Kelas / Mapel / Diunggah)
//   • optional notes section
//   • AI-conversion suggestion card (defer to backend phase 2)
//
// Structured-format RPPs (k13 / rpp_1_halaman / modul_ajar) go
// through [AiRppDetailScreen] instead. The dispatcher in
// `lesson_plan_detail_screen.dart` decides which to show once at
// entry — neither screen re-checks the kind.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_pdf_builder.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_upload_sheet.dart';

class ManualRppDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const ManualRppDetailScreen({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlanData,
    bool isNew = false,
  }) {
    // Pushed as a full-page route (was modal bottom sheet) so the
    // BrandPageHeader gets full safe-area padding and the title row
    // isn't clipped by the sheet's rounded-top chrome.
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualRppDetailScreen(
          lessonPlanData: lessonPlanData,
          isNew: isNew,
        ),
      ),
    );
  }

  @override
  State<ManualRppDetailScreen> createState() => _ManualRppDetailScreenState();
}

class _ManualRppDetailScreenState extends State<ManualRppDetailScreen> {
  late Map<String, dynamic> _lessonPlanData;
  bool _isDownloading = false;

  Color get _primary => ColorUtils.getRoleColor('guru');

  // Cobalt — the teacher role color. The FILE format identity is
  // communicated via the kicker "RPP · FILE" + ctx-strip metadata,
  // not via a slate page chrome (which read as a separate theme and
  // didn't match the rest of the teacher tools).
  Color get _brand => _primary;

  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
  }

  String? get _lessonPlanId {
    final id = _lessonPlanData['id'] ??
        _lessonPlanData['rpp_id'] ??
        _lessonPlanData['lesson_plan_id'];
    final s = id?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get _filePath {
    final url = _lessonPlanData['file_url'];
    if (url != null && url.toString().trim().isNotEmpty) {
      return url.toString().trim();
    }
    final fp = _lessonPlanData['file_path'];
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }

  String _displayTitle() {
    final title = LessonPlan.fromJson(_lessonPlanData).title;
    return title.isNotEmpty ? title : 'RPP';
  }

  String _formattedContent() =>
      LessonPlanContentFormatter.format(_lessonPlanData);

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Full-page Scaffold (no longer modal bottom sheet) — lets the
    // BrandPageHeader claim the system status bar area for its
    // gradient and back-button row, matching every other teacher
    // detail screen.
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: true,
      body: BrandPageLayout(
        role: 'guru',
        header: _buildSlateHeader(),
        kpiCard: _buildKpiCard(),
        bodyChildren: [_buildBody()],
      ),
    );
  }

  // ── Header — uses the shared BrandPageHeader so the file detail
  //    chrome matches the rest of the teacher screens (Presensi /
  //    Rekap Nilai / Kegiatan Kelas). The FILE format is communicated
  //    via the kicker text and the FILE chip in the bottomSlot.

  Widget _buildSlateHeader() {
    final model = LessonPlan.fromJson(_lessonPlanData);
    final subjectName = (model.subjectName ?? '').trim();
    final className = (model.className ?? '').trim();

    final kicker = [
      'RPP · FILE',
      if (className.isNotEmpty) className.toUpperCase(),
      if (subjectName.isNotEmpty) subjectName.toUpperCase(),
    ].join(' · ');

    return BrandPageHeader(
      role: 'guru',
      title: _displayTitle(),
      subtitle: kicker,
      isRealtimeFresh: true,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      // Pencil = open the LessonPlanFormDialog (ganti file + metadata).
      // 3-dot = export menu (PDF / text).
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.edit_rounded,
          onTap: _openEditForm,
        ),
        BrandHeaderIconButton(
          icon: Icons.more_vert_rounded,
          onTap: _showExportMenu,
        ),
      ],
      bottomSlot: _buildHeaderCtxRow(model, subjectName, className),
    );
  }

  /// ctx-strip equivalent of Frame H — renders inside the header's
  /// bottomSlot. Shows the FILE format chip + subject/class/upload
  /// metadata so the teacher can see which file they're looking at.
  Widget _buildHeaderCtxRow(
    LessonPlan model,
    String subjectName,
    String className,
  ) {
    final pieces = <String>[
      'File',
      'Manual',
      if (_humanFileSize() != null) _humanFileSize()!,
      if (model.createdAtDate != '-') 'diunggah ${model.createdAtDate}',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              size: 18,
              color: _brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  [
                    if (subjectName.isNotEmpty) subjectName,
                    if (className.isNotEmpty) className,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pieces.join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI overlap card (3 cells: Tipe · MB · Status) ──

  Widget _buildKpiCard() {
    final mime = (_lessonPlanData['file_mime'] ?? '').toString();
    final tipe = mime.contains('pdf')
        ? 'PDF'
        : (mime.contains('word') || mime.contains('docx'))
            ? 'DOCX'
            : 'FILE';
    final mb = _humanFileSize() ?? '—';
    final status = (_lessonPlanData['status'] ?? '').toString();
    final stat = _statusLabel(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            _kpiCell(label: 'Tipe', value: tipe, color: ColorUtils.info600),
            _kpiDivider(),
            // Ukuran cell stays neutral cobalt — keeps the page
            // consistently teacher-themed. AI affordances are the
            // only places that should pop violet.
            _kpiCell(label: 'Ukuran', value: mb, color: _primary),
            _kpiDivider(),
            _kpiCell(
              label: 'Status',
              value: stat.label,
              color: stat.color,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 13 : 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: compact ? 0 : -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() => Container(
        width: 1,
        height: 28,
        color: ColorUtils.slate100,
      );

  ({String label, Color color}) _statusLabel(String raw) {
    final s = raw.toLowerCase();
    if (s == 'approved' || s == 'disetujui') {
      return (label: 'Disetujui', color: ColorUtils.success600);
    }
    if (s == 'rejected' || s == 'ditolak' || s == 'revision') {
      return (label: 'Revisi', color: ColorUtils.error600);
    }
    if (s == 'pending' || s == 'submitted' || s == 'menunggu') {
      return (label: 'Pending', color: ColorUtils.warning600);
    }
    return (label: 'Draf', color: ColorUtils.slate500);
  }

  // ── Body — read-only banner + file card + metadata + AI suggest ──

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ro-banner
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: ColorUtils.info600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Versi file — isi tidak bisa diedit dalam app. '
                    'Tap pencil untuk ganti file.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.info600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // file-card
          if (_filePath != null) _buildFileCard(),

          // metadata grid
          const SizedBox(height: 8),
          _buildMetadataCard(),

          // notes (optional)
          if ((LessonPlan.fromJson(_lessonPlanData).notes ?? '').isNotEmpty)
            ...[
              const SizedBox(height: 8),
              _buildNotesCard(),
            ],

          // AI conversion suggestion (defer to backend phase 2)
          const SizedBox(height: 8),
          _buildAiConversionCard(),
        ],
      ),
    );
  }

  Widget _buildFileCard() {
    final originalName = (_lessonPlanData['file_name'] ?? '').toString().trim();
    final pathName = _filePath == null
        ? ''
        : Uri.parse(_filePath!).pathSegments.last;
    final displayName = originalName.isNotEmpty ? originalName : pathName;
    final size = _humanFileSize() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 20,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName.isEmpty ? 'File terlampir' : displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  size.isEmpty ? 'Siap diunduh' : size,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDownloading ? null : _downloadAndOpenFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isDownloading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ColorUtils.slate700,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: ColorUtils.slate700,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    final model = LessonPlan.fromJson(_lessonPlanData);
    // Replaced the legacy `GridView.count(childAspectRatio: 3.0)` —
    // a fixed aspect ratio forced every cell to the same height,
    // which wasted vertical space when content was short ("7A",
    // "—") and overflowed when content was long ("Hiwar: Percakapan
    // tentang Profesi dan Cita-cita"). The IntrinsicHeight + 2-col
    // Row pair below grows to fit whichever cell has the longest
    // content per row, so neither side wastes space and overflow is
    // eliminated.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'METADATA',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _metaRow(
            _metaCell('Bab / Judul', model.title.isEmpty ? '—' : model.title),
            _metaCell(
              'Kelas',
              (model.className ?? '').isEmpty ? '—' : model.className!,
            ),
          ),
          const SizedBox(height: 8),
          _metaRow(
            _metaCell(
              'Mapel',
              (model.subjectName ?? '').isEmpty ? '—' : model.subjectName!,
            ),
            _metaCell(
              'Tahun ajaran',
              (model.academicYear ?? '').isEmpty ? '—' : model.academicYear!,
            ),
          ),
        ],
      ),
    );
  }

  /// Two-column row that stretches both cells to the height of the
  /// taller one so they read as a tidy grid without GridView's
  /// fixed-aspect baggage.
  Widget _metaRow(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      // Top-aligned now (was centered) — IntrinsicHeight stretches
      // shorter cells to match the taller sibling, so centering
      // would have left blank vertical space; left-aligned reads
      // cleaner.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
            // Up from 1 → 2 lines so longer titles ("Hiwar:
            // Percakapan tentang Profesi") wrap inside the cell
            // instead of getting truncated to a meaningless head.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    final notes = (LessonPlan.fromJson(_lessonPlanData).notes ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATATAN',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: TextStyle(
              fontSize: 12.5,
              color: ColorUtils.slate800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiConversionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.06),
            const Color(0xFF4338CA).withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Konversi ke RPP digital?',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'AI baca PDF dan susun ulang ke K13 / 1 Hal / Modul Ajar.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Conversion endpoint deferred to backend phase 2 — disable
          // for now so the UI surface lands without misleading the
          // teacher.
          Opacity(
            opacity: 0.5,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Segera',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _humanFileSize() {
    final raw = _lessonPlanData['file_size'];
    if (raw is! num) return null;
    final size = raw.toInt();
    if (size <= 0) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Edit — opens the upload sheet in edit mode (Frame H) ──
  //
  // The legacy LessonPlanFormDialog has been retired; the upload
  // sheet now powers both create and edit by accepting an optional
  // `existingPlan` argument. Edit mode renders the current file as
  // a card with a "Ganti file" CTA and pre-fills the metadata.

  Future<void> _openEditForm() async {
    if (_lessonPlanId == null) return;
    final teacherId = (_lessonPlanData['teacher_id'] ??
            _lessonPlanData['teacher']?['id'] ??
            '')
        .toString();
    final result = await showLessonPlanUploadSheet(
      context: context,
      teacherId: teacherId,
      existingPlan: _lessonPlanData,
    );
    if (result == null || !mounted) return;
    setState(() {
      // The upload sheet returns the merged (existing + patched) map,
      // so we can use it as the new local source of truth without a
      // re-fetch. If you prefer a fresh server pull, call
      // _refreshFromApi() instead.
      _lessonPlanData = Map<String, dynamic>.from(result.lessonPlan);
    });
    SnackBarUtils.showInfo(context, 'RPP file tersimpan');
  }

  Future<void> _refreshFromApi() async {
    final id = _lessonPlanId;
    if (id == null) return;
    try {
      final fresh = await LessonPlanService.getLessonPlanById(id);
      if (!mounted) return;
      if (fresh.isEmpty) {
        // No payload returned — fall back to closing the detail so
        // the list re-fetch surfaces whatever the server now has.
        AppNavigator.pop(context);
        return;
      }
      setState(() {
        _lessonPlanData = Map<String, dynamic>.from(fresh);
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'refresh after edit failed: $e');
      if (mounted) AppNavigator.pop(context);
    }
  }

  // ── Export menu (PDF / text) ──────────────────────────────────

  void _showExportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export ke PDF'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export ke Text'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToText();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _formattedContent()));
    if (mounted) {
      SnackBarUtils.showInfo(
        context,
        AppLocalizations.lessonPlanCopiedToClipboard.tr,
      );
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final bytes = await LessonPlanPdfBuilder.build(
        data: _lessonPlanData,
        formattedBody: _formattedContent(),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(context, 'RPP berhasil diexport ke PDF');
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _exportToText() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_formattedContent(), flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.lessonPlanExportedToText.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // ── Attachment download ───────────────────────────────────────

  Future<void> _downloadAndOpenFile() async {
    final fp = _filePath;
    final id = _lessonPlanId;
    if (fp == null || id == null) return;

    setState(() => _isDownloading = true);
    try {
      // Use the backend download proxy — works with
      // both local storage and S3/Minio. The mobile
      // client cannot resolve the internal Docker
      // hostname (e.g. minio:9000) in file_url.
      final bytes = await ApiService.downloadFile(
        '/rpp/$id/download',
      );
      final dir = await getTemporaryDirectory();
      // Prefer the persisted original filename so the local copy
      // matches what the teacher uploaded. Fall back to the storage
      // path's basename for legacy rows that don't have file_name.
      final originalName =
          _lessonPlanData['file_name']?.toString().trim();
      final fileName = (originalName != null && originalName.isNotEmpty)
          ? originalName
          : Uri.parse(fp).pathSegments.last;
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(bytes, flush: true);
      await OpenFile.open(localFile.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.fileSavedSuccessfully.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          ErrorUtils.getFriendlyMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
