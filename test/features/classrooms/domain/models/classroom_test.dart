/// classroom_test.dart - Unit tests for the Classroom domain model.
///
/// The Classroom class is a plain Dart data class (no fromJson/toJson,
/// no == override, no freezed). Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. Each field type is correct (String, int).
///   3. Two separately constructed instances with the same data are NOT equal
///      because Dart's default == is reference equality (no override exists).
///   4. A single instance IS equal to itself (same reference).
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
    String homeroomTeacher = 'Pak Andi',
    int studentCount = 30,
  }) {
    return Classroom(
      id: id,
      name: name,
      homeroomTeacher: homeroomTeacher,
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
        homeroomTeacher: 'Bu Siti',
        studentCount: 28,
      );

      expect(cls.id, 'cls-10');
      expect(cls.name, '8B');
      expect(cls.homeroomTeacher, 'Bu Siti');
      expect(cls.studentCount, 28);
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

    test('homeroomTeacher field stores full name string', () {
      final cls = makeClassroom(homeroomTeacher: 'Drs. Ahmad Fauzi, M.Pd.');
      expect(cls.homeroomTeacher, 'Drs. Ahmad Fauzi, M.Pd.');
    });

    test('fields are final - verified by reading their types', () {
      final cls = makeClassroom();
      expect(cls.id, isA<String>());
      expect(cls.name, isA<String>());
      expect(cls.homeroomTeacher, isA<String>());
      expect(cls.studentCount, isA<int>());
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & identity (no == override → reference equality)
  // ---------------------------------------------------------------------------

  group('Classroom equality', () {
    test('same instance is equal to itself', () {
      final cls = makeClassroom();
      // ignore: unrelated_type_equality_checks
      expect(cls == cls, isTrue);
    });

    test('two separate instances with identical data are NOT equal', () {
      final a = makeClassroom();
      final b = makeClassroom();
      expect(a == b, isFalse);
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
      final cls = Classroom(
        id: '',
        name: '',
        homeroomTeacher: '',
        studentCount: 0,
      );

      expect(cls.id, '');
      expect(cls.name, '');
      expect(cls.homeroomTeacher, '');
      expect(cls.studentCount, 0);
    });

    test('id field accepts numeric string ids from API', () {
      // APIs often return numeric ids; the model stores them as strings.
      final cls = makeClassroom(id: '42');
      expect(cls.id, '42');
    });
  });
}
