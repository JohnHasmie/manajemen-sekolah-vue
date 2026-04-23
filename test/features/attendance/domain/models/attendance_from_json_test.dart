// CRUD data tests for Attendance.fromJson + _standardizeJson.
//
// The _standardizeJson method normalises 18+ Indonesian/English field variations
// and handles mixed types for the is_read flag (bool/int/string "0"/"1").
// Like testing a Laravel Accessor that normalises API response fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

Map<String, dynamic> _base({Map<String, dynamic>? overrides}) => {
  'id': '1',
  'student_id': 's1',
  'date': '2025-03-10',
  'status': 'hadir',
  ...?overrides,
};

void main() {
  // ---------------------------------------------------------------------------
  // is_read normalisation (bool / int / string)
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — is_read normalisation', () {
    test('bool true → isRead = true', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': true}));
      expect(a.isRead, isTrue);
    });

    test('bool false → isRead = false', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': false}));
      expect(a.isRead, isFalse);
    });

    test('int 1 → isRead = true', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': 1}));
      expect(a.isRead, isTrue);
    });

    test('int 0 → isRead = false', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': 0}));
      expect(a.isRead, isFalse);
    });

    test('string "1" → isRead = true', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': '1'}));
      expect(a.isRead, isTrue);
    });

    test('string "0" → isRead = false', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': '0'}));
      expect(a.isRead, isFalse);
    });

    test('absent is_read field → defaults to false', () {
      final a = Attendance.fromJson(_base());
      expect(a.isRead, isFalse);
    });

    test('null is_read → defaults to false', () {
      final a = Attendance.fromJson(_base(overrides: {'is_read': null}));
      expect(a.isRead, isFalse);
    });

    test('reads "isRead" camelCase alias', () {
      final a = Attendance.fromJson({
        'id': '1',
        'student_id': 's1',
        'date': '2025-03-10',
        'status': 'hadir',
        'isRead': 1,
      });
      expect(a.isRead, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // date normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — date field', () {
    test('reads "date" key directly', () {
      final a = Attendance.fromJson(_base(overrides: {'date': '2025-06-15'}));
      expect(a.date, DateTime.parse('2025-06-15'));
    });

    test('falls back to "tanggal" key', () {
      final a = Attendance.fromJson({
        'id': '1',
        'student_id': 's1',
        'tanggal': '2025-01-20',
        'status': 'hadir',
      });
      expect(a.date.year, 2025);
      expect(a.date.month, 1);
      expect(a.date.day, 20);
    });
  });

  // ---------------------------------------------------------------------------
  // student_id normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — student_id field', () {
    test('reads "student_id" directly', () {
      final a = Attendance.fromJson(_base(overrides: {'student_id': 'stu-42'}));
      expect(a.studentId, 'stu-42');
    });

    test('falls back to "id_siswa"', () {
      final a = Attendance.fromJson({
        'id': '1',
        'id_siswa': 'stu-99',
        'date': '2025-03-10',
        'status': 'hadir',
      });
      expect(a.studentId, 'stu-99');
    });

    test('numeric student_id is coerced to String', () {
      final a = Attendance.fromJson(_base(overrides: {'student_id': 77}));
      expect(a.studentId, '77');
    });
  });

  // ---------------------------------------------------------------------------
  // subjectName / subjectId normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — subject fields', () {
    test('reads "subject_name" directly', () {
      final a = Attendance.fromJson(
        _base(overrides: {'subject_name': 'Fisika'}),
      );
      expect(a.subjectName, 'Fisika');
    });

    test('falls back to "mata_pelajaran_nama"', () {
      final a = Attendance.fromJson(
        _base(overrides: {'mata_pelajaran_nama': 'Kimia'}),
      );
      expect(a.subjectName, 'Kimia');
    });

    test('reads "subject_id" directly', () {
      final a = Attendance.fromJson(_base(overrides: {'subject_id': 'sub-5'}));
      expect(a.subjectId, 'sub-5');
    });

    test('falls back to "id_mata_pelajaran"', () {
      final a = Attendance.fromJson(
        _base(overrides: {'id_mata_pelajaran': 'sub-9'}),
      );
      expect(a.subjectId, 'sub-9');
    });

    test('falls back to "mata_pelajaran_id"', () {
      final a = Attendance.fromJson(
        _base(overrides: {'mata_pelajaran_id': 'sub-11'}),
      );
      expect(a.subjectId, 'sub-11');
    });

    test('numeric subject_id coerced to String', () {
      final a = Attendance.fromJson(_base(overrides: {'subject_id': 3}));
      expect(a.subjectId, '3');
    });

    test('subjectName is null when absent', () {
      final a = Attendance.fromJson(_base());
      expect(a.subjectName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // lessonHourName / lessonHourId normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — lesson hour fields', () {
    test('reads "lesson_hour_name" directly', () {
      final a = Attendance.fromJson(
        _base(overrides: {'lesson_hour_name': 'Jam 3'}),
      );
      expect(a.lessonHourName, 'Jam 3');
    });

    test('falls back to "jam_pelajaran_nama"', () {
      final a = Attendance.fromJson(
        _base(overrides: {'jam_pelajaran_nama': 'Jam 1'}),
      );
      expect(a.lessonHourName, 'Jam 1');
    });

    test('lessonHourName is null when absent', () {
      final a = Attendance.fromJson(_base());
      expect(a.lessonHourName, isNull);
    });

    test('reads "lesson_hour_id" directly', () {
      final a = Attendance.fromJson(
        _base(overrides: {'lesson_hour_id': 'lh-7'}),
      );
      expect(a.lessonHourId, 'lh-7');
    });

    test('falls back to "id_jam_pelajaran"', () {
      final a = Attendance.fromJson(
        _base(overrides: {'id_jam_pelajaran': 'lh-3'}),
      );
      expect(a.lessonHourId, 'lh-3');
    });
  });

  // ---------------------------------------------------------------------------
  // classId normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — classId field', () {
    test('reads "class_id" directly', () {
      final a = Attendance.fromJson(_base(overrides: {'class_id': 'cls-1'}));
      expect(a.classId, 'cls-1');
    });

    test('falls back to "kelas_id"', () {
      final a = Attendance.fromJson(_base(overrides: {'kelas_id': 'cls-2'}));
      expect(a.classId, 'cls-2');
    });

    test('falls back to "id_kelas"', () {
      final a = Attendance.fromJson(_base(overrides: {'id_kelas': 'cls-3'}));
      expect(a.classId, 'cls-3');
    });

    test('numeric class_id coerced to String', () {
      final a = Attendance.fromJson(_base(overrides: {'class_id': 10}));
      expect(a.classId, '10');
    });

    test('classId is null when absent', () {
      final a = Attendance.fromJson(_base());
      expect(a.classId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // teacherId normalisation
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — teacherId field', () {
    test('reads "teacher_id" directly', () {
      final a = Attendance.fromJson(_base(overrides: {'teacher_id': 't-1'}));
      expect(a.teacherId, 't-1');
    });

    test('falls back to "guru_id"', () {
      final a = Attendance.fromJson(_base(overrides: {'guru_id': 't-2'}));
      expect(a.teacherId, 't-2');
    });

    test('teacherId is null when absent', () {
      final a = Attendance.fromJson(_base());
      expect(a.teacherId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // status field
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — status field', () {
    for (final status in ['hadir', 'sakit', 'izin', 'alpha', 'terlambat']) {
      test('preserves status "$status"', () {
        final a = Attendance.fromJson(_base(overrides: {'status': status}));
        expect(a.status, status);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Equality / immutability (Freezed)
  // ---------------------------------------------------------------------------
  group('Attendance.fromJson — Freezed equality', () {
    test('two identical fromJson calls produce equal objects', () {
      final a1 = Attendance.fromJson(_base());
      final a2 = Attendance.fromJson(_base());
      expect(a1, equals(a2));
    });

    test('different status produces non-equal objects', () {
      final a1 = Attendance.fromJson(_base(overrides: {'status': 'hadir'}));
      final a2 = Attendance.fromJson(_base(overrides: {'status': 'alpha'}));
      expect(a1, isNot(equals(a2)));
    });
  });
}
