import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Builds the embedded bottom-sheet chrome for the attendance UI.
///
/// Mirrors Frame A from `_design/teacher_attendance_detail_mockup.html`:
/// gradient header with kicker + title + realtime dot, followed by an
/// inline KPI strip showing live status counts. The status counts are
/// computed by the consumer so this mixin stays presentation-only.
mixin AttendanceUIEmbeddedMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──

  /// Live status counts from the consumer (`{hadir, terlambat, sakit,
  /// izin, alpha}`). Empty before the first student loads.
  Map<String, int> get embeddedStatusCounts;

  /// Total number of students currently in the filtered list. Used by
  /// the section head ("Daftar Siswa · N siswa").
  int get embeddedTotalStudents;

  // ─────────────────────────────────────────
  // EMBEDDED HEADER · Frame A
  // ─────────────────────────────────────────

  /// Brand-aligned header for the take-attendance flow. Same gradient
  /// + centered title pattern as the detail screen, with a context
  /// strip in the bottom slot showing `Subject · Class · Jam ke-N`
  /// + the date — so the teacher always sees the full session
  /// identity at a glance.
  ///
  /// The drag handle and explicit close button are gone — the screen
  /// is no longer a draggable sheet, and the back button is provided
  /// automatically by [BrandPageHeader] from the navigator.
  Widget buildEmbeddedHeader(LanguageProvider lp) {
    return BrandPageHeader(
      role: 'guru',
      title: lp.getTranslatedText({
        'en': 'Take Attendance',
        'id': 'Ambil Presensi',
      }),
      subtitle: lp.getTranslatedText({
        'en': 'Attendance · Input',
        'id': 'Presensi · Input',
      }),
      isRealtimeFresh: true,
      // Reserve enough gradient at the bottom for the KPI strip
      // to overlap into — same convention as the main Presensi
      // page and the detail screen.
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      // Density toggle removed — the screen now ships a single
      // compact view (one row per student with inline status
      // pills). Keeping just one layout simplifies the mental
      // model and frees the action slot for a future affordance.
      bottomSlot: _buildEmbeddedContextStrip(lp),
    );
  }

  /// Translucent card showing `Subject · Class` + date / lesson hour
  /// — same shape as the detail screen's context strip so the two
  /// surfaces feel like one flow. Falls back gracefully when any
  /// field is missing (e.g. during the brief moment before initial
  /// data hydrates).
  Widget _buildEmbeddedContextStrip(LanguageProvider lp) {
    final subjectName = (widget.initialSubjectName ?? '').trim();
    final className = (widget.initialClassName ?? '').trim();
    final lessonHourNumber = widget.initialLessonHourNumber;
    final date = widget.initialDate ?? DateTime.now();

    final initial = subjectName.isNotEmpty
        ? subjectName[0].toUpperCase()
        : '?';
    final titleParts = <String>[
      if (subjectName.isNotEmpty) subjectName,
      if (className.isNotEmpty) className,
    ];
    final title = titleParts.isEmpty ? '-' : titleParts.join(' · ');

    final dateStr = DateFormat('EEE, d MMM yyyy', 'id_ID').format(date);
    final subtitleParts = <String>[
      dateStr,
      if (lessonHourNumber != null) 'Jam ke-$lessonHourNumber',
    ];
    final subtitle = subtitleParts.join(' · ');

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
                color: ColorUtils.getRoleColor('guru'),
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
                  subtitle,
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

  // ─────────────────────────────────────────
  // KPI STRIP · Frame A overlap card
  // ─────────────────────────────────────────

  /// Five-cell KPI card rendered between the gradient header and the
  /// body. Each cell shows a status count with its brand colour. Live
  /// — re-counts on every status change.
  Widget buildEmbeddedKpiStrip(LanguageProvider lp) {
    final c = embeddedStatusCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        // Frame A · 4-cell strip per the mockup. Telat is folded into
        // Hadir for the count (late arrivals are still "present") so
        // teachers see a single Hadir number that matches the student
        // list head count.
        child: Row(
          children: [
            _kpiCell(
              label: 'Hadir',
              value: (c['hadir'] ?? 0) + (c['terlambat'] ?? 0),
              color: ColorUtils.success600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: 'Sakit',
              value: c['sakit'] ?? 0,
              color: ColorUtils.warning600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: 'Izin',
              value: c['izin'] ?? 0,
              color: ColorUtils.info600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: 'Alpa',
              value: c['alpha'] ?? 0,
              color: ColorUtils.error600,
            ),
          ],
        ),
      ),
    );
  }

  /// "Daftar Siswa · N siswa" section head between the toolbar and the
  /// student list — matches the mockup's `.section-head` block.
  Widget buildEmbeddedSectionHead(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: ColorUtils.getRoleColor('guru'),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            lp.getTranslatedText({'en': 'Student List', 'id': 'Daftar Siswa'}),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ColorUtils.slate900,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Text(
            '$embeddedTotalStudents ${lp.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SMALL WIDGET HELPERS
  // ─────────────────────────────────────────

  Widget _kpiCell({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 24, color: ColorUtils.slate100);
  }
}
