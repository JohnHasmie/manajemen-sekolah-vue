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
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';

class TeacherActivityDetailScreen extends ConsumerStatefulWidget {
  /// The activity payload — same shape as the list card consumes.
  /// At minimum: `id`, `title`, `type`, `class_name`, `subject_name`.
  final Map<String, dynamic> activity;

  /// When false, render the read-only ARSIP variant (no edit footer,
  /// slate dot, download trailing icon).
  final bool canEdit;

  /// Fired when the teacher taps "Edit". Caller decides whether to
  /// open the edit sheet or navigate elsewhere.
  final VoidCallback? onEdit;

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
  Map<String, dynamic> get a => widget.activity;

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
                  '$subject · $klass${subParts.isEmpty ? '' : ' · ${subParts.join(' · ')}'}',
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
    // 3-cell KPI: Siswa · Submit · Belum.
    // Backend wiring pending — for now we read these out of the
    // activity payload (when the future detail endpoint adds them)
    // and fall back to en-dash placeholders so the card looks
    // intentionally pre-populated rather than buggy-empty.
    final siswa = a['student_count'] ?? a['jumlah_siswa'];
    final submit = a['submission_count'] ?? a['jumlah_submit'];
    final belum = siswa is num && submit is num
        ? (siswa.toInt() - submit.toInt())
        : null;

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
        ),
      ),
    );
  }

  String _fmt(dynamic v) => v is num ? '${v.toInt()}' : '—';

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
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
        child: Row(
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
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    lp.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
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
        ),
      ),
    );
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

/// Helper for callers — opens the detail screen as a normal route.
Future<void> openTeacherActivityDetail({
  required BuildContext context,
  required Map<String, dynamic> activity,
  bool canEdit = true,
  VoidCallback? onEdit,
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
