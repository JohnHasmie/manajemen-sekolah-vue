import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

/// Represents a single schedule (jadwal) entry — a timetable slot that binds
/// a subject, class, teacher, day, and lesson hour.
///
/// The API returns schedule data with mixed English + Indonesian keys and,
/// in some responses, nested Maps for `day` / `hari` and `semester`:
///   - Subject: `subject_id` / `mata_pelajaran_id`, `subject_name` / `mata_pelajaran_nama`
///   - Class:   `class_id` / `kelas_id`, `class_name` / `kelas_nama`
///   - Teacher: `teacher_id` / `guru_id`, `teacher_name` / `guru_nama`
///   - Day:     `day_id` / `hari_id`, `day_name` / `hari_nama`, or
///              nested `day: {name, nama}` / `hari: {name, nama}`
///   - Hour:    `lesson_hour` / `jam_ke` / `hour_number`,
///              `lesson_hour_id` / `jam_pelajaran_id`
///   - Time:    `start_time` / `jam_mulai`, `end_time` / `jam_selesai`
///   - Term:    `semester_name` / `semester` (Map or String), `academic_year`
///
/// [Schedule.fromJson] normalizes all variations via [_standardizeJson].
@freezed
abstract class Schedule with _$Schedule {
  const Schedule._();

  const factory Schedule({
    required String id,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'class_name') String? className,
    @JsonKey(name: 'teacher_id') String? teacherId,
    @JsonKey(name: 'teacher_name') String? teacherName,
    @JsonKey(name: 'day_id') String? dayId,
    @JsonKey(name: 'day_name') String? dayName,
    @JsonKey(name: 'lesson_hour') int? lessonHour,
    @JsonKey(name: 'lesson_hour_id') String? lessonHourId,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    @JsonKey(name: 'academic_year') String? academicYear,
    @JsonKey(name: 'semester_name') String? semesterName,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(_standardizeJson(json));

  /// True when the schedule has both a subject and class assigned.
  bool get isComplete =>
      (subjectId ?? '').isNotEmpty && (classId ?? '').isNotEmpty;

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(json);

    // Subject — flat first, then nested `subject` / `mata_pelajaran` Map
    m['subject_id'] ??= m['mata_pelajaran_id'];
    m['subject_name'] ??= m['mata_pelajaran_nama'];
    final dynamic subj = m['subject'] ?? m['mata_pelajaran'];
    if (subj is Map) {
      m['subject_id'] ??= subj['id'];
      m['subject_name'] ??= subj['name'] ?? subj['nama'];
    }

    // Class — flat first, then nested `class` / `kelas` Map
    m['class_id'] ??= m['kelas_id'];
    m['class_name'] ??= m['kelas_nama'];
    final dynamic cls = m['class'] ?? m['kelas'];
    if (cls is Map) {
      m['class_id'] ??= cls['id'];
      m['class_name'] ??= cls['name'] ?? cls['nama'];
    }

    // Teacher — flat first, then nested `teacher` / `guru` Map
    m['teacher_id'] ??= m['guru_id'];
    m['teacher_name'] ??= m['guru_nama'];
    final dynamic tch = m['teacher'] ?? m['guru'];
    if (tch is Map) {
      m['teacher_id'] ??= tch['id'];
      m['teacher_name'] ??= tch['name'] ?? tch['nama'];
    }

    // Day — flat English/Indonesian first, then nested day/hari Map fallback.
    // Backend stores English names (Monday, Tuesday...). We keep English
    // here; translation to Indonesian happens at the UI layer.
    m['day_id'] ??= m['hari_id'];
    m['day_name'] ??= m['hari_nama'];
    final dynamic day = m['day'] ?? m['hari'];
    if (day is Map) {
      m['day_id'] ??= day['id'];
      m['day_name'] ??= day['name'] ?? day['nama'];
    }

    // Lesson hour — extract from nested Map before coercing to int.
    // Also extract day info from lesson_hour.day since eager-loaded
    // TeachingSchedule responses nest the day inside lesson_hour.
    final dynamic rawLessonHour = m['lesson_hour'];
    if (rawLessonHour is Map) {
      m['start_time'] ??= rawLessonHour['start_time'] ??
          rawLessonHour['jam_mulai'];
      m['end_time'] ??= rawLessonHour['end_time'] ??
          rawLessonHour['jam_selesai'];
      m['lesson_hour_id'] ??= rawLessonHour['id'];
      // Extract day from lesson_hour.day before overwriting lesson_hour.
      // Backend sends {name: "Wednesday", order_number: 3}.
      final dynamic lhDay = rawLessonHour['day'] ?? rawLessonHour['hari'];
      if (lhDay is Map) {
        m['day_id'] ??= lhDay['id'];
        m['day_name'] ??= lhDay['name'] ?? lhDay['nama'];
      }
      m['lesson_hour'] = rawLessonHour['hour_number'] ??
          rawLessonHour['jam_ke'];
    }
    m['lesson_hour'] ??= m['jam_ke'] ?? m['hour_number'];
    m['lesson_hour_id'] ??= m['jam_pelajaran_id'];

    // Time window
    m['start_time'] ??= m['jam_mulai'];
    m['end_time'] ??= m['jam_selesai'];

    // Semester — flat English/Indonesian name or nested Map
    m['semester_name'] ??= m['semester_nama'];
    if (m['semester_name'] == null) {
      final dynamic sem = m['semester'];
      if (sem is String) {
        m['semester_name'] = sem;
      } else if (sem is Map) {
        m['semester_name'] = sem['name'] ?? sem['nama'];
      }
    }

    // Coerce required id
    m['id'] = (m['id'] ?? '').toString();

    // Coerce nullable string fields to String (or null)
    for (final key in const [
      'subject_id',
      'subject_name',
      'class_id',
      'class_name',
      'teacher_id',
      'teacher_name',
      'day_id',
      'day_name',
      'lesson_hour_id',
      'start_time',
      'end_time',
      'academic_year',
      'semester_name',
    ]) {
      if (m[key] != null) m[key] = m[key].toString();
    }

    // Coerce lesson_hour to int?
    final lh = m['lesson_hour'];
    if (lh is String) {
      m['lesson_hour'] = int.tryParse(lh);
    } else if (lh is num) {
      m['lesson_hour'] = lh.toInt();
    }

    return m;
  }
}
