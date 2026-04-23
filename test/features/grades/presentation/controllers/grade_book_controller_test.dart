// Unit tests for GradeBookController — covers all pure functions that have
// no external side-effects (no API calls, no cache, no BuildContext).
//
// Like testing a Laravel Controller's pure helper methods in isolation:
// we only test deterministic input → output logic, leaving network/cache
// methods for integration tests.
//
// Controller is obtained from a ProviderContainer so the production
// DI wiring is exercised (gradeBookControllerProvider returns the real class).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_models.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_data_processor.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

// ---------------------------------------------------------------------------
// Helpers — factory functions used across test groups
// ---------------------------------------------------------------------------

/// Builds a minimal [Student] for test purposes.
Student _student({
  String id = '1',
  String name = 'Budi Santoso',
  String studentNumber = 'NIS001',
  String? studentClassId,
}) => Student(
  id: id,
  name: name,
  className: '7A',
  studentNumber: studentNumber,
  address: '',
  guardianName: '',
  phoneNumber: '',
  studentClassId: studentClassId,
);

/// Builds a minimal grade record matching the internal (normalised) format
/// produced by [GradeBookController.processAndApplyGradeData].
Map<String, dynamic> _grade({
  String siswaId = '1',
  String? studentClassId,
  String type = 'uh',
  String date = '2025-01-15',
  String title = '',
  String? assessmentId,
  dynamic score = 85,
  String? id,
}) => {
  'id': id,
  'siswa_id': siswaId,
  'student_class_id': studentClassId,
  'jenis': type,
  'tanggal': date,
  'title': title,
  'assessment_id': assessmentId,
  'score': score,
  'deskripsi': null,
};

/// Builds an assessment header map.
Map<String, dynamic> _header({
  String date = '2025-01-15',
  String title = '',
  String? id,
}) => {'id': id, 'date': date, 'title': title, 'is_temp': false};

