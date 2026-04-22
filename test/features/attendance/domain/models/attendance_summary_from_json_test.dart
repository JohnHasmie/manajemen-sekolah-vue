// CRUD data tests for AttendanceSummary.fromJson + _standardizeJson.
//
// _standardizeJson maps Indonesian count keys (hadir, sakit, izin, alpha/alpa)
// to English equivalents and handles multiple alias keys.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance_summary.dart';

Map<String, dynamic> _base({Map<String, dynamic>? overrides}) => {
  'id': 'as-1',
  'date': '2025-03-10',
  ...?overrides,
};

void main() {
  // ---------------------------------------------------------------------------
  // present (hadir) normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — present field', () {
    test('reads "present" directly', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'present': 25}));
      expect(s.present, 25);
    });

    test('falls back to "hadir"', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'hadir': 28}));
      expect(s.present, 28);
    });

    test('defaults to 0 when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.present, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // sick (sakit) normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — sick field', () {
    test('reads "sick" directly', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'sick': 3}));
      expect(s.sick, 3);
    });

    test('falls back to "sakit"', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'sakit': 2}));
      expect(s.sick, 2);
    });

    test('defaults to 0 when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.sick, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // excused (izin) normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — excused field', () {
    test('reads "excused" directly', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'excused': 1}));
      expect(s.excused, 1);
    });

    test('falls back to "izin"', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'izin': 4}));
      expect(s.excused, 4);
    });

    test('defaults to 0 when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.excused, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // absent (alpha/alpa/tidak_hadir) normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — absent field', () {
    test('reads "absent" directly', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'absent': 5}));
      expect(s.absent, 5);
    });

    test('falls back to "alpha"', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'alpha': 6}));
      expect(s.absent, 6);
    });

    test('falls back to "alpa" (common Indonesian misspelling)', () {
      final s = AttendanceSummary.fromJson(_base(overrides: {'alpa': 7}));
      expect(s.absent, 7);
    });

    test('falls back to "tidak_hadir"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'tidak_hadir': 8}),
      );
      expect(s.absent, 8);
    });

    test('"absent" takes priority over "alpha"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'absent': 2, 'alpha': 9}),
      );
      expect(s.absent, 2);
    });

    test('defaults to 0 when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.absent, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // totalStudents normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — totalStudents field', () {
    test('reads "total_students" directly', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'total_students': 30}),
      );
      expect(s.totalStudents, 30);
    });

    test('falls back to "total_siswa"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'total_siswa': 32}),
      );
      expect(s.totalStudents, 32);
    });

    test('defaults to 0 when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.totalStudents, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // subjectName normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — subjectName field', () {
    test('reads "subject_name" directly', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'subject_name': 'Biologi'}),
      );
      expect(s.subjectName, 'Biologi');
    });

    test('falls back to "mata_pelajaran_nama"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'mata_pelajaran_nama': 'Sejarah'}),
      );
      expect(s.subjectName, 'Sejarah');
    });

    test('is null when absent', () {
      final s = AttendanceSummary.fromJson(_base());
      expect(s.subjectName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // subjectId normalisation
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — subjectId field', () {
    test('reads "subject_id" directly', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'subject_id': 'sub-7'}),
      );
      expect(s.subjectId, 'sub-7');
    });

    test('falls back to "id_mata_pelajaran"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'id_mata_pelajaran': 'sub-8'}),
      );
      expect(s.subjectId, 'sub-8');
    });

    test('falls back to "mata_pelajaran_id"', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'mata_pelajaran_id': 'sub-9'}),
      );
      expect(s.subjectId, 'sub-9');
    });

    test('numeric subject_id coerced to String', () {
      final s = AttendanceSummary.fromJson(
        _base(overrides: {'subject_id': 15}),
      );
      expect(s.subjectId, '15');
    });
  });

  // ---------------------------------------------------------------------------
  // Full API payload scenario (realistic response)
  // ---------------------------------------------------------------------------
  group('AttendanceSummary.fromJson — realistic API payloads', () {
    test('Indonesian key payload parses correctly', () {
      final s = AttendanceSummary.fromJson({
        'id': 'sum-1',
        'tanggal': '2025-04-01',
        'hadir': 28,
        'sakit': 1,
        'izin': 0,
        'alpha': 1,
        'total_siswa': 30,
        'mata_pelajaran_nama': 'Matematika',
        'id_mata_pelajaran': 'mp-3',
      });
      expect(s.present, 28);
      expect(s.sick, 1);
      expect(s.excused, 0);
      expect(s.absent, 1);
      expect(s.totalStudents, 30);
      expect(s.subjectName, 'Matematika');
      expect(s.subjectId, 'mp-3');
    });

    test('English key payload parses correctly', () {
      final s = AttendanceSummary.fromJson({
        'id': 'sum-2',
        'date': '2025-04-02',
        'present': 30,
        'sick': 0,
        'excused': 0,
        'absent': 0,
        'total_students': 30,
        'subject_name': 'Physics',
        'subject_id': 'sub-phy',
      });
      expect(s.present, 30);
      expect(s.absent, 0);
      expect(s.totalStudents, 30);
      expect(s.subjectName, 'Physics');
    });

    test('all-zero counts are valid', () {
      final s = AttendanceSummary.fromJson({
        'id': 'sum-3',
        'date': '2025-04-03',
      });
      expect(s.present + s.sick + s.excused + s.absent, 0);
    });
  });
}
