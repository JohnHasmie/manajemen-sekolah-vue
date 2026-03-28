/// Tests for Student model — fromJson / toJson serialization.
///
/// Verifies the two API response shapes (flat kelas_nama vs nested class.name)
/// are both handled correctly, and that missing/null fields get safe defaults.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

void main() {
  group('Student.fromJson', () {
    test('parses flat response with kelas_nama field', () {
      final json = {
        'id': 1,
        'name': 'Budi Santoso',
        'kelas_nama': '7A',
        'student_number': 'S001',
        'address': 'Jl. Merdeka 10',
        'guardian_name': 'Pak Santoso',
        'phone_number': '08123456789',
        'class_id': 5,
        'student_class_id': 42,
      };

      final student = Student.fromJson(json);

      expect(student.id, '1');
      expect(student.name, 'Budi Santoso');
      expect(student.className, '7A');
      expect(student.studentNumber, 'S001');
      expect(student.address, 'Jl. Merdeka 10');
      expect(student.guardianName, 'Pak Santoso');
      expect(student.phoneNumber, '08123456789');
      expect(student.classId, '5');
      expect(student.studentClassId, '42');
    });

    test('parses nested response with class.name field', () {
      final json = {
        'id': 2,
        'name': 'Siti Aminah',
        'class': {'name': '8B'},
        'student_number': 'S002',
        'address': 'Jl. Sudirman 5',
        'guardian_name': 'Bu Aminah',
        'phone_number': '08198765432',
        'class_id': 8,
        'student_class_id': 99,
      };

      final student = Student.fromJson(json);

      expect(student.className, '8B');
      expect(student.name, 'Siti Aminah');
    });

    test('handles missing fields with safe defaults', () {
      final json = {'id': 3};

      final student = Student.fromJson(json);

      expect(student.id, '3');
      expect(student.name, '');
      expect(student.className, '');
      expect(student.studentNumber, '');
      expect(student.address, '');
      expect(student.guardianName, '');
      expect(student.phoneNumber, '');
    });

    test('handles null optional fields (classId, studentClassId)', () {
      final json = {
        'id': 4,
        'name': 'Test',
        'class_id': null,
        'student_class_id': null,
      };

      final student = Student.fromJson(json);

      expect(student.classId, isNull);
      expect(student.studentClassId, isNull);
    });

    test('converts numeric id to string', () {
      final json = {'id': 123};
      final student = Student.fromJson(json);
      expect(student.id, '123');
    });

    test('converts string id to string', () {
      final json = {'id': 'abc-uuid'};
      final student = Student.fromJson(json);
      expect(student.id, 'abc-uuid');
    });

    test('flat kelas_nama takes precedence over nested class.name', () {
      // When both are present, kelas_nama is checked first via ?? chain.
      final json = {
        'id': 5,
        'kelas_nama': 'Flat7A',
        'class': {'name': 'Nested8B'},
      };

      final student = Student.fromJson(json);
      expect(student.className, 'Flat7A');
    });
  });

  group('Student.toJson', () {
    test('produces correct snake_case keys', () {
      const student = Student(
        id: '1',
        name: 'Budi',
        className: '7A',
        studentNumber: 'S001',
        address: 'Jl. Merdeka',
        guardianName: 'Pak Budi',
        phoneNumber: '0812345',
        classId: '5',
        studentClassId: '42',
      );

      final json = student.toJson();

      expect(json['id'], '1');
      expect(json['name'], 'Budi');
      expect(json['kelas_nama'], '7A');
      expect(json['student_number'], 'S001');
      expect(json['address'], 'Jl. Merdeka');
      expect(json['guardian_name'], 'Pak Budi');
      expect(json['phone_number'], '0812345');
      expect(json['class_id'], '5');
      expect(json['student_class_id'], '42');
    });

    test('null optional fields serialize as null', () {
      const student = Student(id: '1');

      final json = student.toJson();

      expect(json['class_id'], isNull);
      expect(json['student_class_id'], isNull);
    });
  });

  group('Student round-trip', () {
    test('toJson then fromJson preserves all fields', () {
      const original = Student(
        id: '10',
        name: 'Round Trip',
        className: '9C',
        studentNumber: 'S999',
        address: 'Jl. Test 1',
        guardianName: 'Guardian',
        phoneNumber: '081111',
        classId: '3',
        studentClassId: '77',
      );

      final json = original.toJson();
      final restored = Student.fromJson(json);

      expect(restored, original);
    });
  });
}
