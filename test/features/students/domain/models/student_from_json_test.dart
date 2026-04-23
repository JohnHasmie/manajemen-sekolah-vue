// CRUD data tests for Student.fromJson + _standardizeJson.
//
// The _standardizeJson method normalises multiple API response shapes
// (Indonesian keys, nested objects, numeric IDs) into a consistent map
// before Freezed's generated code parses it.
//
// These tests verify that every documented normalisation path works correctly,
// like testing a Laravel Accessor or a Vue computed prop for data transformation.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Name normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — name field', () {
    test('reads "name" key directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'Budi Santoso',
        'class_name': 'VII-A',
        'student_number': '001',
        'address': 'Jl. A',
        'guardian_name': 'Pak Budi',
        'phone_number': '0812',
      });
      expect(s.name, 'Budi Santoso');
    });

    test('falls back to "nama" when "name" is absent', () {
      final s = Student.fromJson({
        'id': '2',
        'nama': 'Siti Rahayu',
        'class_name': 'VIII-B',
        'student_number': '002',
        'address': 'Jl. B',
        'guardian_name': 'Ibu Siti',
        'phone_number': '0813',
      });
      expect(s.name, 'Siti Rahayu');
    });

    test(
      'defaults to empty string when both "name" and "nama" are missing',
      () {
        final s = Student.fromJson({
          'id': '3',
          'class_name': 'VII-A',
          'student_number': '003',
          'address': '-',
          'guardian_name': '-',
          'phone_number': '-',
        });
        expect(s.name, '');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // className normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — className field', () {
    test('reads "class_name" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'IX-C',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.className, 'IX-C');
    });

    test('falls back to "kelas_nama"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'kelas_nama': 'VIII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.className, 'VIII-A');
    });

    test('reads from nested class.name map', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class': {'id': 'c1', 'name': 'VII-B'},
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.className, 'VII-B');
    });

    test('"class_name" takes priority over "kelas_nama"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'IX-A',
        'kelas_nama': 'IX-B',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.className, 'IX-A');
    });

    test('defaults to empty string when all class name keys are absent', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.className, '');
    });
  });

  // ---------------------------------------------------------------------------
  // studentNumber normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — studentNumber field', () {
    test('reads "student_number" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '20240001',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.studentNumber, '20240001');
    });

    test('falls back to "nomor_induk"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'nomor_induk': '20240002',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.studentNumber, '20240002');
    });

    test('converts numeric nomor_induk to string', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'nomor_induk': 12345,
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.studentNumber, '12345');
    });
  });

  // ---------------------------------------------------------------------------
  // address normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — address field', () {
    test('reads "address" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': 'Jl. Merdeka No. 10',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.address, 'Jl. Merdeka No. 10');
    });

    test('falls back to "alamat" key', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'alamat': 'Jl. Proklamasi No. 5',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.address, 'Jl. Proklamasi No. 5');
    });
  });

  // ---------------------------------------------------------------------------
  // guardianName normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — guardianName field', () {
    test('reads "guardian_name" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': 'Pak Ahmad',
        'phone_number': '-',
      });
      expect(s.guardianName, 'Pak Ahmad');
    });

    test('falls back to "nama_wali"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'nama_wali': 'Ibu Dewi',
        'phone_number': '-',
      });
      expect(s.guardianName, 'Ibu Dewi');
    });
  });

  // ---------------------------------------------------------------------------
  // phoneNumber normalisation
  // ---------------------------------------------------------------------------
  group('Student.fromJson — phoneNumber field', () {
    test('reads "phone_number" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '0812345678',
      });
      expect(s.phoneNumber, '0812345678');
    });

    test('falls back to "nomor_hp"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'nomor_hp': '087654321',
      });
      expect(s.phoneNumber, '087654321');
    });
  });

  // ---------------------------------------------------------------------------
  // Optional ID fields
  // ---------------------------------------------------------------------------
  group('Student.fromJson — optional classId / studentClassId', () {
    test('reads "class_id" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
        'class_id': 'c-42',
      });
      expect(s.classId, 'c-42');
    });

    test('falls back to "id_kelas" for classId', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
        'id_kelas': 'c-99',
      });
      expect(s.classId, 'c-99');
    });

    test('converts numeric classId to string', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
        'class_id': 7,
      });
      expect(s.classId, '7');
    });

    test('classId is null when absent', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.classId, isNull);
    });

    test('reads "student_class_id" directly', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
        'student_class_id': 'sc-5',
      });
      expect(s.studentClassId, 'sc-5');
    });

    test('falls back to "id_siswa_kelas"', () {
      final s = Student.fromJson({
        'id': '1',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
        'id_siswa_kelas': 'sc-88',
      });
      expect(s.studentClassId, 'sc-88');
    });
  });

  // ---------------------------------------------------------------------------
  // ID type coercion
  // ---------------------------------------------------------------------------
  group('Student.fromJson — id type coercion', () {
    test('numeric id is coerced to String', () {
      final s = Student.fromJson({
        'id': 42,
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.id, '42');
    });

    test('string id is kept as-is', () {
      final s = Student.fromJson({
        'id': 'stu-001',
        'name': 'A',
        'class_name': 'VII-A',
        'student_number': '1',
        'address': '-',
        'guardian_name': '-',
        'phone_number': '-',
      });
      expect(s.id, 'stu-001');
    });
  });
}
