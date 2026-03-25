/// Tests for PreferencesService — wrapper around SharedPreferences.
///
/// Uses SharedPreferences.setMockInitialValues({}) to avoid needing
/// a real platform channel. This is similar to how you'd mock Redis
/// or config in Laravel tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';

void main() {
  late PreferencesService service;

  setUp(() async {
    // Initialize the mock SharedPreferences with an empty state.
    SharedPreferences.setMockInitialValues({});
    service = PreferencesService();
    await service.init();
  });

  group('String operations', () {
    test('getString returns null for missing key', () {
      expect(service.getString('nonexistent'), isNull);
    });

    test('setString then getString round-trip', () async {
      await service.setString('lang', 'id');
      expect(service.getString('lang'), 'id');
    });

    test('setString overwrites previous value', () async {
      await service.setString('lang', 'id');
      await service.setString('lang', 'en');
      expect(service.getString('lang'), 'en');
    });
  });

  group('Bool operations', () {
    test('getBool returns null for missing key', () {
      expect(service.getBool('nonexistent'), isNull);
    });

    test('setBool then getBool round-trip', () async {
      await service.setBool('tour_seen', true);
      expect(service.getBool('tour_seen'), isTrue);
    });

    test('setBool false', () async {
      await service.setBool('dark_mode', false);
      expect(service.getBool('dark_mode'), isFalse);
    });
  });

  group('Int operations', () {
    test('getInt returns null for missing key', () {
      expect(service.getInt('nonexistent'), isNull);
    });

    test('setInt then getInt round-trip', () async {
      await service.setInt('page_size', 25);
      expect(service.getInt('page_size'), 25);
    });
  });

  group('JSON operations', () {
    test('getJson returns null for missing key', () {
      expect(service.getJson('nonexistent'), isNull);
    });

    test('setJson then getJson round-trip', () async {
      final data = {'name': 'Budi', 'age': 15};
      await service.setJson('cached_student', data);

      final result = service.getJson('cached_student');
      expect(result, isNotNull);
      expect(result!['name'], 'Budi');
      expect(result['age'], 15);
    });

    test('getJson returns null for empty string', () async {
      await service.setString('bad_json', '');
      expect(service.getJson('bad_json'), isNull);
    });

    test('getJson returns null for invalid JSON', () async {
      await service.setString('bad_json', 'not-valid-json{{{');
      expect(service.getJson('bad_json'), isNull);
    });
  });

  group('Remove / ContainsKey', () {
    test('remove deletes a key', () async {
      await service.setString('temp', 'value');
      expect(service.containsKey('temp'), isTrue);

      await service.remove('temp');
      expect(service.containsKey('temp'), isFalse);
      expect(service.getString('temp'), isNull);
    });

    test('containsKey returns false for nonexistent key', () {
      expect(service.containsKey('ghost'), isFalse);
    });

    test('containsKey returns true for existing key', () async {
      await service.setString('exists', 'yes');
      expect(service.containsKey('exists'), isTrue);
    });
  });

  group('Clear', () {
    test('clear removes all keys', () async {
      await service.setString('a', '1');
      await service.setBool('b', true);
      await service.setInt('c', 3);

      await service.clear();

      expect(service.getString('a'), isNull);
      expect(service.getBool('b'), isNull);
      expect(service.getInt('c'), isNull);
    });
  });

  group('prefs getter', () {
    test('returns the underlying SharedPreferences instance', () {
      final prefs = service.prefs;
      expect(prefs, isA<SharedPreferences>());
    });
  });
}
