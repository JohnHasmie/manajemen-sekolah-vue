// Unit tests for SchoolDay — verifies fromJson handles the various API shapes
// the backend can return (name_id vs name, int vs string id, missing fields).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/domain/models/school_day.dart';

void main() {
  group('SchoolDay.fromJson', () {
    test('parses standard API response', () {
      final day = SchoolDay.fromJson({'id': 1, 'name': 'Monday', 'name_id': 'Senin'});
      expect(day.id, '1');
      expect(day.name, 'Monday');
      expect(day.nameId, 'Senin');
    });

    test('falls back to name when name_id is missing', () {
      final day = SchoolDay.fromJson({'id': '3', 'name': 'Wednesday'});
      expect(day.nameId, 'Wednesday');
    });

    test('handles null id gracefully', () {
      final day = SchoolDay.fromJson({'id': null, 'name': 'Senin'});
      expect(day.id, '');
    });

    test('handles completely empty map', () {
      final day = SchoolDay.fromJson({});
      expect(day.id, '');
      expect(day.name, '');
      expect(day.nameId, '');
    });

    test('casts integer id to string', () {
      final day = SchoolDay.fromJson({'id': 42, 'name': 'Jumat', 'name_id': 'Jumat'});
      expect(day.id, '42');
    });
  });

  group('SchoolDay.toJson', () {
    test('round-trips through fromJson', () {
      final original = SchoolDay.fromJson({'id': '5', 'name': 'Friday', 'name_id': 'Jumat'});
      final json = original.toJson();
      final restored = SchoolDay.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.nameId, original.nameId);
    });
  });
}
