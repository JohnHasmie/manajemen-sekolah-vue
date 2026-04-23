import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

void main() {
  group('Student.fromJson', () {
    test('parses flat response with kelas_nama field', () {
      final json = {
        'id': 1,
        'nama': 'Budi Santoso',
        'id_kelas': 5,
        'kelas_nama': '7A',
        'nomor_induk': 'S001',
        'address': 'Jl. Merdeka 10',
        'nama_wali': 'Pak Santoso',
        'nomor_hp': '08123456789',
        'id_siswa_kelas': 42,
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

    test('handles missing fields with defaults from fromJson', () {
      final json = {
        'id': 3,
        'name': 'Generic',
        'kelas_nama': '7A',
        'nomor_induk': 'S003',
        'address': '',
        'nama_wali': '',
        'nomor_hp': '',
      };

      final student = Student.fromJson(json);

      expect(student.id, '3');
      expect(student.name, 'Generic');
      expect(student.className, '7A');
    });

    test('handles null optional fields (classId, studentClassId)', () {
      final json = {
        'id': 4,
        'nama': 'Test',
        'nomor_induk': 'T004',
        'kelas_nama': 'TestClass',
        'address': 'TestAddr',
        'nama_wali': 'TestGuardian',
        'nomor_hp': '000',
        'id_kelas': null,
        'id_siswa_kelas': null,
      };

      final student = Student.fromJson(json);

      expect(student.classId, isNull);
      expect(student.studentClassId, isNull);
    });

    test('converts numeric id to string', () {
      final json = {
        'id': 123,
        'name': 'Name',
        'kelas_nama': 'Class',
        'student_number': 'Num',
        'address': 'Addr',
        'guardian_name': 'Guardian',
        'phone_number': 'Phone',
      };
      final student = Student.fromJson(json);
      expect(student.id, '123');
    });

    test('flat kelas_nama takes precedence over nested class.name', () {
      final json = {
        'id': 5,
        'name': 'Precedence',
        'kelas_nama': 'Flat7A',
        'class': {'name': 'Nested8B'},
        'nomor_induk': 'P005',
        'address': 'Addr',
        'nama_wali': 'Guardian',
        'nomor_hp': '000',
      };

      final student = Student.fromJson(json);
      expect(student.className, 'Flat7A');
    });
  });

  group('Student.toJson', () {
    test('produces correct snake_case keys (English)', () {
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
      expect(json['class_name'], '7A');
      expect(json['student_number'], 'S001');
      expect(json['address'], 'Jl. Merdeka');
      expect(json['guardian_name'], 'Pak Budi');
      expect(json['phone_number'], '0812345');
      expect(json['class_id'], '5');
      expect(json['student_class_id'], '42');
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
