/// teacher_test.dart - Unit tests for the Teacher Freezed model.
///
/// The Teacher class is a @freezed data class with [_standardizeJson]
/// that normalizes Indonesian ↔ English keys, nested user objects,
/// homeroom_class shapes, and subject lists. Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. fromJson normalizes various API shapes correctly.
///   3. Two instances with the same data ARE equal (Freezed == override).
///   4. Computed helpers (isHomeroomTeacher, initials) work correctly.
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
    String email = 'budi@school.id',
    String role = 'guru',
  }) {
    return Teacher(id: id, name: name, email: email, role: role);
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Teacher constructor', () {
    test('stores all required fields correctly', () {
      const teacher = Teacher(
        id: 'tch-7',
        name: 'Bu Rahayu',
        email: 'rahayu@school.id',
        role: 'guru',
      );

      expect(teacher.id, 'tch-7');
      expect(teacher.name, 'Bu Rahayu');
      expect(teacher.email, 'rahayu@school.id');
      expect(teacher.role, 'guru');
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

    test('optional fields default to null', () {
      final teacher = makeTeacher();
      expect(teacher.employeeNumber, isNull);
      expect(teacher.phoneNumber, isNull);
      expect(teacher.address, isNull);
      expect(teacher.homeroomClassId, isNull);
      expect(teacher.homeroomClassName, isNull);
      expect(teacher.subjectIds, isNull);
      expect(teacher.subjectNames, isNull);
      expect(teacher.userId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fromJson / _standardizeJson
  // ---------------------------------------------------------------------------

  group('Teacher.fromJson', () {
    test('parses flat English keys', () {
      final teacher = Teacher.fromJson({
        'id': 'tch-1',
        'name': 'Pak Budi',
        'email': 'budi@school.id',
        'role': 'guru',
        'employee_number': 'NIP001',
        'phone_number': '08123456',
      });

      expect(teacher.id, 'tch-1');
      expect(teacher.name, 'Pak Budi');
      expect(teacher.email, 'budi@school.id');
      expect(teacher.role, 'guru');
      expect(teacher.employeeNumber, 'NIP001');
      expect(teacher.phoneNumber, '08123456');
    });

    test('normalizes Indonesian key "nama"', () {
      final teacher = Teacher.fromJson({
        'id': '2',
        'nama': 'Bu Siti',
        'email': 'siti@school.id',
        'role': 'guru',
      });

      expect(teacher.name, 'Bu Siti');
    });

    test('extracts email from nested user object', () {
      final teacher = Teacher.fromJson({
        'id': '3',
        'name': 'Pak Hendra',
        'role': 'guru',
        'user': {'id': 'user-3', 'email': 'hendra@school.id'},
      });

      expect(teacher.email, 'hendra@school.id');
      expect(teacher.userId, 'user-3');
    });

    test('extracts homeroom_class from Map', () {
      final teacher = Teacher.fromJson({
        'id': '4',
        'name': 'Bu Ani',
        'email': 'ani@school.id',
        'role': 'guru',
        'homeroom_class': {'id': 'cls-1', 'name': '7A'},
      });

      expect(teacher.homeroomClassId, 'cls-1');
      expect(teacher.homeroomClassName, '7A');
    });

    test('extracts homeroom_class from List', () {
      final teacher = Teacher.fromJson({
        'id': '5',
        'name': 'Pak Joko',
        'email': 'joko@school.id',
        'role': 'guru',
        'homeroom_classes': [
          {'id': 'cls-2', 'name': '8B'},
        ],
      });

      expect(teacher.homeroomClassId, 'cls-2');
      expect(teacher.homeroomClassName, '8B');
    });

    test('normalizes NIP / nuptk to employee_number', () {
      final teacher = Teacher.fromJson({
        'id': '6',
        'name': 'Bu Dewi',
        'email': 'dewi@school.id',
        'role': 'guru',
        'nip': '198501012010011001',
      });

      expect(teacher.employeeNumber, '198501012010011001');
    });

    test('normalizes Indonesian phone and address', () {
      final teacher = Teacher.fromJson({
        'id': '7',
        'name': 'Pak Eko',
        'email': 'eko@school.id',
        'role': 'guru',
        'nomor_hp': '081234567890',
        'alamat': 'Jl. Merdeka No. 1',
      });

      expect(teacher.phoneNumber, '081234567890');
      expect(teacher.address, 'Jl. Merdeka No. 1');
    });

    test('coerces numeric id to string', () {
      final teacher = Teacher.fromJson({
        'id': 42,
        'name': 'Pak Test',
        'email': 'test@school.id',
        'role': 'guru',
      });
      expect(teacher.id, '42');
    });

    test('maps teacher_id alias to id', () {
      final teacher = Teacher.fromJson({
        'teacher_id': 'tch-99',
        'name': 'Bu Test',
        'email': 'test@school.id',
        'role': 'guru',
      });
      expect(teacher.id, 'tch-99');
    });

    test('extracts subjects from list of Maps', () {
      final teacher = Teacher.fromJson({
        'id': '8',
        'name': 'Bu Rina',
        'email': 'rina@school.id',
        'role': 'guru',
        'subjects': [
          {'id': 's1', 'name': 'Matematika'},
          {'id': 's2', 'name': 'Fisika'},
        ],
      });

      expect(teacher.subjectIds, ['s1', 's2']);
      expect(teacher.subjectNames, ['Matematika', 'Fisika']);
    });

    test('defaults role to guru when missing', () {
      final teacher = Teacher.fromJson({
        'id': '9',
        'name': 'Pak Default',
        'email': 'default@school.id',
      });
      expect(teacher.role, 'guru');
    });
  });

  // ---------------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------------

  group('Teacher computed properties', () {
    test('isHomeroomTeacher returns true when homeroomClassId is set', () {
      const teacher = Teacher(
        id: '1',
        name: 'Test',
        email: 'test@school.id',
        role: 'guru',
        homeroomClassId: 'cls-1',
      );
      expect(teacher.isHomeroomTeacher, isTrue);
    });

    test('isHomeroomTeacher returns false when homeroomClassId is null', () {
      final teacher = makeTeacher();
      expect(teacher.isHomeroomTeacher, isFalse);
    });

    test('isHomeroomTeacher returns false when homeroomClassId is empty', () {
      const teacher = Teacher(
        id: '1',
        name: 'Test',
        email: 'test@school.id',
        role: 'guru',
        homeroomClassId: '',
      );
      expect(teacher.isHomeroomTeacher, isFalse);
    });

    test('initials returns two-letter initials for two-word name', () {
      final teacher = makeTeacher(name: 'John Doe');
      expect(teacher.initials, 'JD');
    });

    test('initials returns single letter for single-word name', () {
      final teacher = makeTeacher(name: 'Budi');
      expect(teacher.initials, 'B');
    });

    test('initials returns ? for empty name', () {
      final teacher = makeTeacher(name: '');
      expect(teacher.initials, '?');
    });
  });

  // ---------------------------------------------------------------------------
  // Equality (Freezed == override)
  // ---------------------------------------------------------------------------

  group('Teacher equality', () {
    test('same instance is equal to itself', () {
      final teacher = makeTeacher();
      expect(teacher == teacher, isTrue);
    });

    test('two separate instances with identical data ARE equal (Freezed)', () {
      final a = makeTeacher();
      final b = makeTeacher();
      expect(a == b, isTrue);
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
      const teacher = Teacher(id: '', name: '', email: '', role: '');
      expect(teacher.id, '');
      expect(teacher.name, '');
      expect(teacher.email, '');
    });

    test('name with honorific prefix and suffix is stored intact', () {
      final teacher = makeTeacher(
        name: 'Prof. Dr. Ir. Budi Santoso, M.T., Ph.D.',
      );
      expect(teacher.name, 'Prof. Dr. Ir. Budi Santoso, M.T., Ph.D.');
    });
  });
}
