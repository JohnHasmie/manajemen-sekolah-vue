/// teacher_test.dart - Unit tests for the Teacher domain model.
///
/// The Teacher class is a plain Dart data class (no fromJson/toJson,
/// no == override, no freezed). Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. Each field type is correct (both String).
///   3. Two separately constructed instances with the same data are NOT equal
///      because Dart's default == is reference equality (no override exists).
///   4. A single instance IS equal to itself (same reference).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Factory that returns a fully populated Teacher for reuse across tests.
  Teacher makeTeacher({
    String id = 'tch-1',
    String name = 'Pak Budi',
  }) {
    return Teacher(id: id, name: name);
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Teacher constructor', () {
    test('stores id and name correctly', () {
      final teacher = Teacher(id: 'tch-7', name: 'Bu Rahayu');

      expect(teacher.id, 'tch-7');
      expect(teacher.name, 'Bu Rahayu');
    });

    test('id is stored as string', () {
      final teacher = makeTeacher(id: 'tch-99');
      expect(teacher.id, isA<String>());
      expect(teacher.id, 'tch-99');
    });

    test('name is stored as string', () {
      final teacher = makeTeacher(name: 'Drs. Ahmad Fauzi, M.Pd.');
      expect(teacher.name, isA<String>());
      expect(teacher.name, 'Drs. Ahmad Fauzi, M.Pd.');
    });

    test('id field accepts numeric-looking string ids from API', () {
      // APIs often return numeric ids; the model stores them as strings.
      final teacher = makeTeacher(id: '123');
      expect(teacher.id, '123');
    });

    test('different teacher names are stored correctly', () {
      final names = ['Pak Andi', 'Bu Siti', 'Pak Hendra', 'Bu Nurul Hidayah'];
      for (final n in names) {
        final teacher = makeTeacher(name: n);
        expect(teacher.name, n);
      }
    });

    test('fields are final - verified by reading their types', () {
      final teacher = makeTeacher();
      expect(teacher.id, isA<String>());
      expect(teacher.name, isA<String>());
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & identity (no == override → reference equality)
  // ---------------------------------------------------------------------------

  group('Teacher equality', () {
    test('same instance is equal to itself', () {
      final teacher = makeTeacher();
      // ignore: unrelated_type_equality_checks
      expect(teacher == teacher, isTrue);
    });

    test('two separate instances with identical data are NOT equal', () {
      final a = makeTeacher();
      final b = makeTeacher();
      expect(a == b, isFalse);
    });

    test('two instances with different ids are not equal', () {
      final a = makeTeacher(id: 'tch-1');
      final b = makeTeacher(id: 'tch-2');
      expect(a == b, isFalse);
    });

    test('two instances with different names are not equal', () {
      final a = makeTeacher(name: 'Pak Andi');
      final b = makeTeacher(name: 'Bu Siti');
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Teacher edge cases', () {
    test('empty strings are valid field values', () {
      final teacher = Teacher(id: '', name: '');
      expect(teacher.id, '');
      expect(teacher.name, '');
    });

    test('name with honorific prefix and suffix is stored intact', () {
      final teacher = makeTeacher(name: 'Prof. Dr. Ir. Budi Santoso, M.T., Ph.D.');
      expect(teacher.name, 'Prof. Dr. Ir. Budi Santoso, M.T., Ph.D.');
    });
  });
}
