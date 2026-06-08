// Derives the "Tambah Kegiatan" form's scoped Mapel + Jam-pelajaran
// pickers from the teacher's own teaching schedule (`schedules`) — the
// same per-class / per-day / per-lesson-hour source the Jadwal screen
// renders. This mirrors the web `fix/jadwal-mapel-teacher-scope` work
// (ScheduleFormModal + subjects.service): the add/edit form must only
// offer subjects the logged-in teacher actually teaches, and the time
// field must be a lesson-hour ("Jam ke-N · HH:MM–HH:MM") picker scoped
// to the chosen class + day, never a free clock.
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// One lesson-hour slot the teacher can pick in the activity form.
///
/// Built from a [Schedule] row, so it already carries the exact
/// `lesson_hour_id` UUID + the slot's `HH:MM` start/end window. The
/// label renders as `Jam ke-N` (falling back to the time window when
/// the backend omits the hour number).
class ActivityLessonHourOption {
  /// `hour_number` / `jam_ke` for the slot (e.g. 1 for "Jam ke-1").
  final int? hourNumber;

  /// Exact `lesson_hour_id` UUID. Each (day, hour) tuple owns a
  /// distinct UUID, so newly created activities tag the right slot.
  final String? lessonHourId;

  /// `HH:MM` start time (already normalized by [Schedule.fromJson]).
  final String? startTime;

  /// `HH:MM` end time.
  final String? endTime;

  const ActivityLessonHourOption({
    this.hourNumber,
    this.lessonHourId,
    this.startTime,
    this.endTime,
  });

  /// `09:00` — the value the form stores in the payload's `time`
  /// field. Falls back to an empty string when no start time is known.
  String get timeValue => _hhmm(startTime);

  /// Human label for the picker row, e.g. `Jam ke-1 · 09:00–09:45`.
  /// Degrades gracefully when the hour number or window is missing.
  String get label {
    final parts = <String>[];
    if (hourNumber != null) {
      parts.add('Jam ke-$hourNumber');
    }
    final window = _window;
    if (window.isNotEmpty) parts.add(window);
    if (parts.isEmpty) return 'Jam pelajaran';
    return parts.join(' · ');
  }

  String get _window {
    final s = _hhmm(startTime);
    final e = _hhmm(endTime);
    if (s.isEmpty && e.isEmpty) return '';
    if (e.isEmpty) return s;
    if (s.isEmpty) return e;
    return '$s–$e';
  }

  static String _hhmm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final cleaned = raw.replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }
}

/// Pure helpers that turn a raw `schedules` list (as returned by the
/// teacher-summary endpoint) into the form's scoped option lists.
///
/// All methods are static + side-effect free so they're trivially
/// unit-testable and safe to call from any of the three form callers
/// (FAB add, list-row edit, Jadwal "Kegiatan" entry).
class ActivityScheduleOptions {
  const ActivityScheduleOptions._();

  /// ISO weekday (1=Mon … 7=Sun) → the lowercase day names a schedule
  /// row may use. Backend stores English; the model keeps it English
  /// but some legacy rows are Indonesian, so we match both.
  static const Map<int, List<String>> _weekdayNames = {
    1: ['monday', 'senin'],
    2: ['tuesday', 'selasa'],
    3: ['wednesday', 'rabu'],
    4: ['thursday', 'kamis'],
    5: ['friday', 'jumat'],
    6: ['saturday', 'sabtu'],
    7: ['sunday', 'minggu'],
  };

  /// Parses each raw entry into a [Schedule]. Skips malformed rows.
  static List<Schedule> _parse(List<dynamic> schedules) {
    final out = <Schedule>[];
    for (final s in schedules) {
      if (s is! Map) continue;
      try {
        out.add(Schedule.fromJson(Map<String, dynamic>.from(s)));
      } catch (_) {
        // Skip rows the model can't normalize.
      }
    }
    return out;
  }

  /// Subjects the teacher teaches, optionally narrowed to one class.
  ///
  /// Returns `[{id, name}]` de-duped by subject id — the exact shape
  /// the form's Mapel picker consumes. When [classId] is non-empty we
  /// only keep subjects the teacher teaches IN that class (the strict
  /// scope the bug asks for); otherwise we return every subject across
  /// the teacher's whole schedule.
  static List<Map<String, dynamic>> subjectsFor(
    List<dynamic> schedules, {
    String? classId,
  }) {
    final parsed = _parse(schedules);
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final s in parsed) {
      final sid = (s.subjectId ?? '').trim();
      if (sid.isEmpty) continue;
      if (classId != null &&
          classId.isNotEmpty &&
          (s.classId ?? '') != classId) {
        continue;
      }
      if (!seen.add(sid)) continue;
      out.add({'id': sid, 'name': s.subjectName ?? '-'});
    }
    return out;
  }

  /// Classes the teacher teaches, de-duped by class id — used as a
  /// fallback when the caller has no explicit class list.
  static List<Map<String, dynamic>> classesFrom(List<dynamic> schedules) {
    final parsed = _parse(schedules);
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final s in parsed) {
      final cid = (s.classId ?? '').trim();
      if (cid.isEmpty || !seen.add(cid)) continue;
      out.add({'id': cid, 'name': s.className ?? '-'});
    }
    return out;
  }

  /// Lesson-hour slots for the chosen class on the chosen [date]'s
  /// weekday — the "Jam ke-N" options the WAKTU picker shows.
  ///
  /// Scoped to:
  ///   • [classId]  — the slot must belong to the selected class
  ///   • [date]     — the slot's day must match the date's weekday
  ///   • [subjectId] (optional) — narrow further to the picked subject
  ///
  /// De-duped by `lesson_hour_id` (falling back to hour number) and
  /// sorted ascending by hour number then start time, so "Jam ke-1"
  /// comes before "Jam ke-2".
  static List<ActivityLessonHourOption> lessonHoursFor(
    List<dynamic> schedules, {
    required String? classId,
    required DateTime date,
    String? subjectId,
  }) {
    if (classId == null || classId.isEmpty) return const [];
    final dayNames = _weekdayNames[date.weekday] ?? const [];
    final parsed = _parse(schedules);
    final seen = <String>{};
    final out = <ActivityLessonHourOption>[];
    for (final s in parsed) {
      if ((s.classId ?? '') != classId) continue;
      if (subjectId != null &&
          subjectId.isNotEmpty &&
          (s.subjectId ?? '') != subjectId) {
        continue;
      }
      final dn = (s.dayName ?? '').toLowerCase();
      final dayMatches = dayNames.any(dn.contains);
      if (!dayMatches) continue;

      // De-dupe key — prefer the UUID, else fall back to the hour
      // number so two rows for the same slot don't double up.
      final key = (s.lessonHourId ?? '').isNotEmpty
          ? s.lessonHourId!
          : 'h${s.lessonHour ?? ''}';
      if (!seen.add(key)) continue;

      out.add(
        ActivityLessonHourOption(
          hourNumber: s.lessonHour,
          lessonHourId: s.lessonHourId,
          startTime: s.startTime,
          endTime: s.endTime,
        ),
      );
    }

    out.sort((a, b) {
      final ah = a.hourNumber ?? 9999;
      final bh = b.hourNumber ?? 9999;
      if (ah != bh) return ah.compareTo(bh);
      return a.timeValue.compareTo(b.timeValue);
    });
    return out;
  }
}
