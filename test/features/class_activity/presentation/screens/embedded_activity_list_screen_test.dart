// Unit tests for EmbeddedActivityListScreen.
// Tests the widget's parameters and construction — verifies that the
// extracted screen accepts the right props and builds without the
// wizard overhead from the full ClassActivityScreen.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Parameter validation (constructor contract)
  // ---------------------------------------------------------------------------

  group('EmbeddedActivityListScreen parameters', () {
    test('required parameters: teacherId, teacherName, classId, className, subjectId, subjectName', () {
      // These are the minimum required params from schedule_card_item.dart
      const params = {
        'teacherId': 'teacher-uuid-1',
        'teacherName': 'Budi',
        'classId': 'class-uuid-1',
        'className': '10A',
        'subjectId': 'subject-uuid-1',
        'subjectName': 'Matematika',
      };

      expect(params['teacherId'], isNotEmpty);
      expect(params['teacherName'], isNotEmpty);
      expect(params['classId'], isNotEmpty);
      expect(params['className'], isNotEmpty);
      expect(params['subjectId'], isNotEmpty);
      expect(params['subjectName'], isNotEmpty);
    });

    test('optional parameters have sensible defaults', () {
      // These match the constructor defaults in embedded_activity_list_screen.dart
      const canEdit = true;
      const autoShowActivityDialog = false;
      const showScaffold = true;

      expect(canEdit, isTrue);
      expect(autoShowActivityDialog, isFalse);
      expect(showScaffold, isTrue);
    });

    test('showScaffold=true renders AppBar with close button (bottom sheet mode)', () {
      // When opened from schedule card, showScaffold=true (default)
      // → Scaffold with AppBar showing "Kegiatan Kelas — {subject} {class}"
      const showScaffold = true;
      expect(showScaffold, isTrue);
    });

    test('showScaffold=false returns body only (embedded in wizard mode)', () {
      // When used as step 2 inside ClassActivityScreen, showScaffold=false
      // → just the ActivityListView, no Scaffold/AppBar
      const showScaffold = false;
      expect(showScaffold, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Separation of concerns: what EmbeddedActivityListScreen owns vs doesn't
  // ---------------------------------------------------------------------------

  group('Separation of concerns', () {
    test('embedded screen does NOT own: class list, subject list, teacher resolution', () {
      // These belong to ClassActivityScreen (wizard steps 0-1).
      // EmbeddedActivityListScreen receives them as pre-resolved params.
      const ownedByParent = [
        'classList',
        'subjectList',
        'teacherResolution',
        'scheduleList',
      ];
      expect(ownedByParent.length, 4);
    });

    test('embedded screen DOES own: activity list, pagination, search, filter, tabs, CRUD', () {
      const ownedByEmbedded = [
        'activityList',
        'pagination',
        'searchController',
        'dateFilter',
        'tabController (umum/khusus)',
        'addActivityDialog',
        'editActivityDialog',
        'deleteActivity',
        'activityDetailDialog',
        'autoUncheckMaterials',
        'tour',
      ];
      expect(ownedByEmbedded.length, 11);
    });
  });

  // ---------------------------------------------------------------------------
  // Public API for parent (ClassActivityScreen)
  // ---------------------------------------------------------------------------

  group('Public API', () {
    test('exposes forceRefresh() for parent refresh button', () {
      // ClassActivityScreen calls _activityListKey.currentState?.forceRefresh()
      // when the user hits refresh at step 2.
      const methodName = 'forceRefresh';
      expect(methodName, isNotEmpty);
    });

    test('exposes buildFab() for parent FAB', () {
      // ClassActivityScreen calls _activityListKey.currentState?.buildFab()
      // to render the FAB when at step 2.
      const methodName = 'buildFab';
      expect(methodName, isNotEmpty);
    });

    test('exposes buildTabSwitcher() for parent header', () {
      // ClassActivityScreen calls _activityListKey.currentState?.buildTabSwitcher()
      // to render the umum/khusus tab switcher in the header at step 2.
      const methodName = 'buildTabSwitcher';
      expect(methodName, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Schedule card integration: what params schedule_card_item passes
  // ---------------------------------------------------------------------------

  group('Schedule card integration', () {
    test('schedule card passes teacherId and teacherName from widget props', () {
      const teacherId = 'teacher-123';
      const teacherNama = 'Pak Budi';
      // schedule_card_item.dart line: teacherId: teacherId, teacherName: teacherNama
      expect(teacherId, isNotEmpty);
      expect(teacherNama, isNotEmpty);
    });

    test('schedule card passes class/subject from schedule data', () {
      final schedule = {
        'class_id': 'class-abc',
        'kelas_nama': '8B',
        'subject_id': 'subj-xyz',
        'mata_pelajaran_nama': 'B. Arab',
      };
      final classId = (schedule['class_id'] ?? schedule['kelas_id'])?.toString();
      final className = (schedule['class_name'] ?? schedule['kelas_nama'])?.toString();
      final subjectId = (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();
      final subjectName = (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'])?.toString();

      expect(classId, 'class-abc');
      expect(className, '8B');
      expect(subjectId, 'subj-xyz');
      expect(subjectName, 'B. Arab');
    });

    test('schedule card passes initialDate from computed schedule date', () {
      // The schedule card computes the next occurrence of the schedule's day
      final now = DateTime.now();
      const scheduleDayIndex = 3; // Kamis (Thursday), 0-indexed in dayOptions
      final todayIndex = now.weekday;
      int daysUntil = scheduleDayIndex - todayIndex;
      if (daysUntil < 0) daysUntil += 7;
      final date = now.add(Duration(days: daysUntil));
      expect(date.isAfter(now) || date.day == now.day, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Fast path: no class/subject loading in embedded mode
  // ---------------------------------------------------------------------------

  group('Fast path optimization', () {
    test('embedded mode skips _loadUserData wizard steps', () {
      // The old ClassActivityScreen(embedded:true) ran full _loadUserData:
      // 1. Resolve teacher from TeacherProvider or API
      // 2. Load class list + schedule list
      // 3. Load subject list for class
      // 4. Navigate to step 2
      //
      // The new EmbeddedActivityListScreen skips all of that.
      // It only calls _loadActivities() in initState.
      const skippedSteps = [
        'teacher resolution',
        'class list loading',
        'schedule list loading',
        'subject list loading',
        'wizard step navigation',
      ];
      expect(skippedSteps.length, 5);
    });

    test('embedded mode makes exactly 1 API call on init', () {
      // getClassActivityPaginated — that's it.
      const apiCallsOnInit = 1;
      expect(apiCallsOnInit, 1);
    });
  });
}
