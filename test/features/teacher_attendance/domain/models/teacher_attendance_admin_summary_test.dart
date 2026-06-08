// Parsing tests for the ADMIN teacher-attendance report models —
// TeacherAttendanceAdminSummary (rekap) + TeacherAttendanceListResult
// (per-row detail). These mirror the backend contract the web service
// parses (web-vue teacher-attendance.service.ts adminSummary/adminReport)
// and guard the dynamic-status-column logic + defensive coercion.
//
// Like testing a Laravel API Resource's reverse `fromArray()`: feed in a
// representative JSON envelope, assert the typed shape comes out right.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

void main() {
  group('TeacherAttendanceAdminSummary.fromJson', () {
    test('parses meta, dynamic status columns, rows, and totals', () {
      final summary = TeacherAttendanceAdminSummary.fromJson({
        'meta': {
          'start_date': '2026-06-01',
          'end_date': '2026-06-30',
          'statuses': ['present', 'late', 'sick'],
        },
        'data': [
          {
            'teacher_id': 't1',
            'teacher_name': 'Budi',
            'employee_number': 'NIP-001',
            'present': 18,
            'late': 2,
            'sick': 1,
            'total': 21,
            'present_pct': 95.2,
          },
        ],
        'totals': {
          'present': 18,
          'late': 2,
          'sick': 1,
          'total': 21,
          'present_pct': 95.2,
          'teacher_count': 1,
        },
      });

      expect(summary.startDate, '2026-06-01');
      expect(summary.endDate, '2026-06-30');
      expect(summary.statuses, ['present', 'late', 'sick']);
      expect(summary.rows, hasLength(1));

      final row = summary.rows.first;
      expect(row.teacherId, 't1');
      expect(row.teacherName, 'Budi');
      expect(row.employeeNumber, 'NIP-001');
      expect(row.countFor('present'), 18);
      expect(row.countFor('late'), 2);
      expect(row.countFor('sick'), 1);
      expect(row.total, 21);
      expect(row.presentPct, 95.2);

      expect(summary.totals.countFor('present'), 18);
      expect(summary.totals.total, 21);
      expect(summary.totals.teacherCount, 1);
    });

    test('defaults statuses to [present, late] when meta omits them', () {
      final summary = TeacherAttendanceAdminSummary.fromJson({
        'meta': {'start_date': '2026-06-01', 'end_date': '2026-06-30'},
        'data': [],
        'totals': {},
      });
      expect(summary.statuses, kTeacherAttendanceDefaultStatuses);
      expect(summary.rows, isEmpty);
      // Totals teacher_count falls back to row count (0) when omitted.
      expect(summary.totals.teacherCount, 0);
    });

    test('missing per-status keys read as 0 for a row', () {
      final summary = TeacherAttendanceAdminSummary.fromJson({
        'meta': {
          'start_date': '2026-06-01',
          'end_date': '2026-06-30',
          'statuses': ['present', 'late'],
        },
        'data': [
          {
            'teacher_id': 't2',
            'teacher_name': 'Siti',
            'present': 5,
            'total': 5,
          },
        ],
        'totals': {'present': 5, 'total': 5},
      });
      final row = summary.rows.first;
      expect(row.countFor('late'), 0); // omitted → 0, never crashes
      expect(row.presentPct, 0); // omitted present_pct → 0.0
      expect(row.employeeNumber, isNull);
    });

    test('coerces string/num types defensively', () {
      final summary = TeacherAttendanceAdminSummary.fromJson({
        'meta': {
          'start_date': '2026-06-01',
          'end_date': '2026-06-30',
          'statuses': ['present', 'late'],
        },
        'data': [
          {
            'teacher_id': 9, // int → coerced to '9'
            'teacher_name': 'Ana',
            'present': '7', // string → 7
            'late': '1',
            'total': '8',
            'present_pct': '88.0',
          },
        ],
        'totals': {},
      });
      final row = summary.rows.first;
      expect(row.teacherId, '9');
      expect(row.countFor('present'), 7);
      expect(row.total, 8);
      expect(row.presentPct, 88.0);
    });

    test('non-map body yields an empty, safe summary', () {
      final summary = TeacherAttendanceAdminSummary.fromJson(null);
      expect(summary.rows, isEmpty);
      expect(summary.statuses, kTeacherAttendanceDefaultStatuses);
      expect(summary.startDate, '');
    });
  });

  group('TeacherAttendanceListResult.fromJson', () {
    test('parses paginated detail records + meta', () {
      final result = TeacherAttendanceListResult.fromJson({
        'data': [
          {
            'id': 'r1',
            'teacher_id': 't1',
            'date': '2026-06-08',
            'status': 'late',
            'check_in_at': '2026-06-08T07:15:00+07:00',
            'check_in_distance_m': 42,
            'check_in_outside_geofence': false,
            'teacher': {'name': 'Budi', 'employee_number': 'NIP-001'},
          },
        ],
        'meta': {
          'current_page': 2,
          'last_page': 5,
          'per_page': 25,
          'total': 120,
        },
      });

      expect(result.items, hasLength(1));
      final rec = result.items.first;
      expect(rec.id, 'r1');
      expect(rec.status, 'late');
      expect(rec.isLate, isTrue);
      expect(rec.checkInDistanceM, 42);
      expect(rec.teacherName, 'Budi');
      expect(rec.teacherEmployeeNumber, 'NIP-001');

      expect(result.meta.currentPage, 2);
      expect(result.meta.lastPage, 5);
      expect(result.meta.perPage, 25);
      expect(result.meta.total, 120);
    });

    test('falls back to safe meta when meta is absent', () {
      final result = TeacherAttendanceListResult.fromJson({
        'data': [
          {'id': 'r1', 'status': 'present'},
        ],
      });
      expect(result.items, hasLength(1));
      expect(result.meta.currentPage, 1);
      expect(result.meta.lastPage, 1);
      expect(result.meta.total, 1); // falls back to item count
    });

    test('non-map body yields an empty result', () {
      final result = TeacherAttendanceListResult.fromJson('oops');
      expect(result.items, isEmpty);
      expect(result.meta.total, 0);
    });
  });
}