void main() {
  late ProviderContainer container;
  late GradeBookController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(gradeBookControllerProvider);
  });

  tearDown(() => container.dispose());

  // ─── filterStudents ───────────────────────────────────────────────────────

  group('filterStudents', () {
    final students = [
      _student(id: '1', name: 'Budi Santoso', studentNumber: 'NIS001'),
      _student(id: '2', name: 'Ani Rahayu', studentNumber: 'NIS002'),
      _student(id: '3', name: 'Candra Wijaya', studentNumber: 'NIS003'),
    ];

    test('empty query returns all students unchanged', () {
      expect(ctrl.filterStudents(students, ''), hasLength(3));
    });

    test('matches by name substring (case-insensitive)', () {
      final result = ctrl.filterStudents(students, 'budi');
      expect(result, hasLength(1));
      expect(result.first.name, 'Budi Santoso');
    });

    test('matches by studentNumber substring', () {
      final result = ctrl.filterStudents(students, 'NIS002');
      expect(result, hasLength(1));
      expect(result.first.id, '2');
    });

    test('query matches multiple students', () {
      // 'a' appears in "Budi Santoso", "Ani Rahayu", "Candra Wijaya"
      final result = ctrl.filterStudents(students, 'a');
      expect(result.length, greaterThan(1));
    });

    test('no match returns empty list', () {
      expect(ctrl.filterStudents(students, 'ZZZZZ'), isEmpty);
    });

    test('returns new list — does not mutate original', () {
      final original = List.of(students);
      ctrl.filterStudents(students, 'budi');
      expect(students, original);
    });
  });

  // ─── computeFilteredGradeTypes ────────────────────────────────────────────

  group('computeFilteredGradeTypes', () {
    const allTypes = ['uh', 'tugas', 'uts', 'uas', 'pts', 'pas'];

    test('all enabled returns all types in order', () {
      final filter = {for (final t in allTypes) t: true};
      expect(ctrl.computeFilteredGradeTypes(allTypes, filter), allTypes);
    });

    test('all disabled returns empty list', () {
      final filter = {for (final t in allTypes) t: false};
      expect(ctrl.computeFilteredGradeTypes(allTypes, filter), isEmpty);
    });

    test('only enabled types are returned', () {
      final filter = {
        'uh': true,
        'tugas': false,
        'uts': true,
        'uas': false,
        'pts': false,
        'pas': false,
      };
      expect(ctrl.computeFilteredGradeTypes(allTypes, filter), ['uh', 'uts']);
    });

    test('preserves original order of allGradeTypeList', () {
      final filter = {
        'pts': true,
        'uh': true,
        'tugas': false,
        'uts': false,
        'uas': false,
        'pas': false,
      };
      // Order should follow allTypes, not the filter map iteration order
      expect(ctrl.computeFilteredGradeTypes(allTypes, filter), ['uh', 'pts']);
    });
  });

  // ─── formatGradeValue ─────────────────────────────────────────────────────

  group('formatGradeValue', () {
    test('null returns empty string', () {
      expect(ctrl.formatGradeValue(null), '');
    });

    test('non-numeric string returns empty string', () {
      expect(ctrl.formatGradeValue('abc'), '');
    });

    test('integer value strips trailing .0', () {
      expect(ctrl.formatGradeValue(85), '85');
      expect(ctrl.formatGradeValue(85.0), '85');
      expect(ctrl.formatGradeValue('85.0'), '85');
      expect(ctrl.formatGradeValue('100.0'), '100');
    });

    test('fractional value kept as-is', () {
      expect(ctrl.formatGradeValue(85.5), '85.5');
      expect(ctrl.formatGradeValue('72.3'), '72.3');
    });

    test('zero returns "0"', () {
      expect(ctrl.formatGradeValue(0), '0');
      expect(ctrl.formatGradeValue(0.0), '0');
    });
  });

  // ─── formatDateDisplay ────────────────────────────────────────────────────

  group('formatDateDisplay', () {
    test('converts yyyy-MM-dd to dd/MM/yyyy', () {
      expect(ctrl.formatDateDisplay('2025-01-15'), '15/01/2025');
      expect(ctrl.formatDateDisplay('2025-12-31'), '31/12/2025');
    });

    test('returns input unchanged when format is unexpected', () {
      // Uses slashes — split on '-' yields 1 part, so no reformat occurs
      expect(ctrl.formatDateDisplay('2025/01/15'), '2025/01/15');
      // Non-date string with no dashes
      expect(ctrl.formatDateDisplay('notadate'), 'notadate');
    });

    test('handles ISO datetime strings — uses only the date part via split', () {
      // The method splits on '-' — an ISO datetime has extra parts after split
      // so it won't produce the dd/MM/yyyy output. Verify it doesn't crash.
      expect(ctrl.formatDateDisplay('2025-01-15T10:30:00'), isA<String>());
    });
  });

  // ─── addNewAssessment ─────────────────────────────────────────────────────

  group('addNewAssessment', () {
    test('returns null when pickedDate is null', () {
      expect(ctrl.addNewAssessment('uh', {}, null), isNull);
    });

    test('adds new temp header for the given type', () {
      final result = ctrl.addNewAssessment('uh', {}, DateTime(2025, 3, 10));
      expect(result, isNotNull);
      expect(result!['uh'], hasLength(1));
      expect(result['uh']!.first['date'], '2025-03-10');
      expect(result['uh']!.first['is_temp'], isTrue);
      expect(result['uh']!.first['id'], isNull);
    });

    test(
      'does not add duplicate date for same type (temp entry with null title)',
      () {
        // addNewAssessment deduplicates only against temp entries (title == null).
        final existing = {
          'uh': [
            {'id': null, 'date': '2025-03-10', 'title': null, 'is_temp': true},
          ],
        };
        final result = ctrl.addNewAssessment(
          'uh',
          existing,
          DateTime(2025, 3, 10),
        );
        // Already exists with same date + null title — should not add duplicate
        expect(result!['uh'], hasLength(1));
      },
    );

    test('creates list for new type when type did not exist', () {
      final result = ctrl.addNewAssessment('uts', {}, DateTime(2025, 6, 1));
      expect(result!['uts'], hasLength(1));
    });

    test('does not mutate original assessmentHeaders map', () {
      final original = <String, List<Map<String, dynamic>>>{};
      ctrl.addNewAssessment('uh', original, DateTime(2025, 1, 1));
      expect(original, isEmpty);
    });

    test('sorts headers by date after insertion', () {
      final existing = {
        'uh': [_header(date: '2025-03-20')],
      };
      final result = ctrl.addNewAssessment(
        'uh',
        existing,
        DateTime(2025, 3, 5),
      );
      final dates = result!['uh']!.map((h) => h['date']).toList();
      expect(dates, ['2025-03-05', '2025-03-20']);
    });
  });

  // ─── getGradeForStudentAndHeader ──────────────────────────────────────────

  group('getGradeForStudentAndHeader', () {
    final student = _student(id: '1', studentClassId: 'sc1');
    final grades = [
      _grade(
        siswaId: '1',
        type: 'uh',
        date: '2025-01-15',
        title: '',
        assessmentId: 'a1',
        score: 80,
      ),
      _grade(
        siswaId: '2',
        type: 'uh',
        date: '2025-01-15',
        title: '',
        assessmentId: 'a1',
        score: 90,
      ),
      _grade(
        siswaId: '1',
        type: 'tugas',
        date: '2025-02-01',
        title: 'PR1',
        assessmentId: 'a2',
        score: 75,
      ),
    ];

    test('returns correct grade matched by assessmentId + studentId', () {
      final header = _header(date: '2025-01-15', id: 'a1');
      final result = ctrl.getGradeForStudentAndHeader(
        student,
        'uh',
        header,
        grades,
      );
      expect(result, isNotNull);
      expect(result!['score'], 80);
    });

    test('returns null when student has no grade for the header', () {
      final other = _student(id: '99');
      final header = _header(date: '2025-01-15', id: 'a1');
      final result = ctrl.getGradeForStudentAndHeader(
        other,
        'uh',
        header,
        grades,
      );
      expect(result, isNull);
    });

    test('returns null when grade type does not match', () {
      final header = _header(date: '2025-01-15', id: 'a1');
      final result = ctrl.getGradeForStudentAndHeader(
        student,
        'tugas',
        header,
        grades,
      );
      expect(result, isNull);
    });

    test(
      'returns correct grade when matched by date + title (no assessmentId)',
      () {
        final gradesNoId = [
          _grade(
            siswaId: '1',
            type: 'tugas',
            date: '2025-02-01',
            title: 'PR1',
            assessmentId: null,
            score: 75,
          ),
        ];
        final header = _header(date: '2025-02-01', title: 'PR1', id: null);
        final result = ctrl.getGradeForStudentAndHeader(
          student,
          'tugas',
          header,
          gradesNoId,
        );
        expect(result, isNotNull);
        expect(result!['score'], 75);
      },
    );

    test('returns null on empty grade list', () {
      final header = _header(date: '2025-01-15', id: 'a1');
      final result = ctrl.getGradeForStudentAndHeader(
        student,
        'uh',
        header,
        [],
      );
      expect(result, isNull);
    });
  });

  // ─── GradeDataProcessor.processRawData ─────────────────────────────────────

  group('GradeDataProcessor.processRawData', () {
    const allTypes = ['uh', 'tugas', 'uts', 'uas', 'pts', 'pas'];

    final rawStudents = [
      {
        'id': '1',
        'name': 'Budi',
        'class_name': '7A',
        'student_number': 'NIS001',
        'address': '',
        'guardian_name': '',
        'phone_number': '',
      },
      {
        'id': '2',
        'name': 'Ani',
        'class_name': '7A',
        'student_number': 'NIS002',
        'address': '',
        'guardian_name': '',
        'phone_number': '',
      },
    ];

    final rawGrades = [
      {
        'id': 'g1',
        'student_id': '1',
        'assessment': {'type': 'uh', 'date': '2025-01-15', 'title': 'Quiz 1'},
        'assessment_id': 'a1',
        'score': 85,
        'notes': 'Good',
      },
      {
        'id': 'g2',
        'student_id': '2',
        'assessment': {'type': 'uh', 'date': '2025-01-15', 'title': 'Quiz 1'},
        'assessment_id': 'a1',
        'score': 90,
        'notes': null,
      },
      {
        'id': 'g3',
        'student_id': '1',
        'assessment': {'type': 'tugas', 'date': '2025-02-01', 'title': 'PR1'},
        'assessment_id': 'a2',
        'score': 75,
        'notes': null,
      },
    ];

    test('produces correct student list from raw data', () {
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades,
        allTypes,
      );
      expect(result.studentList, hasLength(2));
      expect(result.studentList.first.name, 'Budi');
    });

    test('filteredStudentList equals studentList on first load', () {
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades,
        allTypes,
      );
      expect(result.filteredStudentList.length, result.studentList.length);
    });

    test('produces correct gradeList length', () {
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades,
        allTypes,
      );
      expect(result.gradeList, hasLength(3));
    });

    test('filters out grades for students not in the student list', () {
      final orphanGrade = [
        {
          'id': 'g99',
          'student_id': '99',
          'assessment': {'type': 'uh', 'date': '2025-01-15', 'title': ''},
          'assessment_id': 'a1',
          'score': 100,
        },
      ];
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        orphanGrade,
        allTypes,
      );
      expect(result.gradeList, isEmpty);
    });

    test('builds assessment headers grouped by type', () {
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades,
        allTypes,
      );
      expect(result.assessmentHeaders.containsKey('uh'), isTrue);
      expect(result.assessmentHeaders.containsKey('tugas'), isTrue);
      // Only 2 types in rawGrades
      expect(result.assessmentHeaders.length, 2);
    });

    test('deduplicates assessment headers by assessmentId', () {
      // Both g1 and g2 share assessment_id a1 — should produce only 1 header
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades,
        allTypes,
      );
      expect(result.assessmentHeaders['uh'], hasLength(1));
    });

    test('assessment headers are sorted by date', () {
      final rawGrades2 = [
        {
          'id': 'gA',
          'student_id': '1',
          'assessment': {'type': 'uh', 'date': '2025-03-01', 'title': 'Late'},
          'assessment_id': 'aA',
          'score': 70,
        },
        {
          'id': 'gB',
          'student_id': '1',
          'assessment': {'type': 'uh', 'date': '2025-01-01', 'title': 'Early'},
          'assessment_id': 'aB',
          'score': 80,
        },
      ];
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        rawGrades2,
        allTypes,
      );
      final dates = result.assessmentHeaders['uh']!
          .map((h) => h['date'])
          .toList();
      expect(dates, ['2025-01-01', '2025-03-01']);
    });

    test('grades for unknown types are excluded from assessmentHeaders', () {
      final gradeWithUnknownType = [
        {
          'id': 'gX',
          'student_id': '1',
          'assessment': {
            'type': 'unknown_type',
            'date': '2025-01-01',
            'title': '',
          },
          'assessment_id': 'aX',
          'score': 50,
        },
      ];
      final result = GradeDataProcessor.processRawData(
        rawStudents,
        gradeWithUnknownType,
        allTypes,
      );
      expect(result.assessmentHeaders, isEmpty);
    });

    test('empty grades produce empty assessmentHeaders', () {
      final result = GradeDataProcessor.processRawData(rawStudents, [], allTypes);
      expect(result.assessmentHeaders, isEmpty);
      expect(result.studentList, hasLength(2));
    });
  });

  // ─── LoadDataResult.failure ───────────────────────────────────────────────

  group('LoadDataResult.failure', () {
    test('failure constructor sets error message', () {
      final result = LoadDataResult.failure('Network error');
      expect(result.error, 'Network error');
      expect(result.studentList, isEmpty);
      expect(result.gradeList, isEmpty);
      expect(result.isLoading, isFalse);
    });
  });
}
