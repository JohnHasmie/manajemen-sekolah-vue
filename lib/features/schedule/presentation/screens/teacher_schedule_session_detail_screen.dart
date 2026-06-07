// Frame E — full-page session detail.
//
// Replaces the legacy `ScheduleCardSummarySheet` (which was a
// `showModalBottomSheet` of a tap-target list). Tapping a card on the
// teacher Jadwal hub now pushes this screen, which gives the
// `BrandPageHeader` its full SafeArea and lets ESC / system-back
// behave predictably (a deep-link from FCM previously took the user
// past the sheet).
//
// Layout (matches `_design/teacher_jadwal_redesign.html` Frame E):
//
//   • BrandPageHeader — `Detail Sesi · <Jumat 9 Mei>` kicker, title
//     `JP <n> · <subject> · <class>`.
//   • Hero card (overlapping the gradient by 20dp):
//       – 56dp cobalt JP icon
//       – subject + class · time · room
//       – status banner (`Sedang berlangsung`, `Akan dimulai dalam …`,
//         or `Selesai`).
//   • 2×2 action tile grid — Presensi (green) · Kegiatan (amber) ·
//     Materi (cobalt) · Buku Nilai (violet — AI/grade adjacent
//     affordance).
//   • Detail Sesi list — Waktu / Ruangan / Wali Kelas / Periode rows.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_helpers.dart';

class TeacherScheduleSessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic>? summary;
  final LanguageProvider languageProvider;
  final VoidCallback onAttendanceTap;
  final VoidCallback onMaterialTap;
  final VoidCallback onActivityTap;
  final VoidCallback? onGradeBookTap;

  const TeacherScheduleSessionDetailScreen({
    super.key,
    required this.schedule,
    required this.summary,
    required this.languageProvider,
    required this.onAttendanceTap,
    required this.onMaterialTap,
    required this.onActivityTap,
    this.onGradeBookTap,
  });

  /// Push this screen onto the navigator. Returns when popped.
  static Future<void> push(
    BuildContext context, {
    required Map<String, dynamic> schedule,
    required Map<String, dynamic>? summary,
    required LanguageProvider languageProvider,
    required VoidCallback onAttendanceTap,
    required VoidCallback onMaterialTap,
    required VoidCallback onActivityTap,
    VoidCallback? onGradeBookTap,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TeacherScheduleSessionDetailScreen(
          schedule: schedule,
          summary: summary,
          languageProvider: languageProvider,
          onAttendanceTap: onAttendanceTap,
          onMaterialTap: onMaterialTap,
          onActivityTap: onActivityTap,
          onGradeBookTap: onGradeBookTap,
        ),
      ),
    );
  }

  Schedule get _model => Schedule.fromJson(schedule);

  @override
  Widget build(BuildContext context) {
    final m = _model;
    final lp = languageProvider;
    final cobalt = ColorUtils.brandCobalt;

    final att = summary?['attendance'];
    final act = summary?['class_activity'];
    final mat = summary?['material_progress'];

    final attCount = att is Map && att['filled'] == true
        ? '${att['hadir'] ?? 0}/${att['total'] ?? 0} Hadir'
        : 'Belum diisi';
    final actCount = act is Map && (act['count'] ?? 0) > 0
        ? '${act['count']} kegiatan'
        : 'Belum ada kegiatan';
    final matCount = mat is Map
        ? '${mat['checked'] ?? 0}/${mat['total'] ?? 0} bab ditandai'
        : 'Belum ada data materi';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'guru',
            subtitle: _kickerLabel(),
            title: _titleLabel(),
            onBackPressed: () => AppNavigator.pop(context),
            kpiOverlayHeight: 28,
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  children: [
                    const SizedBox(height: 20),
                    _buildHeroCard(cobalt),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildActionGrid(lp, attCount, actCount, matCount),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        kSchSessionDetails.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _detailRow(
                            Icons.access_time_rounded,
                            kSchTime.tr,
                            '${formatTimeStr(m.startTime)} – '
                                '${formatTimeStr(m.endTime)}',
                          ),
                          if ((m.dayName ?? '').isNotEmpty)
                            _detailRow(
                              Icons.calendar_today_rounded,
                              kDay.tr,
                              _formatDay(m.dayName!),
                            ),
                          if (_periodeLabel().isNotEmpty)
                            _detailRow(
                              Icons.school_rounded,
                              kSchPeriod.tr,
                              _periodeLabel(),
                            ),
                          if ((m.teacherName ?? '').isNotEmpty)
                            _detailRow(
                              Icons.person_rounded,
                              kTeacher.tr,
                              m.teacherName!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _kickerLabel() {
    final m = _model;
    final day = (m.dayName ?? '').isNotEmpty ? _formatDay(m.dayName!) : 'Sesi';
    return 'Detail Sesi · $day';
  }

  String _titleLabel() {
    final m = _model;
    final hour = m.lessonHour?.toString() ?? '-';
    final subject = (m.subjectName ?? '').isNotEmpty
        ? m.subjectName!
        : 'Mata Pelajaran';
    final cls = (m.className ?? '').isNotEmpty ? m.className! : '-';
    return 'JP $hour · $subject · $cls';
  }

  /// Builds the "Periode" row's value safely. The schedule model coerces
  /// `academic_year` from the raw API into a `String?`, but the API
  /// sometimes returns it as an object (`{id, year}`), in which case
  /// the model ends up holding the map's `toString()` representation
  /// (`{id: 3, year: 2025/2026}`). We re-read the raw map here and
  /// extract `year` defensively so the row always renders a clean
  /// `Genap · 2025/2026`.
  String _periodeLabel() {
    final parts = <String>[];
    final semesterName = _model.semesterName;
    if (semesterName != null && semesterName.isNotEmpty) {
      parts.add(semesterName);
    }

    final rawAy = schedule['academic_year'];
    String? yearText;
    if (rawAy is String && rawAy.isNotEmpty && !rawAy.startsWith('{')) {
      yearText = rawAy;
    } else if (rawAy is Map) {
      final year = rawAy['year'] ?? rawAy['name'] ?? rawAy['nama'];
      if (year != null && year.toString().isNotEmpty) {
        yearText = year.toString();
      }
    }
    if (yearText != null && yearText.isNotEmpty) parts.add(yearText);

    return parts.join(' · ');
  }

  // ── Hero card ─────────────────────────────────────────────────

  Widget _buildHeroCard(Color cobalt) {
    final m = _model;
    final hour = m.lessonHour?.toString() ?? '-';
    final subject = (m.subjectName ?? '').isNotEmpty
        ? m.subjectName!
        : 'Mata Pelajaran';
    final cls = (m.className ?? '').isNotEmpty ? m.className! : '-';

    final startMin = _parseTime(m.startTime);
    final endMin = _parseTime(m.endTime);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final isLive = startMin <= nowMin && nowMin < endMin;
    final isUpcoming = nowMin < startMin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ColorUtils.brandDarkBlue, cobalt],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cobalt.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hour,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'JP',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.5,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate500,
                          ),
                          children: [
                            TextSpan(
                              text: cls,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: cobalt,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text:
                                  '${formatTimeStr(m.startTime)} – '
                                  '${formatTimeStr(m.endTime)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isLive || isUpcoming) ...[
              const SizedBox(height: 12),
              _statusBanner(
                isLive: isLive,
                remainingMin: isLive ? endMin - nowMin : startMin - nowMin,
                cobalt: cobalt,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBanner({
    required bool isLive,
    required int remainingMin,
    required Color cobalt,
  }) {
    final text = isLive
        ? 'Sedang berlangsung — sisa $remainingMin menit'
        : 'Akan dimulai dalam $remainingMin menit';
    final (bg, fg, border) = isLive
        ? (
            ColorUtils.error600.withValues(alpha: 0.06),
            ColorUtils.error600,
            ColorUtils.error600.withValues(alpha: 0.18),
          )
        : (
            cobalt.withValues(alpha: 0.06),
            cobalt,
            cobalt.withValues(alpha: 0.18),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 13, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action grid ───────────────────────────────────────────────

  Widget _buildActionGrid(
    LanguageProvider lp,
    String attCount,
    String actCount,
    String matCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionTile(
                icon: Icons.fact_check_rounded,
                title: kSchTakeAttendance.tr,
                sub: attCount,
                color: ColorUtils.success600,
                onTap: onAttendanceTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionTile(
                icon: Icons.assignment_rounded,
                title: kClassActivities.tr,
                sub: actCount,
                color: ColorUtils.warning600,
                onTap: onActivityTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _actionTile(
                icon: Icons.library_books_rounded,
                title: kSchMaterialsAndLessonPlan.tr,
                sub: matCount,
                color: ColorUtils.brandCobalt,
                onTap: onMaterialTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionTile(
                icon: Icons.grade_rounded,
                title: kSchGradeBook.tr,
                sub: kSchViewInputGrades.tr,
                color: const Color(0xFF7C3AED),
                onTap: onGradeBookTap ?? () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate500,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Detail list rows ──────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ColorUtils.brandCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 14, color: ColorUtils.brandCobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandCobalt,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  static String _formatDay(String raw) {
    final lower = raw.toLowerCase();
    const map = <String, String>{
      'monday': 'Senin',
      'tuesday': 'Selasa',
      'wednesday': 'Rabu',
      'thursday': 'Kamis',
      'friday': 'Jumat',
      'saturday': 'Sabtu',
      'sunday': 'Minggu',
    };
    for (final entry in map.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return raw;
  }

  static int _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    final colon = raw.indexOf(':');
    if (colon < 0) return 0;
    final h = int.tryParse(raw.substring(0, colon)) ?? 0;
    final endIdx = colon + 3 > raw.length ? raw.length : colon + 3;
    final m = int.tryParse(raw.substring(colon + 1, endIdx)) ?? 0;
    return h * 60 + m;
  }
}
