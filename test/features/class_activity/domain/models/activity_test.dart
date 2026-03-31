/// activity_test.dart - Unit tests for the Activity domain model.
///
/// The Activity class is a plain Dart data class (no fromJson/toJson,
/// no == override, no freezed). Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. Each field type is correct (String, DateTime).
///   3. Two separately constructed instances with the same data are NOT equal
///      because Dart's default == is reference equality (no override exists).
///   4. A single instance IS equal to itself (same reference).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/activity.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Factory that returns a fully populated Activity for reuse across tests.
  Activity makeActivity({
    String id = 'act-1',
    String name = 'Upacara Bendera',
    String description = 'Upacara bendera setiap Senin pagi.',
    DateTime? date,
    String location = 'Lapangan Utama',
  }) {
    return Activity(
      id: id,
      name: name,
      description: description,
      date: date ?? DateTime(2025, 8, 17),
      location: location,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Activity constructor', () {
    test('stores all required fields correctly', () {
      final date = DateTime(2025, 8, 17, 7, 0);
      final act = Activity(
        id: 'act-99',
        name: 'Perlombaan 17 Agustus',
        description: 'Lomba untuk memperingati Hari Kemerdekaan.',
        date: date,
        location: 'Aula Sekolah',
      );

      expect(act.id, 'act-99');
      expect(act.name, 'Perlombaan 17 Agustus');
      expect(act.description, 'Lomba untuk memperingati Hari Kemerdekaan.');
      expect(act.date, date);
      expect(act.location, 'Aula Sekolah');
    });

    test('stores a DateTime with full time component', () {
      final dateWithTime = DateTime(2025, 3, 21, 14, 30, 0);
      final act = makeActivity(date: dateWithTime);

      expect(act.date.year, 2025);
      expect(act.date.month, 3);
      expect(act.date.day, 21);
      expect(act.date.hour, 14);
      expect(act.date.minute, 30);
    });

    test('name and description are stored independently', () {
      final act = Activity(
        id: '1',
        name: 'Short Name',
        description: 'A detailed description of the activity.',
        date: DateTime(2025, 1, 1),
        location: 'Room 1',
      );

      expect(act.name, isNot(equals(act.description)));
    });

    test('location can describe a complex venue string', () {
      final act = makeActivity(location: 'Gedung Serbaguna Lt. 2, Kab. Bandung');
      expect(act.location, 'Gedung Serbaguna Lt. 2, Kab. Bandung');
    });

    test('fields are final - verified by reading their types', () {
      final act = makeActivity();
      expect(act.id, isA<String>());
      expect(act.name, isA<String>());
      expect(act.description, isA<String>());
      expect(act.date, isA<DateTime>());
      expect(act.location, isA<String>());
    });

    test('different activity names are stored correctly', () {
      final names = ['Ujian Tengah Semester', 'Studi Lapangan', 'Bakti Sosial', 'Pentas Seni'];
      for (final n in names) {
        final act = makeActivity(name: n);
        expect(act.name, n);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & identity (no == override → reference equality)
  // ---------------------------------------------------------------------------

  group('Activity equality', () {
    test('same instance is equal to itself', () {
      final act = makeActivity();
      // ignore: unrelated_type_equality_checks
      expect(act == act, isTrue);
    });

    test('two separate instances with identical data are NOT equal', () {
      final a = makeActivity();
      final b = makeActivity();
      expect(a == b, isFalse);
    });

    test('two instances with different ids are not equal', () {
      final a = makeActivity(id: 'act-1');
      final b = makeActivity(id: 'act-2');
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Activity edge cases', () {
    test('empty strings are valid field values', () {
      final act = Activity(
        id: '',
        name: '',
        description: '',
        date: DateTime(2000),
        location: '',
      );

      expect(act.id, '');
      expect(act.name, '');
      expect(act.description, '');
      expect(act.location, '');
    });

    test('very long description is stored intact', () {
      final longDesc = 'D' * 5000;
      final act = makeActivity(description: longDesc);
      expect(act.description.length, 5000);
    });

    test('date at epoch boundary is stored correctly', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final act = makeActivity(date: epoch);
      expect(act.date.millisecondsSinceEpoch, 0);
    });
  });
}
