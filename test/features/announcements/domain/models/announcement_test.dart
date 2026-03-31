/// announcement_test.dart - Unit tests for the Announcement domain model.
///
/// The Announcement class is a plain Dart data class (no fromJson/toJson,
/// no == override, no freezed). Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. Each field type is correct (String, DateTime).
///   3. Two separately constructed instances with the same data are NOT equal
///      because Dart's default == is reference equality (no override exists).
///   4. A single instance IS equal to itself (same reference).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Factory that returns a fully populated Announcement for reuse across tests.
  Announcement makeAnnouncement({
    String id = 'ann-1',
    String title = 'Libur Lebaran',
    String content = 'Sekolah libur mulai tanggal 10 April.',
    DateTime? date,
    String category = 'Akademik',
  }) {
    return Announcement(
      id: id,
      title: title,
      content: content,
      date: date ?? DateTime(2025, 4, 10),
      category: category,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Announcement constructor', () {
    test('stores all required fields correctly', () {
      final date = DateTime(2025, 4, 10);
      final ann = Announcement(
        id: 'ann-42',
        title: 'Pengumuman Ujian',
        content: 'Ujian nasional dilaksanakan bulan Mei.',
        date: date,
        category: 'Akademik',
      );

      expect(ann.id, 'ann-42');
      expect(ann.title, 'Pengumuman Ujian');
      expect(ann.content, 'Ujian nasional dilaksanakan bulan Mei.');
      expect(ann.date, date);
      expect(ann.category, 'Akademik');
    });

    test('accepts any non-empty string as id', () {
      final ann = makeAnnouncement(id: 'unique-999');
      expect(ann.id, 'unique-999');
    });

    test('accepts different category values', () {
      final categories = ['Akademik', 'Keuangan', 'Kegiatan', 'Umum'];
      for (final cat in categories) {
        final ann = makeAnnouncement(category: cat);
        expect(ann.category, cat);
      }
    });

    test('stores a DateTime with time component', () {
      final dateWithTime = DateTime(2025, 6, 15, 8, 30, 0);
      final ann = makeAnnouncement(date: dateWithTime);

      expect(ann.date.year, 2025);
      expect(ann.date.month, 6);
      expect(ann.date.day, 15);
      expect(ann.date.hour, 8);
      expect(ann.date.minute, 30);
    });

    test('title and content are stored independently', () {
      final ann = Announcement(
        id: '1',
        title: 'Short Title',
        content: 'A much longer content body that describes the announcement in detail.',
        date: DateTime(2025, 1, 1),
        category: 'Umum',
      );

      expect(ann.title, isNot(equals(ann.content)));
    });

    test('fields are final (read-only) - verified by accessing them', () {
      final ann = makeAnnouncement();
      // Just accessing all fields verifies they are readable; the compiler
      // prevents assignment because they are declared final.
      expect(ann.id, isA<String>());
      expect(ann.title, isA<String>());
      expect(ann.content, isA<String>());
      expect(ann.date, isA<DateTime>());
      expect(ann.category, isA<String>());
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & identity (no == override → reference equality)
  // ---------------------------------------------------------------------------

  group('Announcement equality', () {
    test('same instance is equal to itself', () {
      final ann = makeAnnouncement();
      // ignore: unrelated_type_equality_checks
      expect(ann == ann, isTrue);
    });

    test('two separate instances with identical data are NOT equal', () {
      // Because Announcement does not override ==, Dart uses reference equality.
      // This is expected behaviour for a plain data class without overrides.
      final a = makeAnnouncement();
      final b = makeAnnouncement();
      expect(a == b, isFalse);
    });

    test('two instances with different ids are not equal', () {
      final a = makeAnnouncement(id: 'ann-1');
      final b = makeAnnouncement(id: 'ann-2');
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Announcement edge cases', () {
    test('empty strings are valid field values', () {
      final ann = Announcement(
        id: '',
        title: '',
        content: '',
        date: DateTime(2000),
        category: '',
      );

      expect(ann.id, '');
      expect(ann.title, '');
      expect(ann.content, '');
      expect(ann.category, '');
    });

    test('very long content string is stored intact', () {
      final longContent = 'X' * 10000;
      final ann = makeAnnouncement(content: longContent);
      expect(ann.content.length, 10000);
    });

    test('date at epoch boundary is stored correctly', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final ann = makeAnnouncement(date: epoch);
      expect(ann.date.millisecondsSinceEpoch, 0);
    });
  });
}
