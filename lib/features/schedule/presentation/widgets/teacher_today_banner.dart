// Cobalt-gradient "today" banner shown at the top of the teacher Jadwal
// hub when the schedule list contains lessons scheduled for today. It
// summarises the day's progress in three lines:
//
//   • kicker — `HARI INI · <Jumat, 9 Mei>`
//   • title  — `<n> sesi · <m> sedang berlangsung` (or `· hari sudah
//              selesai` when none are live and all are past)
//   • caption — `Selesai <done>/<total> — <next subject> di <time>`
//
// A 5dp-tall progress strip below the caption fills proportional to
// `done / total`, rounded down. Surfaces inside the cobalt-gradient
// header so it visually anchors to the brand chrome — same idiom as the
// activity-progress card on the Kegiatan Kelas detail screen.
//
// The banner deliberately renders nothing when there are no schedules
// for today (the dailySummary is the source of truth) or when the
// teacher is viewing past-week / future-week data — surfacing a "live"
// banner there would mis-imply real-time relevance.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Drop into the body of `BrandPageLayout` above the day-grouped card
/// list. Self-contained — no callbacks, no state.
class TeacherTodayBanner extends StatelessWidget {
  /// All schedule entries currently rendered (already-filtered by the
  /// hub). The widget extracts the subset matching today's day name.
  final List<dynamic> allSchedules;

  /// Same `dailySummary` map the hub uses for card tap-throughs:
  /// `{ "<class_id>__<subject_id>": {attendance, class_activity, ...} }`.
  /// Used to compute "completed" sessions (attendance.filled = true).
  final Map<String, dynamic>? dailySummary;

  const TeacherTodayBanner({
    super.key,
    required this.allSchedules,
    this.dailySummary,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayName = _indoDayName(today.weekday);
    final todaySchedules = allSchedules.where((s) {
      if (s is! Map) return false;
      final m = Schedule.fromJson(Map<String, dynamic>.from(s));
      final raw = (m.dayName ?? '').trim();
      return _matchesIndoDay(raw, todayName);
    }).toList()..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));

    if (todaySchedules.isEmpty) return const SizedBox.shrink();

    final total = todaySchedules.length;

    // Count "done" via attendance.filled — same contract that the
    // schedule-card "filled-attendance" tint uses.
    final done = todaySchedules.where((s) {
      if (s is! Map) return false;
      final classId = s['class_id'] ?? s['kelas_id'];
      final subjectId = s['subject_id'] ?? s['mata_pelajaran_id'];
      if (classId == null || subjectId == null) return false;
      final key = '${classId}__$subjectId';
      final entry = dailySummary?[key];
      if (entry is! Map) return false;
      final att = entry['attendance'];
      return att is Map && att['filled'] == true;
    }).length;

    // "Sedang" — the lesson whose start..end window contains the
    // current minute-of-day. There's at most one in a normal timetable.
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    int liveCount = 0;
    Map<String, dynamic>? liveSchedule;
    for (final s in todaySchedules) {
      if (s is! Map) continue;
      final start = _startMinutes(s);
      final end = _endMinutes(s);
      if (start <= nowMin && nowMin < end) {
        liveCount++;
        liveSchedule ??= Map<String, dynamic>.from(s);
        break;
      }
    }

    // "Next" — the first lesson whose start time is >= now.
    Map<String, dynamic>? nextSchedule;
    for (final s in todaySchedules) {
      if (s is! Map) continue;
      if (_startMinutes(s) > nowMin) {
        nextSchedule = Map<String, dynamic>.from(s);
        break;
      }
    }

    final cobalt = ColorUtils.brandCobalt;
    final dark = ColorUtils.brandDarkBlue;
    final percent = total > 0 ? done / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dark, cobalt],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cobalt.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                'HARI INI · ${_indoDateLabel(today)}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            liveCount > 0
                ? '$total sesi · 1 sedang berlangsung'
                : (done >= total
                      ? 'Hari sudah selesai · $total sesi'
                      : '$total sesi · $done selesai'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          if (liveSchedule != null || nextSchedule != null) ...[
            const SizedBox(height: 4),
            Text(
              _buildCaption(done, total, liveSchedule, nextSchedule),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.18)),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────

  static String _buildCaption(
    int done,
    int total,
    Map<String, dynamic>? live,
    Map<String, dynamic>? next,
  ) {
    if (live != null) {
      final m = Schedule.fromJson(live);
      final subject = (m.subjectName ?? '').isNotEmpty
          ? m.subjectName!
          : 'Sesi ini';
      final cls = (m.className ?? '').isNotEmpty ? m.className! : '-';
      final start = _formatTimeStr(m.startTime);
      return 'Selesai $done dari $total · $subject $cls dimulai $start';
    }
    if (next != null) {
      final m = Schedule.fromJson(next);
      final subject = (m.subjectName ?? '').isNotEmpty
          ? m.subjectName!
          : 'Selanjutnya';
      final cls = (m.className ?? '').isNotEmpty ? m.className! : '-';
      final start = _formatTimeStr(m.startTime);
      return 'Selesai $done dari $total · $subject $cls jam $start';
    }
    return 'Selesai $done dari $total sesi';
  }

  static String _indoDayName(int weekday) {
    // DateTime.weekday: Monday=1 ... Sunday=7
    switch (weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      default:
        return 'Minggu';
    }
  }

  static bool _matchesIndoDay(String raw, String indoToday) {
    final lower = raw.toLowerCase();
    if (lower.contains(indoToday.toLowerCase())) return true;
    // English fallback — backend stores English names by convention.
    const map = <String, String>{
      'senin': 'monday',
      'selasa': 'tuesday',
      'rabu': 'wednesday',
      'kamis': 'thursday',
      'jumat': 'friday',
      'sabtu': 'saturday',
      'minggu': 'sunday',
    };
    final eng = map[indoToday.toLowerCase()];
    return eng != null && lower.contains(eng);
  }

  static String _indoDateLabel(DateTime d) {
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
    return '${_indoDayName(d.weekday)}, ${d.day} ${months[d.month - 1]}';
  }

  static int _startMinutes(dynamic s) {
    if (s is! Map) return 0;
    final m = Schedule.fromJson(Map<String, dynamic>.from(s));
    return _parseTime(m.startTime);
  }

  static int _endMinutes(dynamic s) {
    if (s is! Map) return 0;
    final m = Schedule.fromJson(Map<String, dynamic>.from(s));
    return _parseTime(m.endTime);
  }

  static int _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    final colon = raw.indexOf(':');
    if (colon < 0) return 0;
    final h = int.tryParse(raw.substring(0, colon)) ?? 0;
    final mm = colon + 1 < raw.length
        ? int.tryParse(
                raw.substring(
                  colon + 1,
                  colon + 3 > raw.length ? raw.length : colon + 3,
                ),
              ) ??
              0
        : 0;
    return h * 60 + mm;
  }

  static String _formatTimeStr(String? raw) {
    if (raw == null || raw.isEmpty) return '--:--';
    final colon = raw.indexOf(':');
    if (colon < 0) return raw;
    final h = raw.substring(0, colon).padLeft(2, '0');
    final m = colon + 1 + 2 <= raw.length
        ? raw.substring(colon + 1, colon + 3)
        : raw.substring(colon + 1);
    return '$h.$m';
  }
}
