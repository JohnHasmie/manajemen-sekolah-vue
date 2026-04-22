// Unit tests for GradeConstants — verifies the single source of truth for
// grade type keys, labels, and default filter state.
//
// Like testing a Laravel config/grades.php to ensure all expected keys exist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/constants/grade_constants.dart';

void main() {
  group('GradeConstants.allTypes', () {
    test('contains all six expected grade types', () {
      expect(
        GradeConstants.allTypes,
        containsAll(['uh', 'tugas', 'uts', 'uas', 'pts', 'pas']),
      );
    });

    test('has exactly six types', () {
      expect(GradeConstants.allTypes, hasLength(6));
    });

    test('is in the canonical order', () {
      expect(GradeConstants.allTypes, [
        'uh',
        'tugas',
        'uts',
        'uas',
        'pts',
        'pas',
      ]);
    });
  });

  group('GradeConstants.defaultFilter', () {
    test('contains a key for every type in allTypes', () {
      final filter = GradeConstants.defaultFilter;
      for (final type in GradeConstants.allTypes) {
        expect(filter.containsKey(type), isTrue, reason: 'missing key: $type');
      }
    });

    test('all values are true', () {
      final filter = GradeConstants.defaultFilter;
      expect(filter.values.every((v) => v), isTrue);
    });

    test('returns a new mutable map each call — mutations do not persist', () {
      final first = GradeConstants.defaultFilter;
      first['uh'] = false;
      final second = GradeConstants.defaultFilter;
      expect(second['uh'], isTrue);
    });
  });

  group('GradeConstants.labelsEn', () {
    test('has a label for every type in allTypes', () {
      for (final type in GradeConstants.allTypes) {
        expect(
          GradeConstants.labelsEn.containsKey(type),
          isTrue,
          reason: 'missing EN label: $type',
        );
      }
    });

    test('labels are non-empty strings', () {
      for (final label in GradeConstants.labelsEn.values) {
        expect(label, isNotEmpty);
      }
    });
  });

  group('GradeConstants.labelsId', () {
    test('has a label for every type in allTypes', () {
      for (final type in GradeConstants.allTypes) {
        expect(
          GradeConstants.labelsId.containsKey(type),
          isTrue,
          reason: 'missing ID label: $type',
        );
      }
    });

    test('labels are non-empty strings', () {
      for (final label in GradeConstants.labelsId.values) {
        expect(label, isNotEmpty);
      }
    });

    test('Indonesian and English labels are not identical', () {
      for (final type in GradeConstants.allTypes) {
        // Most labels should differ between languages
        // (uts/uas/pts/pas happen to be same acronym — skip those)
        if (['uh', 'tugas'].contains(type)) {
          expect(
            GradeConstants.labelsId[type],
            isNot(equals(GradeConstants.labelsEn[type])),
            reason: 'EN and ID label unexpectedly identical for: $type',
          );
        }
      }
    });
  });
}
