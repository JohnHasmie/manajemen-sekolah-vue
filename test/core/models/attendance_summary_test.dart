import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance_summary.dart';

void main() {
  group('AttendanceSummary.fromJson', () {
    test('parses normal response with all fields', () {
      final json = {
        'id': 1,
        'mata_pelajaran_id': 42,
        'mata_pelajaran_nama': 'Matematika',
        'tanggal': '2026-03-25',
        'total_siswa': 30,
        'hadir': 28,
        'sakit': 1,
        'izin': 1,
        'alpha': 0,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, '1');
      expect(summary.subjectId, '42');
      expect(summary.subjectName, 'Matematika');
      expect(summary.date, DateTime(2026, 3, 25));
      expect(summary.totalStudents, 30);
      expect(summary.present, 28);
      expect(summary.sick, 1);
      expect(summary.excused, 1);
      expect(summary.absent, 0);
    });

    test('handles Indonesian aliases (alpa, tanggal, hadir)', () {
      final json = {
        'id': 'uuid-abc',
        'mata_pelajaran_id': 'uuid-def',
        'mata_pelajaran_nama': 'Bahasa Indonesia',
        'tanggal': '2026-01-15',
        'total_siswa': 25,
        'hadir': 20,
        'alpa': 5,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, 'uuid-abc');
      expect(summary.subjectId, 'uuid-def');
      expect(summary.date, DateTime(2026, 1, 15));
      expect(summary.absent, 5);
      expect(summary.present, 20);
    });

    test('handles missing optional fields with defaults', () {
      final json = {'tanggal': '2026-06-01'};

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, isNull);
      expect(summary.subjectId, isNull);
      expect(summary.subjectName, isNull);
      expect(summary.date, DateTime(2026, 6, 1));
      expect(summary.totalStudents, 0);
      expect(summary.present, 0);
      expect(summary.absent, 0);
    });

    test('handles null id and subject_id gracefully', () {
      final json = {
        'id': null,
        'mata_pelajaran_id': null,
        'mata_pelajaran_nama': null,
        'tanggal': '2026-12-31',
        'total_siswa': null,
        'hadir': null,
        'alpha': null,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, isNull);
      expect(summary.subjectId, isNull);
      expect(summary.subjectName, isNull);
      expect(summary.totalStudents, 0);
      expect(summary.present, 0);
      expect(summary.absent, 0);
    });

    test('parses datetime with time component', () {
      final json = {'tanggal': '2026-03-25T14:30:00'};

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.date.year, 2026);
      expect(summary.date.month, 3);
      expect(summary.date.day, 25);
      expect(summary.date.hour, 14);
      expect(summary.date.minute, 30);
    });
  });
}
