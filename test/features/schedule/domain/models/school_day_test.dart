// Unit tests for SchoolDay — verifies fromJson handles the various API shapes
// the backend can return (English name in single `name` column).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/domain/models/school_day.dart';

void main() {
  group('SchoolDay.fromJson', () {
    test('parses standard API response', () {
      final day = SchoolDay.fromJson({'id': 1, 'name': 'Monday'});
      expect(day.id, '1');
      expect(day.name, 'Monday');
    });

    test('parses name-only response', () {
      final day = SchoolDay.fromJson({'id': '3', 'name': 'Wednesday'});
      expect(day.name, 'Wednesday');
    });

    test('handles null id gracefully', () {
      final day = SchoolDay.fromJson({'id': null, 'name': 'Monday'});
      expect(day.id, '');
    });

    test('handles completely empty map', () {
      final day = SchoolDay.fromJson({});
      expect(day.id, '');
      expect(day.name, '');
    });

    test('casts integer id to string', () {
      final day = SchoolDay.fromJson({'id': 42, 'name': 'Friday'});
      expect(day.id, '42');
    });
  });

  group('SchoolDay.toJson', () {
    test('round-trips through fromJson', () {
      final original = SchoolDay.fromJson({'id': '5', 'name': 'Friday'});
      final json = original.toJson();
      final restored = SchoolDay.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
    });
  });
}
