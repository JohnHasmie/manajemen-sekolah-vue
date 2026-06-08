// Unit tests for ActivityScheduleOptions — the schedule-derived Mapel +
// Jam (jam-pelajaran) scoping that powers the "Tambah Kegiatan" form's
// pickers (Bug 1: scope mapel to the teacher's teaching set; replace the
// free clock with a per-day "Jam ke-N" picker).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/data/activity_schedule_options.dart';

void main() {
  // A teacher who teaches TIK in 7A (Tue + Wed) and Matematika in 7B
  // (Wed). Mirrors the teacher-summary `schedules` shape (English day
  // names, nested-free flat keys).
  final schedules = <Map<String, dynamic>>[
    {
      'id': 's1',
      'subject_id': 'tik',
      'subject_name': 'TIK',
      'class_id': '7a',
      'class_name': '7A',
      'day_name': 'Tuesday',
      'lesson_hour': 3,
      'lesson_hour_id': 'lh-tue-3',
      'start_time': '09:00',
      'end_time': '09:45',
    },
    {
      'id': 's2',
      'subject_id': 'tik',
      'subject_name': 'TIK',
      'class_id': '7a',
      'class_name': '7A',
      'day_name': 'Tuesday',
      'lesson_hour': 4,
      'lesson_hour_id': 'lh-tue-4',
      'start_time': '10:00',
      'end_time': '10:45',
    },
    {
      'id': 's3',
      'subject_id': 'tik',
      'subject_name': 'TIK',
      'class_id': '7a',
      'class_name': '7A',
      'day_name': 'Wednesday',
      'lesson_hour': 1,
      'lesson_hour_id': 'lh-wed-1',
      'start_time': '07:00',
      'end_time': '07:45',
    },
    {
      'id': 's4',
      'subject_id': 'mtk',
      'subject_name': 'Matematika',
      'class_id': '7b',
      'class_name': '7B',
      'day_name': 'Wednesday',
      'lesson_hour': 5,
      'lesson_hour_id': 'lh-wed-5',
      'start_time': '11:00',
      'end_time': '11:45',
    },
  ];

  // Reference weekdays (DateTime.weekday: Mon=1 … Sun=7).
  final tuesday = DateTime(2026, 6, 9); // weekday 2
  final wednesday = DateTime(2026, 6, 10); // weekday 3
  final thursday = DateTime(2026, 6, 11); // weekday 4

  group('subjectsFor', () {
    test('returns all taught subjects when no class filter', () {
      final subjects = ActivityScheduleOptions.subjectsFor(schedules);
      final ids = subjects.map((s) => s['id']).toList();
      expect(ids, containsAll(['tik', 'mtk']));
      expect(ids.length, 2, reason: 'de-duped by subject id');
    });

    test('scopes subjects to the selected class (Bug 1a)', () {
      final in7a =
          ActivityScheduleOptions.subjectsFor(schedules, classId: '7a');
      expect(in7a.map((s) => s['id']), ['tik']);

      final in7b =
          ActivityScheduleOptions.subjectsFor(schedules, classId: '7b');
      expect(in7b.map((s) => s['id']), ['mtk']);
    });

    test('returns empty for a class the teacher does not teach', () {
      final none =
          ActivityScheduleOptions.subjectsFor(schedules, classId: 'zzz');
      expect(none, isEmpty);
    });

    test('does not leak subjects the teacher never teaches', () {
      // No "PKN" / "Penjaskes" etc. — only what is in `schedules`.
      final all = ActivityScheduleOptions.subjectsFor(schedules);
      expect(all.any((s) => s['name'] == 'PKN'), isFalse);
    });
  });

  group('lessonHoursFor (Bug 1b)', () {
    test('returns the selected class+day jam slots, sorted by hour', () {
      final hours = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: '7a',
        date: tuesday,
      );
      expect(hours.map((h) => h.hourNumber), [3, 4]);
      expect(hours.first.lessonHourId, 'lh-tue-3');
      expect(hours.first.timeValue, '09:00');
    });

    test('different day yields that day\'s slots only', () {
      final wed = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: '7a',
        date: wednesday,
      );
      expect(wed.map((h) => h.hourNumber), [1]);
      expect(wed.first.lessonHourId, 'lh-wed-1');
    });

    test('empty when the class has no slot on that weekday', () {
      final thu = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: '7a',
        date: thursday,
      );
      expect(thu, isEmpty);
    });

    test('empty when no class is selected', () {
      final none = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: null,
        date: tuesday,
      );
      expect(none, isEmpty);
    });

    test('narrows further by subject when provided', () {
      // 7B on Wednesday teaches only Matematika.
      final mtk = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: '7b',
        date: wednesday,
        subjectId: 'mtk',
      );
      expect(mtk.map((h) => h.hourNumber), [5]);

      final tikIn7b = ActivityScheduleOptions.lessonHoursFor(
        schedules,
        classId: '7b',
        date: wednesday,
        subjectId: 'tik',
      );
      expect(tikIn7b, isEmpty);
    });

    test('matches Indonesian day names too', () {
      final idSchedule = [
        {
          'id': 'x',
          'subject_id': 'tik',
          'subject_name': 'TIK',
          'class_id': '7a',
          'class_name': '7A',
          'day_name': 'Selasa',
          'lesson_hour': 2,
          'lesson_hour_id': 'lh-sel-2',
          'start_time': '08:00',
          'end_time': '08:45',
        },
      ];
      final hours = ActivityScheduleOptions.lessonHoursFor(
        idSchedule,
        classId: '7a',
        date: tuesday,
      );
      expect(hours.map((h) => h.hourNumber), [2]);
    });
  });

  group('ActivityLessonHourOption.label', () {
    test('renders Jam ke-N · HH:MM–HH:MM', () {
      const opt = ActivityLessonHourOption(
        hourNumber: 1,
        startTime: '09:00',
        endTime: '09:45',
      );
      expect(opt.label, 'Jam ke-1 · 09:00–09:45');
      expect(opt.timeValue, '09:00');
    });

    test('normalizes dotted times and pads single-digit hours', () {
      const opt = ActivityLessonHourOption(
        hourNumber: 2,
        startTime: '9.5.00',
        endTime: '9.50.00',
      );
      expect(opt.label, 'Jam ke-2 · 09:05–09:50');
    });

    test('degrades gracefully without an hour number', () {
      const opt = ActivityLessonHourOption(
        startTime: '07:00',
        endTime: '07:45',
      );
      expect(opt.label, '07:00–07:45');
    });
  });

  group('classesFrom', () {
    test('returns de-duped classes from the schedule', () {
      final classes = ActivityScheduleOptions.classesFrom(schedules);
      expect(classes.map((c) => c['id']), containsAll(['7a', '7b']));
      expect(classes.length, 2);
    });
  });
}
