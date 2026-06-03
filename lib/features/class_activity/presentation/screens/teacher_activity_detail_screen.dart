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
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
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
        kpiCard: _buildKpiCard(lp),
        bodyChildren: [_buildBody(lp, canEdit)],
      ),
      bottomNavigationBar: canEdit ? _buildFooter(lp) : null,
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
      bottomSlot: _contextStrip(),
    );
  }

  Widget _contextStrip() {
    final subject = (a['subject_name'] ?? a['mata_pelajaran_nama'] ?? '-')
        .toString();
    final klass = (a['class_name'] ?? a['kelas_nama'] ?? '-').toString();
    final title = (a['title'] ?? a['judul'] ?? '-').toString();
    final dateStr = (a['date'] ?? a['tanggal'] ?? '').toString();
    final timeStr = (a['time'] ?? a['jam'] ?? '').toString();
    final initial = subject.isNotEmpty ? subject[0].toUpperCase() : '?';

    final subParts = <String>[];
    final d = DateTime.tryParse(dateStr);
    if (d != null) {
      subParts.add(DateFormat('EEEE, d MMM', 'id_ID').format(d));
    }
    if (timeStr.isNotEmpty) subParts.add(_clipTime(timeStr));
    final subSuffix = subParts.isEmpty ? '' : ' · ${subParts.join(' · ')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: ColorUtils.brandCobalt,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subject · $klass$subSuffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(LanguageProvider lp) {
    // Type-aware 3-cell KPI:
    //   tugas / ujian  → Siswa · Submit · Belum  (submission tracking)
    //   aktivitas / catatan → Siswa · Target · Hari  (no submissions to track,
    //                          so we surface useful context instead of 0/0)
    final type = (a['type'] ?? a['tipe'] ?? '').toString().toLowerCase();
    final tracksSubmissions =
        type == 'tugas' ||
        type == 'assignment' ||
        type == 'ujian' ||
        type == 'exam' ||
        type == 'kuis' ||
        type == 'quiz';

    final siswa = a['student_count'] ?? a['jumlah_siswa'];

    Widget content;
    if (tracksSubmissions) {
      final submit = a['submission_count'] ?? a['jumlah_submit'];
      final belum = siswa is num && submit is num
          ? (siswa.toInt() - submit.toInt())
          : null;
      content = Row(
        children: [
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
            value: _fmt(siswa),
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Submit', 'id': 'Submit'}),
            value: _fmt(submit),
            color: ColorUtils.info600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Pending', 'id': 'Belum'}),
            value: _fmt(belum),
            color: ColorUtils.warning600,
          ),
        ],
      );
    } else {
      // aktivitas / catatan — surface Siswa · Target · Hari instead.
      final targetRole = (a['target_role'] ?? '').toString().toLowerCase();
      final targetLabel = targetRole == 'khusus'
          ? lp.getTranslatedText({'en': 'Selected', 'id': 'Khusus'})
          : lp.getTranslatedText({'en': 'All', 'id': 'Umum'});
      final dateStr = (a['date'] ?? a['tanggal'] ?? '').toString();
      final d = DateTime.tryParse(dateStr);
      final dayLabel = d != null
          ? DateFormat('EEEE', 'id_ID').format(d)
          : ((a['day'] ?? a['hari'] ?? '—').toString());
      content = Row(
        children: [
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
            value: _fmt(siswa),
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Target', 'id': 'Target'}),
            value: targetLabel,
            color: ColorUtils.violet700,
            isText: true,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Day', 'id': 'Hari'}),
            value: dayLabel,
            color: ColorUtils.info600,
            isText: true,
          ),
        ],
      );
    }

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
        child: content,
      ),
    );
  }

  String _fmt(dynamic v) => v is num ? '${v.toInt()}' : '—';

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
    bool isText = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // Numeric KPIs use display sizing; text values (Umum/Senin)
              // use a smaller weight so longer words don't overflow the
              // narrow cell.
              fontSize: isText ? 15 : 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: isText ? -0.2 : -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() =>
      Container(width: 1, height: 28, color: ColorUtils.slate100);

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
          if (!canEdit) _archiveBanner(lp),
          _section(
            label: lp.getTranslatedText({'en': 'Type', 'id': 'Tipe'}),
            child: _typePill(type),
          ),
          if (desc.isNotEmpty)
            _section(
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
            _section(
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
            _studentListSection(lp, canEdit: canEdit),
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

  Widget _archiveBanner(LanguageProvider lp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.info600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.info600.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: ColorUtils.info600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lp.getTranslatedText({
                'en':
                    'Past academic year — activity is locked. '
                    'Export PDF to archive.',
                'id':
                    'Tahun ajaran lalu — tidak bisa diubah. '
                    'Ekspor PDF untuk arsip.',
              }),
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.info600,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _typePill(String type) {
    final spec = _typeSpec(type.toLowerCase());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: spec.tint,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(spec.icon, size: 16, color: spec.fg),
        ),
        const SizedBox(width: 10),
        Text(
          spec.label,
          style: TextStyle(
            fontSize: 13,
            color: ColorUtils.slate900,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(LanguageProvider lp) {
    // Footer layout depends on whether the activity tracks submissions:
    //   tugas / ujian / kuis →  [🗑] [✎] [   Catat Submit   ]
    //                           Hapus + Edit shrink to icon-only square
    //                           buttons so the primary CTA gets a full
    //                           pill that never wraps.
    //   aktivitas / catatan  →  [   Hapus   ] [   Edit (primary)   ]
    //                           original 2-button layout.
    final tracks = _tracksSubmissions;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: tracks ? _footerWithSubmit(lp) : _footerEditPrimary(lp),
      ),
    );
  }

  /// Submission-tracked footer: small icon buttons + full-width
  /// "Catat Submit" primary CTA. Avoids text wrapping at any width.
  Widget _footerWithSubmit(LanguageProvider lp) {
    return Row(
      children: [
        _iconActionButton(
          icon: Icons.delete_outline_rounded,
          color: ColorUtils.error600,
          tooltip: lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
          onPressed: widget.onDelete,
        ),
        const SizedBox(width: 8),
        _iconActionButton(
          icon: Icons.edit_rounded,
          color: ColorUtils.slate700,
          tooltip: lp.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
          onPressed: widget.onEdit == null ? null : _onEditPressed,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _openCatatSubmit,
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
              label: Text(
                lp.getTranslatedText({
                  'en': 'Record submit',
                  'id': 'Catat Submit',
                }),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.brandCobalt,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Aktivitas / catatan footer: original Hapus | Edit (primary).
  Widget _footerEditPrimary(LanguageProvider lp) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(
                lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorUtils.error600,
                side: BorderSide(color: ColorUtils.slate200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: widget.onEdit == null ? null : _onEditPressed,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text(lp.getTranslatedText({'en': 'Edit', 'id': 'Edit'})),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.brandCobalt,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Square-ish icon-only action button used in the submission footer
  /// so Hapus + Edit don't compete with Catat Submit for label space.
  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: ColorUtils.slate200),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  /// Daftar Siswa preview card — focused on the actionable Belum bucket.
  ///
  /// Drops the old "Lihat semua siswa" tail (which opened the same sheet
  /// as the footer Catat Submit — pure redundancy) in favor of:
  ///   • a status breakdown strip at the top (Belum N · Sudah N · …)
  ///     so the teacher gets a one-glance summary
  ///   • only the Belum rows inline (max 5), since those are the ones
  ///     a teacher actually scans the list for
  ///   • a "+N belum lainnya" tail line ONLY when the bucket overflows;
  ///     no separate CTA — the footer's Catat Submit is the only entry
  ///     to the editable sheet
  ///   • a tiny "Semua sudah submit ✓" empty-state when the Belum
  ///     bucket is cleared, instead of an empty section
  Widget _studentListSection(LanguageProvider lp, {required bool canEdit}) {
    int belum = 0, sudah = 0, telat = 0, izin = 0;
    final pendingRows = <Map<String, dynamic>>[];
    for (final r in _submissions) {
      switch ((r['status'] ?? 'pending').toString()) {
        case 'submitted':
          sudah++;
          break;
        case 'late':
          telat++;
          break;
        case 'excused':
          izin++;
          break;
        default:
          belum++;
          pendingRows.add(r);
      }
    }
    final preview = pendingRows.take(5).toList();
    final extraBelum = pendingRows.length - preview.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lp.getTranslatedText({
                      'en': 'Student list',
                      'id': 'Daftar Siswa',
                    }).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Text(
                  '${_submissions.length} siswa',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Status breakdown strip — replaces the redundant "Lihat semua"
          // tail with at-a-glance counts. Only renders the buckets that
          // have rows so it stays compact for fresh activities.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (belum > 0)
                  _statusBreakdownPill(
                    count: belum,
                    label: 'Belum',
                    spec: _statusPillSpec('pending'),
                  ),
                if (sudah > 0)
                  _statusBreakdownPill(
                    count: sudah,
                    label: 'Sudah',
                    spec: _statusPillSpec('submitted'),
                  ),
                if (telat > 0)
                  _statusBreakdownPill(
                    count: telat,
                    label: 'Telat',
                    spec: _statusPillSpec('late'),
                  ),
                if (izin > 0)
                  _statusBreakdownPill(
                    count: izin,
                    label: 'Izin',
                    spec: _statusPillSpec('excused'),
                  ),
              ],
            ),
          ),
          // Belum bucket — the actionable section. Empty state when the
          // bucket is cleared signals "all caught up".
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: ColorUtils.success600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lp.getTranslatedText({
                        'en': 'All students recorded',
                        'id': 'Semua siswa sudah dicatat',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.success600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              height: 1,
              color: ColorUtils.slate100,
            ),
            for (int i = 0; i < preview.length; i++) ...[
              if (i > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  height: 1,
                  color: ColorUtils.slate100,
                ),
              _studentRow(preview[i]),
            ],
            if (extraBelum > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Text(
                  '+ $extraBelum siswa lainnya belum submit',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// One pill in the breakdown strip. Tinted background, colored count
  /// + tiny status word inside. Used as a glanceable summary at the
  /// top of the Daftar Siswa card.
  Widget _statusBreakdownPill({
    required int count,
    required String label,
    required _StatusSpec spec,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: spec.fg,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: spec.fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> r) {
    final name = (r['student_name'] ?? '-').toString();
    final status = (r['status'] ?? 'pending').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final spec = _statusPillSpec(status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: ColorUtils.slate700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: spec.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              spec.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: spec.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusSpec _statusPillSpec(String s) {
    switch (s) {
      case 'submitted':
        return _StatusSpec(
          label: 'Sudah',
          tint: ColorUtils.success600.withValues(alpha: 0.12),
          fg: ColorUtils.success600,
        );
      case 'late':
        return _StatusSpec(
          label: 'Telat',
          tint: ColorUtils.warning600.withValues(alpha: 0.14),
          fg: ColorUtils.warning600,
        );
      case 'excused':
        return _StatusSpec(
          label: 'Izin',
          tint: ColorUtils.info600.withValues(alpha: 0.12),
          fg: ColorUtils.info600,
        );
      case 'pending':
      default:
        return _StatusSpec(
          label: 'Belum',
          tint: ColorUtils.slate100,
          fg: ColorUtils.slate700,
        );
    }
  }

  String _clipTime(String s) {
    if (s.length >= 5) return s.substring(0, 5).replaceAll(':', '.');
    return s.replaceAll(':', '.');
  }

  _ActivityTypeSpec _typeSpec(String type) {
    switch (type) {
      case 'tugas':
      case 'assignment':
        return _ActivityTypeSpec(
          icon: Icons.assignment_turned_in_rounded,
          tint: const Color(0xFFDBEAFE),
          fg: ColorUtils.info600,
          label: 'Tugas',
        );
      case 'ujian':
      case 'exam':
      case 'kuis':
      case 'quiz':
        return _ActivityTypeSpec(
          icon: Icons.science_rounded,
          tint: const Color(0xFFFEF3C7),
          fg: ColorUtils.warning600,
          label: 'Ujian',
        );
      case 'catatan':
      case 'note':
        return _ActivityTypeSpec(
          icon: Icons.sticky_note_2_rounded,
          tint: ColorUtils.slate100,
          fg: ColorUtils.slate600,
          label: 'Catatan',
        );
      case 'aktivitas':
      case 'activity':
      default:
        return _ActivityTypeSpec(
          icon: Icons.groups_2_rounded,
          tint: const Color(0xFFEDE9FE),
          fg: ColorUtils.violet700,
          label: 'Aktivitas',
        );
    }
  }
}

class _ActivityTypeSpec {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String label;
  const _ActivityTypeSpec({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.label,
  });
}

/// Visual spec for a submission status pill (Sudah / Belum / Telat / Izin)
/// in the Daftar Siswa preview rows.
class _StatusSpec {
  final String label;
  final Color tint;
  final Color fg;
  const _StatusSpec({
    required this.label,
    required this.tint,
    required this.fg,
  });
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
