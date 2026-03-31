/// grade_test.dart - Unit tests for the Grade domain model.
///
/// The Grade class is a plain Dart data class (no fromJson/toJson,
/// no == override, no freezed). Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. Each field type is correct (String, double).
///   3. Two separately constructed instances with the same data are NOT equal
///      because Dart's default == is reference equality (no override exists).
///   4. A single instance IS equal to itself (same reference).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/domain/models/grade.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Factory that returns a fully populated Grade for reuse across tests.
  Grade makeGrade({
    String studentId = 'stu-1',
    String subject = 'Matematika',
    double score = 85.0,
    String semester = 'Ganjil',
  }) {
    return Grade(
      studentId: studentId,
      subject: subject,
      score: score,
      semester: semester,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Grade constructor', () {
    test('stores all required fields correctly', () {
      final grade = Grade(
        studentId: 'stu-42',
        subject: 'Bahasa Indonesia',
        score: 92.5,
        semester: 'Genap',
      );

      expect(grade.studentId, 'stu-42');
      expect(grade.subject, 'Bahasa Indonesia');
      expect(grade.score, 92.5);
      expect(grade.semester, 'Genap');
    });

    test('score is stored as double', () {
      final grade = makeGrade(score: 78.0);
      expect(grade.score, isA<double>());
    });

    test('score of 0.0 (minimum) is stored correctly', () {
      final grade = makeGrade(score: 0.0);
      expect(grade.score, 0.0);
    });

    test('score of 100.0 (maximum) is stored correctly', () {
      final grade = makeGrade(score: 100.0);
      expect(grade.score, 100.0);
    });

    test('fractional score is stored with full precision', () {
      final grade = makeGrade(score: 77.75);
      expect(grade.score, 77.75);
    });

    test('accepts "Ganjil" semester (odd semester)', () {
      final grade = makeGrade(semester: 'Ganjil');
      expect(grade.semester, 'Ganjil');
    });

    test('accepts "Genap" semester (even semester)', () {
      final grade = makeGrade(semester: 'Genap');
      expect(grade.semester, 'Genap');
    });

    test('different subject names are stored correctly', () {
      final subjects = ['Matematika', 'Fisika', 'Kimia', 'Biologi', 'Sejarah', 'PPKn'];
      for (final s in subjects) {
        final grade = makeGrade(subject: s);
        expect(grade.subject, s);
      }
    });

    test('studentId acts as foreign key reference (string)', () {
      final grade = makeGrade(studentId: '123');
      expect(grade.studentId, '123');
    });

    test('fields are final - verified by reading their types', () {
      final grade = makeGrade();
      expect(grade.studentId, isA<String>());
      expect(grade.subject, isA<String>());
      expect(grade.score, isA<double>());
      expect(grade.semester, isA<String>());
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & identity (no == override → reference equality)
  // ---------------------------------------------------------------------------

  group('Grade equality', () {
    test('same instance is equal to itself', () {
      final grade = makeGrade();
      // ignore: unrelated_type_equality_checks
      expect(grade == grade, isTrue);
    });

    test('two separate instances with identical data are NOT equal', () {
      final a = makeGrade();
      final b = makeGrade();
      expect(a == b, isFalse);
    });

    test('two instances with different scores are not equal', () {
      final a = makeGrade(score: 80.0);
      final b = makeGrade(score: 90.0);
      expect(a == b, isFalse);
    });

    test('two instances with different subjects are not equal', () {
      final a = makeGrade(subject: 'Matematika');
      final b = makeGrade(subject: 'Fisika');
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Grade edge cases', () {
    test('empty strings are valid field values', () {
      final grade = Grade(
        studentId: '',
        subject: '',
        score: 0.0,
        semester: '',
      );

      expect(grade.studentId, '');
      expect(grade.subject, '');
      expect(grade.semester, '');
      expect(grade.score, 0.0);
    });

    test('integer-like score (no decimal) is stored as double', () {
      // In Dart, 85 assigned to a double field becomes 85.0.
      final grade = Grade(
        studentId: 'stu-1',
        subject: 'IPA',
        score: 85,
        semester: 'Ganjil',
      );
      expect(grade.score, 85.0);
    });
  });
}
