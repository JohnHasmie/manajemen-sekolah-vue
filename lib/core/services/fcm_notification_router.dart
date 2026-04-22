// Navigation routing for FCM notifications
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
// Screen imports
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart'
    as admin_ann;
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart'
    as parent_ann;
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart'
    as attendance;
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart'
    as class_act;
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart'
    as grades;

/// Routes notification taps to screen-specific destinations
class FCMNotificationRouter {
  void navigateToAnnouncementScreen() {
    _navigateByRole(
      adminBuilder: (_) => const admin_ann.AdminAnnouncementScreen(),
      defaultBuilder: (_) => const parent_ann.ParentAnnouncementScreen(),
    );
  }

  void navigateToClassActivityScreen() {
    _navigate((_) => const class_act.ParentClassActivityScreen());
  }

  void navigateToGradeScreen() {
    _navigate((_) => const grades.ParentGradeScreen());
  }

  void navigateToPresenceScreen(Map<String, dynamic> data) {
    try {
      final prefs = PreferencesService();
      final userDataString = prefs.getString('user');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final studentId = data['student_id']?.toString();

      if (studentId == null) return;

      _navigate(
        (_) => attendance.ParentAttendanceScreen(
          parent: userData,
          studentId: studentId,
        ),
      );
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to presence screen: $e');
    }
  }

  void _navigateByRole({
    required WidgetBuilder adminBuilder,
    required WidgetBuilder defaultBuilder,
  }) {
    try {
      final prefs = PreferencesService();
      final userDataStr = prefs.getString('user');
      String role = 'wali'; // Default

      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        role = userData['role'] as String? ?? 'wali';
      }

      final builder = role == 'admin' ? adminBuilder : defaultBuilder;
      _navigate(builder);
    } catch (e) {
      AppLogger.error('fcm', 'Error in role-based navigation: $e');
    }
  }

  void _navigate(WidgetBuilder builder) {
    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: builder));
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating: $e');
    }
  }
}
