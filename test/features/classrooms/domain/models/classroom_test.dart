/// classroom_test.dart - Unit tests for the Classroom Freezed model.
///
/// The Classroom class is a @freezed data class with [_standardizeJson]
/// that normalizes Indonesian ↔ English keys, nested homeroom teacher
/// objects, and student count variations. Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. fromJson normalizes various API shapes correctly.
///   3. Two instances with the same data ARE equal (Freezed == override).
///   4. Computed helper (hasHomeroomTeacher) works correctly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Factory that returns a fully populated Classroom for reuse across tests.
  Classroom makeClassroom({
    String id = 'cls-1',
    String name = '7A',
    String? homeroomTeacherName = 'Pak Andi',
    int studentCount = 30,
  }) {
    return Classroom(
      id: id,
      name: name,
      homeroomTeacherName: homeroomTeacherName,
      studentCount: studentCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Classroom constructor', () {
    test('stores all required fields correctly', () {
      final cls = Classroom(
        id: 'cls-10',
        name: '8B',
        homeroomTeacherName: 'Bu Siti',
        studentCount: 28,
      );

      expect(cls.id, 'cls-10');
      expect(cls.name, '8B');
      expect(cls.homeroomTeacherName, 'Bu Siti');
      expect(cls.studentCount, 28);
    });

    test('studentCount defaults to 0', () {
      const cls = Classroom(id: 'cls-1', name: '7A');
      expect(cls.studentCount, 0);
    });

    test('studentCount is stored as int', () {
      final cls = makeClassroom(studentCount: 35);
      expect(cls.studentCount, isA<int>());
      expect(cls.studentCount, 35);
    });

    test('accepts studentCount of zero (empty class)', () {
      final cls = makeClassroom(studentCount: 0);
      expect(cls.studentCount, 0);
    });

    test('accepts large studentCount', () {
      final cls = makeClassroom(studentCount: 999);
      expect(cls.studentCount, 999);
    });

    test('different class names are stored correctly', () {
      final names = ['7A', '7B', '8A', '9C', 'XII IPA 2'];
      for (final n in names) {
        final cls = makeClassroom(name: n);
        expect(cls.name, n);
      }
    });

    test('homeroomTeacherName stores full name string', () {
      final cls =
          makeClassroom(homeroomTeacherName: 'Drs. Ahmad Fauzi, M.Pd.');
      expect(cls.homeroomTeacherName, 'Drs. Ahmad Fauzi, M.Pd.');
    });

    test('optional fields default to null', () {
      const cls = Classroom(id: 'cls-1', name: '7A');
      expect(cls.homeroomTeacherName, isNull);
      expect(cls.homeroomTeacherId, isNull);
      expect(cls.gradeLevel, isNull);
      expect(cls.academicYearId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fromJson / _standardizeJson
  // ---------------------------------------------------------------------------

  group('Classroom.fromJson', () {
    test('parses flat English keys', () {
      final cls = Classroom.fromJson({
        'id': 'cls-1',
        'name': '7A',
        'homeroom_teacher_name': 'Pak Budi',
        'student_count': 30,
        'grade_level': '7',
      });

      expect(cls.id, 'cls-1');
      expect(cls.name, '7A');
      expect(cls.homeroomTeacherName, 'Pak Budi');
      expect(cls.studentCount, 30);
      expect(cls.gradeLevel, '7');
    });

    test('normalizes Indonesian key "nama"', () {
      final cls = Classroom.fromJson({
        'id': '2',
        'nama': 'Kelas 8B',
      });
      expect(cls.name, 'Kelas 8B');
    });

    test('extracts homeroom_teacher from Map', () {
      final cls = Classroom.fromJson({
        'id': '3',
        'name': '9A',
        'homeroom_teacher': {'id': 'tch-1', 'name': 'Bu Ani'},
      });

      expect(cls.homeroomTeacherId, 'tch-1');
      expect(cls.homeroomTeacherName, 'Bu Ani');
    });

    test('extracts homeroom_teacher from List', () {
      final cls = Classroom.fromJson({
        'id': '4',
        'name': '9B',
        'homeroom_teacher': [
          {'id': 'tch-2', 'name': 'Pak Joko'},
        ],
      });

      expect(cls.homeroomTeacherId, 'tch-2');
      expect(cls.homeroomTeacherName, 'Pak Joko');
    });

    test('normalizes wali_kelas Map to homeroom teacher fields', () {
      final cls = Classroom.fromJson({
        'id': '5',
        'name': '7C',
        'wali_kelas': {'id': 'tch-3', 'nama': 'Bu Dewi'},
      });

      expect(cls.homeroomTeacherId, 'tch-3');
      expect(cls.homeroomTeacherName, 'Bu Dewi');
    });

    test('normalizes wali_kelas_nama flat fallback', () {
      final cls = Classroom.fromJson({
        'id': '6',
        'name': '8A',
        'wali_kelas_nama': 'Pak Eko',
      });

      expect(cls.homeroomTeacherName, 'Pak Eko');
    });

    test('normalizes jumlah_siswa to student_count', () {
      final cls = Classroom.fromJson({
        'id': '7',
        'name': '7D',
        'jumlah_siswa': 25,
      });
      expect(cls.studentCount, 25);
    });

    test('normalizes tingkat to grade_level', () {
      final cls = Classroom.fromJson({
        'id': '8',
        'name': '9E',
        'tingkat': '9',
      });
      expect(cls.gradeLevel, '9');
    });

    test('coerces numeric id to string', () {
      final cls = Classroom.fromJson({
        'id': 42,
        'name': '7A',
      });
      expect(cls.id, '42');
    });

    test('coerces string student_count to int', () {
      final cls = Classroom.fromJson({
        'id': '1',
        'name': '7A',
        'student_count': '28',
      });
      expect(cls.studentCount, 28);
    });

    test('handles missing student_count gracefully (defaults to 0)', () {
      final cls = Classroom.fromJson({
        'id': '1',
        'name': '7A',
      });
      expect(cls.studentCount, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------------

  group('Classroom computed properties', () {
    test('hasHomeroomTeacher returns true when name is set', () {
      final cls = makeClassroom(homeroomTeacherName: 'Pak Budi');
      expect(cls.hasHomeroomTeacher, isTrue);
    });

    test('hasHomeroomTeacher returns false when name and id are null', () {
      const cls = Classroom(id: 'cls-1', name: '7A');
      expect(cls.hasHomeroomTeacher, isFalse);
    });

    test('hasHomeroomTeacher returns true when only id is set', () {
      const cls = Classroom(
        id: 'cls-1',
        name: '7A',
        homeroomTeacherId: 'tch-1',
      );
      expect(cls.hasHomeroomTeacher, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Equality (Freezed == override)
  // ---------------------------------------------------------------------------

  group('Classroom equality', () {
    test('same instance is equal to itself', () {
      final cls = makeClassroom();
      expect(cls == cls, isTrue);
    });

    test('two separate instances with identical data ARE equal (Freezed)', () {
      final a = makeClassroom();
      final b = makeClassroom();
      expect(a == b, isTrue);
    });

    test('two instances with different ids are not equal', () {
      final a = makeClassroom(id: 'cls-1');
      final b = makeClassroom(id: 'cls-2');
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Classroom edge cases', () {
    test('empty strings are valid field values', () {
      const cls = Classroom(id: '', name: '', studentCount: 0);

      expect(cls.id, '');
      expect(cls.name, '');
      expect(cls.studentCount, 0);
    });

    test('id field accepts numeric string ids from API', () {
      final cls = makeClassroom(id: '42');
      expect(cls.id, '42');
    });
  });
}
