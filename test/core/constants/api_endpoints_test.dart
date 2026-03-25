/// Tests for ApiEndpoints constants — ensures every endpoint is a non-empty
/// string starting with '/'.
///
/// Like a Laravel test that verifies routes/api.php entries are well-formed.
/// Catches typos (missing leading slash, empty string, etc.).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';

void main() {
  /// Helper: asserts an endpoint is a non-empty string starting with '/'.
  void expectValidEndpoint(String endpoint, String label) {
    test('$label is a valid endpoint path', () {
      expect(endpoint, isNotEmpty, reason: '$label should not be empty');
      expect(endpoint.startsWith('/'), isTrue,
          reason: '$label should start with /');
    });
  }

  group('Auth endpoints', () {
    expectValidEndpoint(ApiEndpoints.login, 'login');
    expectValidEndpoint(ApiEndpoints.verifyOtp, 'verifyOtp');
    expectValidEndpoint(ApiEndpoints.googleLogin, 'googleLogin');
    expectValidEndpoint(ApiEndpoints.logout, 'logout');
    expectValidEndpoint(ApiEndpoints.switchSchool, 'switchSchool');
    expectValidEndpoint(ApiEndpoints.switchRole, 'switchRole');
    expectValidEndpoint(ApiEndpoints.userRoles, 'userRoles');
    expectValidEndpoint(ApiEndpoints.userSchools, 'userSchools');
  });

  group('Dashboard endpoints', () {
    expectValidEndpoint(ApiEndpoints.dashboardStats, 'dashboardStats');
    expectValidEndpoint(ApiEndpoints.health, 'health');
  });

  group('Student endpoints', () {
    expectValidEndpoint(ApiEndpoints.students, 'students');
    expectValidEndpoint(ApiEndpoints.studentTemplate, 'studentTemplate');
    expectValidEndpoint(ApiEndpoints.studentImport, 'studentImport');
  });

  group('Teacher endpoints', () {
    expectValidEndpoint(ApiEndpoints.teachers, 'teachers');
    expectValidEndpoint(ApiEndpoints.teacherTemplate, 'teacherTemplate');
    expectValidEndpoint(ApiEndpoints.teacherImport, 'teacherImport');
    expectValidEndpoint(ApiEndpoints.teacherByUser, 'teacherByUser');
    expectValidEndpoint(ApiEndpoints.teacherClasses, 'teacherClasses');
  });

  group('Class endpoints', () {
    expectValidEndpoint(ApiEndpoints.classes, 'classes');
    expectValidEndpoint(ApiEndpoints.classTemplate, 'classTemplate');
    expectValidEndpoint(ApiEndpoints.classImport, 'classImport');
  });

  group('Subject endpoints', () {
    expectValidEndpoint(ApiEndpoints.subjects, 'subjects');
    expectValidEndpoint(ApiEndpoints.subjectTemplate, 'subjectTemplate');
    expectValidEndpoint(ApiEndpoints.subjectImport, 'subjectImport');
  });

  group('Schedule endpoints', () {
    expectValidEndpoint(ApiEndpoints.schedules, 'schedules');
    expectValidEndpoint(ApiEndpoints.scheduleTemplate, 'scheduleTemplate');
    expectValidEndpoint(ApiEndpoints.scheduleImport, 'scheduleImport');
  });

  group('Attendance endpoints', () {
    expectValidEndpoint(ApiEndpoints.attendance, 'attendance');
    expectValidEndpoint(ApiEndpoints.attendanceSummary, 'attendanceSummary');
  });

  group('Grade endpoints', () {
    expectValidEndpoint(ApiEndpoints.grades, 'grades');
    expectValidEndpoint(ApiEndpoints.gradeRecaps, 'gradeRecaps');
  });

  group('Other feature endpoints', () {
    expectValidEndpoint(ApiEndpoints.lessonPlans, 'lessonPlans');
    expectValidEndpoint(ApiEndpoints.announcements, 'announcements');
    expectValidEndpoint(ApiEndpoints.classActivity, 'classActivity');
    expectValidEndpoint(ApiEndpoints.reportCards, 'reportCards');
    expectValidEndpoint(ApiEndpoints.bills, 'bills');
    expectValidEndpoint(ApiEndpoints.notifications, 'notifications');
  });

  group('Settings endpoints', () {
    expectValidEndpoint(ApiEndpoints.profile, 'profile');
    expectValidEndpoint(ApiEndpoints.profilePassword, 'profilePassword');
    expectValidEndpoint(ApiEndpoints.lessonHours, 'lessonHours');
    expectValidEndpoint(ApiEndpoints.academicYears, 'academicYears');
    expectValidEndpoint(ApiEndpoints.gradeLevels, 'gradeLevels');
    expectValidEndpoint(ApiEndpoints.schoolSettings, 'schoolSettings');
  });

  group('Misc endpoints', () {
    expectValidEndpoint(ApiEndpoints.tour, 'tour');
    expectValidEndpoint(ApiEndpoints.fcmToken, 'fcmToken');
    expectValidEndpoint(ApiEndpoints.days, 'days');
    expectValidEndpoint(ApiEndpoints.semesters, 'semesters');
  });
}
