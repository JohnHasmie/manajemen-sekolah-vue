/// announcement_test.dart - Unit tests for the Announcement Freezed model.
///
/// The Announcement class is a @freezed data class with [_standardizeJson]
/// that normalizes Indonesian ↔ English keys and heterogeneous `is_read`
/// values. Tests verify:
///   1. All fields are stored and accessible after construction.
///   2. fromJson normalizes Indonesian keys correctly.
///   3. Two instances with the same data ARE equal (Freezed == override).
///   4. is_read normalization works for bool, int, String, and null.
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
    String category = 'Akademik',
    String? createdAt,
    bool isRead = true,
  }) {
    return Announcement(
      id: id,
      title: title,
      content: content,
      category: category,
      createdAt: createdAt ?? '2025-04-10',
      isRead: isRead,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor & field access
  // ---------------------------------------------------------------------------

  group('Announcement constructor', () {
    test('stores all required fields correctly', () {
      final ann = Announcement(
        id: 'ann-42',
        title: 'Pengumuman Ujian',
        content: 'Ujian nasional dilaksanakan bulan Mei.',
        category: 'Akademik',
        createdAt: '2025-05-01',
        isRead: false,
      );

      expect(ann.id, 'ann-42');
      expect(ann.title, 'Pengumuman Ujian');
      expect(ann.content, 'Ujian nasional dilaksanakan bulan Mei.');
      expect(ann.category, 'Akademik');
      expect(ann.createdAt, '2025-05-01');
      expect(ann.isRead, false);
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

    test('isRead defaults to true', () {
      const ann = Announcement(
        id: '1',
        title: 'Test',
        content: 'Body',
        category: 'Umum',
      );
      expect(ann.isRead, true);
    });
  });

  // ---------------------------------------------------------------------------
  // fromJson / _standardizeJson
  // ---------------------------------------------------------------------------

  group('Announcement.fromJson', () {
    test('parses English keys', () {
      final ann = Announcement.fromJson({
        'id': 'ann-1',
        'title': 'Title',
        'content': 'Content body',
        'category': 'Akademik',
        'created_at': '2025-04-10',
        'is_read': false,
      });

      expect(ann.id, 'ann-1');
      expect(ann.title, 'Title');
      expect(ann.content, 'Content body');
      expect(ann.category, 'Akademik');
      expect(ann.createdAt, '2025-04-10');
      expect(ann.isRead, false);
    });

    test('normalizes Indonesian keys', () {
      final ann = Announcement.fromJson({
        'id': 2,
        'judul': 'Judul Indo',
        'isi': 'Isi pengumuman',
        'kategori': 'Keuangan',
        'tanggal': '2025-06-01',
      });

      expect(ann.id, '2');
      expect(ann.title, 'Judul Indo');
      expect(ann.content, 'Isi pengumuman');
      expect(ann.category, 'Keuangan');
      expect(ann.createdAt, '2025-06-01');
    });

    test('normalizes is_read from int 1', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
        'is_read': 1,
      });
      expect(ann.isRead, true);
    });

    test('normalizes is_read from int 0', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
        'is_read': 0,
      });
      expect(ann.isRead, false);
    });

    test('normalizes is_read from string "1"', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
        'is_read': '1',
      });
      expect(ann.isRead, true);
    });

    test('normalizes is_read from null to true (default)', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
      });
      expect(ann.isRead, true);
    });

    test('coerces numeric id to string', () {
      final ann = Announcement.fromJson({
        'id': 42,
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
      });
      expect(ann.id, '42');
    });

    test('handles missing optional fields gracefully', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'content': 'C',
        'category': 'Umum',
      });
      expect(ann.createdAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Equality (Freezed == override)
  // ---------------------------------------------------------------------------

  group('Announcement equality', () {
    test('same instance is equal to itself', () {
      final ann = makeAnnouncement();
      expect(ann == ann, isTrue);
    });

    test('two separate instances with identical data ARE equal (Freezed)', () {
      final a = makeAnnouncement();
      final b = makeAnnouncement();
      expect(a == b, isTrue);
    });

    test('two instances with different ids are not equal', () {
      final a = makeAnnouncement(id: 'ann-1');
      final b = makeAnnouncement(id: 'ann-2');
      expect(a == b, isFalse);
    });

    test('two instances with different isRead are not equal', () {
      final a = makeAnnouncement(isRead: true);
      final b = makeAnnouncement(isRead: false);
      expect(a == b, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('Announcement edge cases', () {
    test('empty strings are valid field values', () {
      const ann = Announcement(
        id: '',
        title: '',
        content: '',
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

    test('fromJson with konten key works', () {
      final ann = Announcement.fromJson({
        'id': '1',
        'title': 'T',
        'konten': 'Konten alternatif',
        'category': 'Umum',
      });
      expect(ann.content, 'Konten alternatif');
    });
  });
}
