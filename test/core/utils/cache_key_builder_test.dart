/// Tests for CacheKeyBuilder — verifies all cache key methods produce
/// the expected string format.
///
/// Like testing Laravel's cache key conventions to ensure
/// `Cache::remember("user_{$id}_profile", ...)` builds the right key.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';

void main() {
  group('CacheKeyBuilder - Teacher keys', () {
    test('teacherClasses builds correct key', () {
      expect(
        CacheKeyBuilder.teacherClasses('t1', 'y1'),
        'teacher_classes_t1_y1',
      );
    });

    test('teacherClasses with different IDs', () {
      expect(
        CacheKeyBuilder.teacherClasses('teacher-abc', 'year-2024'),
        'teacher_classes_teacher-abc_year-2024',
      );
    });

    test('teacherProfile builds correct key', () {
      expect(CacheKeyBuilder.teacherProfile('u1'), 'teacher_profile_u1');
    });

    test('teacherList builds correct key with query', () {
      expect(
        CacheKeyBuilder.teacherList('s1', 'math'),
        'teacher_list_s1_math',
      );
    });

    test('teacherList builds correct key without query', () {
      expect(CacheKeyBuilder.teacherList('s1'), 'teacher_list_s1_all');
    });
  });

  group('CacheKeyBuilder - Student keys', () {
    test('studentList builds correct key with query', () {
      expect(
        CacheKeyBuilder.studentList('s1', 'budi'),
        'student_list_s1_budi',
      );
    });

    test('studentList builds correct key without query', () {
      expect(CacheKeyBuilder.studentList('s1'), 'student_list_s1_all');
    });

    test('studentsByClass builds correct key', () {
      expect(CacheKeyBuilder.studentsByClass('c1'), 'students_class_c1');
    });
  });

  group('CacheKeyBuilder - Class keys', () {
    test('classList builds correct key with query', () {
      expect(CacheKeyBuilder.classList('s1', '7A'), 'class_list_s1_7A');
    });

    test('classList builds correct key without query', () {
      expect(CacheKeyBuilder.classList('s1'), 'class_list_s1_all');
    });
  });

  group('CacheKeyBuilder - Subject keys', () {
    test('subjectList builds correct key with query', () {
      expect(
        CacheKeyBuilder.subjectList('s1', 'IPA'),
        'subject_list_s1_IPA',
      );
    });

    test('subjectList builds correct key without query', () {
      expect(CacheKeyBuilder.subjectList('s1'), 'subject_list_s1_all');
    });

    test('subjectFilters builds correct key', () {
      expect(CacheKeyBuilder.subjectFilters('s1'), 'subject_filters_s1');
    });
  });

  group('CacheKeyBuilder - Schedule keys', () {
    test('scheduleList builds correct key with query', () {
      expect(
        CacheKeyBuilder.scheduleList('s1', 'monday'),
        'schedule_list_s1_monday',
      );
    });

    test('scheduleList builds correct key without query', () {
      expect(CacheKeyBuilder.scheduleList('s1'), 'schedule_list_s1_all');
    });

    test('dailySchedule builds correct key', () {
      expect(
        CacheKeyBuilder.dailySchedule('t1', 'mon', 'y1'),
        'daily_schedule_t1_mon_y1',
      );
    });
  });

  group('CacheKeyBuilder - Attendance keys', () {
    test('attendanceList builds correct key', () {
      expect(
        CacheKeyBuilder.attendanceList('c1', 'sub1', '2024-01-15'),
        'attendance_c1_sub1_2024-01-15',
      );
    });
  });

  group('CacheKeyBuilder - Grade keys', () {
    test('gradeClasses builds correct key', () {
      expect(
        CacheKeyBuilder.gradeClasses('t1', 'y1'),
        'grade_classes_t1_y1',
      );
    });
  });

  group('CacheKeyBuilder - Tour keys', () {
    test('tourStatus builds correct key', () {
      expect(
        CacheKeyBuilder.tourStatus('screen', 'admin'),
        'tour_screen_admin',
      );
    });

    test('tourStatus with different values', () {
      expect(
        CacheKeyBuilder.tourStatus('dashboard', 'guru'),
        'tour_dashboard_guru',
      );
    });
  });

  group('CacheKeyBuilder - Announcement keys', () {
    test('announcementFilters builds correct key', () {
      expect(
        CacheKeyBuilder.announcementFilters('s1'),
        'announcement_filters_s1',
      );
    });
  });

  group('CacheKeyBuilder - Finance keys', () {
    test('financeData builds correct key', () {
      expect(
        CacheKeyBuilder.financeData('s1', 'y1'),
        'finance_s1_y1',
      );
    });
  });

  group('CacheKeyBuilder - Generic custom keys', () {
    test('custom with scope builds three-part key', () {
      expect(
        CacheKeyBuilder.custom('feature', 'context', 'scope'),
        'feature_context_scope',
      );
    });

    test('custom without scope builds two-part key', () {
      expect(
        CacheKeyBuilder.custom('feature', 'context'),
        'feature_context',
      );
    });

    test('custom with null scope builds two-part key', () {
      expect(
        CacheKeyBuilder.custom('report', 'monthly', null),
        'report_monthly',
      );
    });

    test('custom with empty string scope includes it', () {
      // scope is not null, so it's included even if empty
      expect(
        CacheKeyBuilder.custom('feature', 'context', ''),
        'feature_context_',
      );
    });
  });
}
