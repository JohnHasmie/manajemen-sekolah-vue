/// Tests for AttendanceSummary model — fromJson serialization.
///
/// Verifies that Indonesian API field names (mata_pelajaran_id, tanggal, hadir,
/// tidak_hadir, etc.) are correctly mapped to English property names.
library;

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
        'tidak_hadir': 2,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, '1');
      expect(summary.subjectId, '42');
      expect(summary.subjectName, 'Matematika');
      expect(summary.date, DateTime(2026, 3, 25));
      expect(summary.totalStudents, 30);
      expect(summary.present, 28);
      expect(summary.absent, 2);
    });

    test('handles string id and subject id', () {
      final json = {
        'id': 'uuid-abc',
        'mata_pelajaran_id': 'uuid-def',
        'mata_pelajaran_nama': 'Bahasa Indonesia',
        'tanggal': '2026-01-15',
        'total_siswa': 25,
        'hadir': 20,
        'tidak_hadir': 5,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, 'uuid-abc');
      expect(summary.subjectId, 'uuid-def');
    });

    test('handles missing optional fields with defaults', () {
      final json = {
        'tanggal': '2026-06-01',
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, '');
      expect(summary.subjectId, '');
      expect(summary.subjectName, '');
      expect(summary.date, DateTime(2026, 6, 1));
      expect(summary.totalStudents, 0);
      expect(summary.present, 0);
      expect(summary.absent, 0);
    });

    test('handles null id and mata_pelajaran_id gracefully', () {
      final json = {
        'id': null,
        'mata_pelajaran_id': null,
        'mata_pelajaran_nama': null,
        'tanggal': '2026-12-31',
        'total_siswa': null,
        'hadir': null,
        'tidak_hadir': null,
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.id, '');
      expect(summary.subjectId, '');
      expect(summary.subjectName, '');
      expect(summary.totalStudents, 0);
      expect(summary.present, 0);
      expect(summary.absent, 0);
    });

    test('parses datetime with time component', () {
      final json = {
        'tanggal': '2026-03-25T14:30:00',
      };

      final summary = AttendanceSummary.fromJson(json);

      expect(summary.date.year, 2026);
      expect(summary.date.month, 3);
      expect(summary.date.day, 25);
      expect(summary.date.hour, 14);
      expect(summary.date.minute, 30);
    });
  });
}
