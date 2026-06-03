// Detail-page hero builder for the admin RPP sheet.
//
// Replaces the legacy "title card + vertical key-value Informasi RPP list"
// layout with a single status-tinted hero matching mockup Frame B1:
//
//   ┌────────────────────────────────────────────┐
//   │ [K13 pill]  [Menunggu pill]      2 jam     │
//   │ Sistem Persamaan Linear Tiga Variabel —    │
//   │ Pertemuan 1                                │
//   │                                            │
//   │ (SR) Siti Rohimah, S.Pd. · Matematika      │
//   │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
//   │ MAPEL      │ KELAS                         │
//   │ Matematika │ XII IPA 1                     │
//   │ SEMESTER   │ ALOKASI                       │
//   │ Ganjil…    │ 2 × 45 menit                  │
//   └────────────────────────────────────────────┘
//
// Background is status-tinted (amber for Menunggu, green for Disetujui,
// red for Ditolak). The mixin signature stays the same — buildInfoCard()
// is now a no-op so the calling order in lesson_plan_admin_detail_page
// keeps working without edits.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin CardBuildersMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  LessonPlan get _lp => LessonPlan.fromJson(lessonPlan);

  /// New: single hero card that fuses status + identity + meta grid.
  /// Caller continues to invoke `buildStatusCard()` first, then
  /// `buildInfoCard()` — the latter is now a no-op so we don't ship
  /// two cards.
  Widget buildStatusCard() {
    final model = _lp;
    final fmt = LessonPlanFormat.fromMap(lessonPlan);
    final kind = _statusKind(model.status);
    final (bg, accentFg, accentBg) = _heroPalette(kind);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Colors.white],
          stops: const [0, 0.7],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: accentBg),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topRow(fmt, model.status, accentFg, accentBg, kind),
          const SizedBox(height: 8),
          Text(
            model.title.isNotEmpty ? model.title : 'RPP tanpa judul',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              height: 1.3,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          _teacherRow(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: ColorUtils.slate200,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: _metaGrid(model),
          ),
          if (_lp.hasAdminNotes) ...[
            const SizedBox(height: 12),
            _adminNoteBlock(accentFg, accentBg),
          ],
        ],
      ),
    );
  }

  Widget _topRow(
    LessonPlanFormat fmt,
    String status,
    Color accentFg,
    Color accentBg,
    _StatusKind kind,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _formatPill(fmt),
        const SizedBox(width: 6),
        _statusPill(status, accentFg, accentBg, kind),
        const Spacer(),
        Text(
          _relativeTime(_lp.createdAt),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate500,
          ),
        ),
      ],
    );
  }

  Widget _formatPill(LessonPlanFormat fmt) {
    final (bg, fg) = switch (fmt) {
      LessonPlanFormat.k13 => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1E40AF),
      ),
      LessonPlanFormat.modulAjar => (
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
      ),
      LessonPlanFormat.rpp1Halaman => (
        const Color(0xFFCCFBF1),
        const Color(0xFF0F766E),
      ),
      LessonPlanFormat.file => (ColorUtils.slate100, ColorUtils.slate700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        fmt.shortLabel,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusPill(String status, Color fg, Color bg, _StatusKind kind) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (kind) {
              _StatusKind.menunggu => Icons.schedule_rounded,
              _StatusKind.disetujui => Icons.check_circle_rounded,
              _StatusKind.ditolak => Icons.cancel_rounded,
              _StatusKind.unknown => Icons.help_outline_rounded,
            },
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 3),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teacherRow() {
    final teacher = (_lp.teacherName ?? '').trim();
    final subject = (_lp.subjectName ?? '').trim();
    final initials = _initials(teacher);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColorUtils.brandCobalt,
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: teacher.isEmpty ? '—' : teacher,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate800,
                  ),
                ),
                if (subject.isNotEmpty)
                  TextSpan(
                    text: ' · $subject',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _metaGrid(LessonPlan model) {
    final mapel = (model.subjectName ?? '').trim();
    final kelas = (model.className ?? '').trim();
    final tahun = (model.academicYear ?? '').trim();
    final semester = (model.semester ?? '').trim();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metaCell('Mata Pelajaran', mapel.isEmpty ? '—' : mapel),
            ),
            const SizedBox(width: 12),
            Expanded(child: _metaCell('Kelas', kelas.isEmpty ? '—' : kelas)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metaCell(
                'Semester',
                [semester, tahun].where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _metaCell('Tanggal Dibuat', _lp.createdAtDate)),
          ],
        ),
      ],
    );
  }

  Widget _metaCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
      ],
    );
  }

  Widget _adminNoteBlock(Color accentFg, Color accentBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentFg, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATATAN ADMIN',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: accentFg,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _lp.adminNotes ?? '',
            style: TextStyle(
              fontSize: 11.5,
              color: accentFg,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// `buildInfoCard()` used to render a vertical "Guru Pengajar: …"
  /// list. The new hero (above) absorbs that information into the meta
  /// grid + teacher row, so this method returns nothing and the
  /// calling site stays unchanged.
  Widget buildInfoCard() => const SizedBox.shrink();

  // ── helpers ─────────────────────────────────────────────────────

  String _initials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  String _statusLabel(String raw) {
    switch (_statusKind(raw)) {
      case _StatusKind.menunggu:
        return 'Menunggu';
      case _StatusKind.disetujui:
        return 'Disetujui';
      case _StatusKind.ditolak:
        return 'Ditolak';
      case _StatusKind.unknown:
        return raw.isEmpty ? 'Draft' : raw;
    }
  }

  _StatusKind _statusKind(String raw) {
    final s = raw.toLowerCase();
    if (s == 'pending' || s == 'menunggu' || s == 'submitted') {
      return _StatusKind.menunggu;
    }
    if (s == 'approved' || s == 'disetujui') return _StatusKind.disetujui;
    if (s == 'rejected' || s == 'ditolak' || s == 'revision') {
      return _StatusKind.ditolak;
    }
    return _StatusKind.unknown;
  }

  /// (background tint, accent foreground, accent light bg) per status.
  /// Background is a soft Tailwind-50 → white gradient; accent foreground
  /// is the 700-weight color used for the status pill text + admin
  /// note left border.
  (Color, Color, Color) _heroPalette(_StatusKind kind) {
    switch (kind) {
      case _StatusKind.menunggu:
        return (
          const Color(0xFFFEF3C7),
          ColorUtils.warning700,
          const Color(0xFFFEF3C7),
        );
      case _StatusKind.disetujui:
        return (
          const Color(0xFFDCFCE7),
          ColorUtils.success700,
          const Color(0xFFDCFCE7),
        );
      case _StatusKind.ditolak:
        return (
          const Color(0xFFFEE2E2),
          ColorUtils.error700,
          const Color(0xFFFEE2E2),
        );
      case _StatusKind.unknown:
        return (ColorUtils.slate100, ColorUtils.slate700, ColorUtils.slate100);
    }
  }

  BoxDecoration buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      border: Border.all(color: ColorUtils.slate200),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    );
  }

  // Abstract methods from other mixins
  Widget buildDetailItem(String label, String value);
  String getStatusLabelDetail(String? status);
  Color getStatusColor(String status);
}

enum _StatusKind { menunggu, disetujui, ditolak, unknown }
