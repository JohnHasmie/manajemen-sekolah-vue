// Unit tests for TeacherScheduleController — covers pure helper methods
// that have no external side-effects (no API calls, no cache, no BuildContext).
//
// Like testing a Laravel Collection pipeline in isolation:
// each test exercises one deterministic input → output transformation.
//
// Controller is obtained via ProviderContainer so that the production
// DI wiring is exercised (the real class, not a stub).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';

void main() {
  late ProviderContainer container;
  late TeacherScheduleController ctrl;

  setUp(() {
    container = ProviderContainer();
    ctrl = container.read(teacherScheduleControllerProvider);
  });

  tearDown(() => container.dispose());

  // ---------------------------------------------------------------------------
  // getCurrentAcademicYear
  // ---------------------------------------------------------------------------

  group('getCurrentAcademicYear', () {
    test('returns string in YYYY/YYYY format', () {
      final result = ctrl.getCurrentAcademicYear();
      expect(result, matches(RegExp(r'^\d{4}/\d{4}$')));
    });

    test('the two years are consecutive', () {
      final result = ctrl.getCurrentAcademicYear();
      final parts = result.split('/');
      expect(int.parse(parts[1]) - int.parse(parts[0]), 1);
    });

    test('second year matches current year when running before July', () {
      final now = DateTime.now();
      final result = ctrl.getCurrentAcademicYear();
      final secondYear = int.parse(result.split('/')[1]);
      if (now.month < 7) {
        expect(secondYear, now.year);
      }
    });

    test('first year matches current year when running in or after July', () {
      final now = DateTime.now();
      final result = ctrl.getCurrentAcademicYear();
      final firstYear = int.parse(result.split('/')[0]);
      if (now.month >= 7) {
        expect(firstYear, now.year);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // buildScheduleCacheKey
  // ---------------------------------------------------------------------------

  group('buildScheduleCacheKey', () {
    const teacherId = 'T42';
    const semester = '1';
    const year = '2024/2025';

    test('returns regular teacher key when no filters are active', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, 'schedule_teacher_T42_1_2024/2025');
    });

    test('returns null when teacherId is empty', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: '',
        selectedDayIds: [],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, isNull);
    });

    test('returns null when day filter is active', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: ['3'],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, isNull);
    });

    test('returns null when class filter is active', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: 'CLS1',
        searchText: '',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, isNull);
    });

    test('returns null when search text is non-empty', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: null,
        searchText: 'math',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, isNull);
    });

    test('returns null when selectedFilterSemester differs from selectedSemester', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: '2',
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, isNull);
    });

    test('returns homeroom key when isHomeroomView with selected class', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: null,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: true,
        selectedHomeroomClass: {'id': 'CLS7A'},
      );
      expect(key, 'schedule_homeroom_CLS7A_1_2024/2025');
    });

    test('uses selectedFilterSemester in key when it matches selectedSemester', () {
      final key = ctrl.buildScheduleCacheKey(
        teacherId: teacherId,
        selectedDayIds: [],
        selectedClassId: null,
        searchText: '',
        selectedFilterSemester: semester,
        selectedSemester: semester,
        selectedAcademicYear: year,
        isHomeroomView: false,
        selectedHomeroomClass: null,
      );
      expect(key, 'schedule_teacher_T42_1_2024/2025');
    });
  });

  // ---------------------------------------------------------------------------
  // normalizeDayName
  // ---------------------------------------------------------------------------

  group('normalizeDayName', () {
    final cases = {
      'Monday': 'Senin',
      'monday': 'Senin',
      'SENIN': 'Senin',
      'Tuesday': 'Selasa',
      'tuesday': 'Selasa',
      'selasa': 'Selasa',
      'Wednesday': 'Rabu',
      'wednesday': 'Rabu',
      'rabu': 'Rabu',
      'Thursday': 'Kamis',
      'thursday': 'Kamis',
      'kamis': 'Kamis',
      'Friday': 'Jumat',
      'friday': 'Jumat',
      'jumat': 'Jumat',
      'Saturday': 'Sabtu',
      'saturday': 'Sabtu',
      'sabtu': 'Sabtu',
      'Sunday': 'Minggu',
      'sunday': 'Minggu',
      'minggu': 'Minggu',
    };

    for (final entry in cases.entries) {
      test('"${entry.key}" → "${entry.value}"', () {
        expect(ctrl.normalizeDayName(entry.key), entry.value);
      });
    }

    test('unknown input is returned in lowercase (trimmed)', () {
      expect(ctrl.normalizeDayName('  Holiday  '), 'holiday');
    });

    test('leading/trailing whitespace is stripped', () {
      expect(ctrl.normalizeDayName('  Monday  '), 'Senin');
    });
  });

  // ---------------------------------------------------------------------------
  // extractDayIds
  // ---------------------------------------------------------------------------

  group('extractDayIds', () {
    test('returns ids from a List<dynamic> days_ids field', () {
      final ids = ctrl.extractDayIds({'days_ids': ['1', '2', '3']});
      expect(ids, ['1', '2', '3']);
    });

    test('returns ids from an integer list (casts to String)', () {
      final ids = ctrl.extractDayIds({'days_ids': [1, 2]});
      expect(ids, ['1', '2']);
    });

    test('returns ids from a serialised array string "[1,2,3]"', () {
      final ids = ctrl.extractDayIds({'days_ids': '[1,2,3]'});
      expect(ids, ['1', '2', '3']);
    });

    test('handles spaces inside the serialised string', () {
      final ids = ctrl.extractDayIds({'days_ids': '[1, 2, 3]'});
      expect(ids, ['1', '2', '3']);
    });

    test('falls back to day_id when days_ids is absent', () {
      final ids = ctrl.extractDayIds({'day_id': '5'});
      expect(ids, ['5']);
    });

    test('falls back to hari_id when day_id is also absent', () {
      final ids = ctrl.extractDayIds({'hari_id': '6'});
      expect(ids, ['6']);
    });

    test('returns empty list when no day fields are present', () {
      final ids = ctrl.extractDayIds({'mata_pelajaran_nama': 'Math'});
      expect(ids, isEmpty);
    });

    test('returns empty list for empty days_ids list', () {
      final ids = ctrl.extractDayIds({'days_ids': []});
      expect(ids, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getFilteredSchedules
  // ---------------------------------------------------------------------------

  group('getFilteredSchedules', () {
    final dayIdMap = {'Senin': '1', 'Selasa': '2', 'Rabu': '3'};

    Map<String, dynamic> schedule({
      String subject = 'Math',
      String className = '7A',
      List<String> dayIds = const ['1'],
      String classId = 'C1',
    }) =>
        {
          'mata_pelajaran_nama': subject,
          'kelas_nama': className,
          'days_ids': dayIds,
          'class_id': classId,
        };

    test('returns all schedules when no filters are active', () {
      final list = [schedule(subject: 'Math'), schedule(subject: 'Science')];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: '',
        selectedDayIds: [],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(2));
    });

    test('empty schedule list returns empty result', () {
      final result = ctrl.getFilteredSchedules(
        scheduleList: [],
        searchText: '',
        selectedDayIds: [],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, isEmpty);
    });

    test('search filter matches mata_pelajaran_nama (case-insensitive)', () {
      final list = [schedule(subject: 'Mathematics'), schedule(subject: 'Physics')];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: 'math',
        selectedDayIds: [],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(1));
      expect(result.first['mata_pelajaran_nama'], 'Mathematics');
    });

    test('search filter matches kelas_nama (case-insensitive)', () {
      final list = [schedule(className: '7A'), schedule(className: '8B')];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: '8b',
        selectedDayIds: [],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(1));
      expect(result.first['kelas_nama'], '8B');
    });

    test('day filter keeps only schedules with matching day id', () {
      final list = [
        schedule(subject: 'Monday Subject', dayIds: ['1']),
        schedule(subject: 'Tuesday Subject', dayIds: ['2']),
      ];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: '',
        selectedDayIds: ['1'],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(1));
      expect(result.first['mata_pelajaran_nama'], 'Monday Subject');
    });

    test('class filter keeps only matching class_id', () {
      final list = [
        schedule(subject: 'Class A Subject', classId: 'CA'),
        schedule(subject: 'Class B Subject', classId: 'CB'),
      ];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: '',
        selectedDayIds: [],
        selectedClassId: 'CA',
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(1));
      expect(result.first['mata_pelajaran_nama'], 'Class A Subject');
    });

    test('combining search + day filter applies AND logic', () {
      final list = [
        schedule(subject: 'Monday Math', dayIds: ['1']),
        schedule(subject: 'Tuesday Math', dayIds: ['2']),
        schedule(subject: 'Monday Science', dayIds: ['1']),
      ];
      final result = ctrl.getFilteredSchedules(
        scheduleList: list,
        searchText: 'math',
        selectedDayIds: ['1'],
        selectedClassId: null,
        dayIdMap: dayIdMap,
      );
      expect(result, hasLength(1));
      expect(result.first['mata_pelajaran_nama'], 'Monday Math');
    });

    test('result is sorted without throwing even when dayIdMap is empty', () {
      final list = [schedule(), schedule(subject: 'Science')];
      expect(
        () => ctrl.getFilteredSchedules(
          scheduleList: list,
          searchText: '',
          selectedDayIds: [],
          selectedClassId: null,
          dayIdMap: {},
        ),
        returnsNormally,
      );
    });
  });
}
