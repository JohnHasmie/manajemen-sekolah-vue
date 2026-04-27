// Routes FCM notification taps to the right screen.
//
// Two paths exist depending on the `kEnableShell` feature flag:
//
//   • Flag OFF (legacy) — push the destination screen directly via the
//     global `navigatorKey`. Same behavior the app has shipped with
//     for the parent flow since the FCM feature landed.
//
//   • Flag ON (P1 shell) — dispatch via `ShellNav.goToGlobal` so the
//     correct tab activates first and then the target screen pushes
//     onto that tab's `Navigator`. Mapping per
//     `P1_BottomNav_Spec.md` § 6.2:
//
//        payload          | role  | tab         | pushed screen
//        -----------------|-------|-------------|-----------------------------
//        absensi          | wali  | attendance  | (root, no push)
//                         | guru  | grades      | TeacherAttendanceScreen
//                         | admin | academic    | AdminAttendanceReportScreen
//        class_activity*  | wali  | academic    | ParentClassActivityScreen
//                         | guru  | teaching    | TeacherClassActivityScreen
//                         | admin | academic    | AdminClassActivityScreen
//        pengumuman       | wali  | academic    | ParentAnnouncementScreen
//                         | guru  | other       | TeacherAnnouncementScreen
//                         | admin | academic    | AdminAnnouncementScreen
//        grade            | wali  | academic    | ParentGradeScreen
//                         | guru  | grades      | (root — opens grades hub)
//                         | admin | academic    | AdminGradeOverviewScreen
//        tagihan          | wali  | finance     | (root, no push)
//                         | admin | finance     | (root, no push)
//
// The role is resolved from `PreferencesService('user').role` which is
// what the app stores at sign-in. Same source the legacy
// `_navigateByRole` used.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/shell/shell_flag.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/main.dart';
// Per-role screen imports — needed for both legacy push and shell push.
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart'
    as admin_ann;
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart'
    as parent_ann;
import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart'
    as teacher_ann;
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart'
    as admin_att;
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart'
    as attendance;
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart'
    as admin_act;
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart'
    as class_act;
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart'
    as teacher_act;
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart'
    as admin_grade;
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart'
    as grades;

/// Routes notification taps to screen-specific destinations, role-aware.
class FCMNotificationRouter {
  void navigateToAnnouncementScreen() {
    final role = _resolveRole();
    if (kEnableShell) {
      switch (role) {
        case 'admin':
          ShellNav.goToGlobal(
            role: 'admin',
            tab: ShellTab.academic,
            pushOnTop: const admin_ann.AdminAnnouncementScreen(),
          );
          return;
        case 'guru':
        case 'teacher':
          ShellNav.goToGlobal(
            role: 'guru',
            tab: ShellTab.other,
            pushOnTop: const teacher_ann.TeacherAnnouncementScreen(),
          );
          return;
        default:
          ShellNav.goToGlobal(
            role: 'wali',
            tab: ShellTab.academic,
            pushOnTop: const parent_ann.ParentAnnouncementScreen(),
          );
          return;
      }
    }
    // Legacy push.
    if (role == 'admin') {
      _legacyPush((_) => const admin_ann.AdminAnnouncementScreen());
    } else if (role == 'guru' || role == 'teacher') {
      _legacyPush((_) => const teacher_ann.TeacherAnnouncementScreen());
    } else {
      _legacyPush((_) => const parent_ann.ParentAnnouncementScreen());
    }
  }

  void navigateToClassActivityScreen() {
    final role = _resolveRole();
    if (kEnableShell) {
      switch (role) {
        case 'admin':
          ShellNav.goToGlobal(
            role: 'admin',
            tab: ShellTab.academic,
            pushOnTop: const admin_act.AdminClassActivityScreen(),
          );
          return;
        case 'guru':
        case 'teacher':
          ShellNav.goToGlobal(
            role: 'guru',
            tab: ShellTab.teaching,
            pushOnTop: const teacher_act.TeacherClassActivityScreen(),
          );
          return;
        default:
          ShellNav.goToGlobal(
            role: 'wali',
            tab: ShellTab.academic,
            pushOnTop: const class_act.ParentClassActivityScreen(),
          );
          return;
      }
    }
    if (role == 'admin') {
      _legacyPush((_) => const admin_act.AdminClassActivityScreen());
    } else if (role == 'guru' || role == 'teacher') {
      _legacyPush((_) => const teacher_act.TeacherClassActivityScreen());
    } else {
      _legacyPush((_) => const class_act.ParentClassActivityScreen());
    }
  }

  void navigateToGradeScreen() {
    final role = _resolveRole();
    if (kEnableShell) {
      switch (role) {
        case 'admin':
          ShellNav.goToGlobal(
            role: 'admin',
            tab: ShellTab.academic,
            pushOnTop: const admin_grade.AdminGradeOverviewScreen(),
          );
          return;
        case 'guru':
        case 'teacher':
          // No push — landing on the Grades tab root surfaces the hub
          // from which the teacher can pick recap / input / buku nilai.
          // Per Q6 in the spec: notification is informational, Rekap is
          // the right default landing.
          ShellNav.goToGlobal(role: 'guru', tab: ShellTab.grades);
          return;
        default:
          ShellNav.goToGlobal(
            role: 'wali',
            tab: ShellTab.academic,
            pushOnTop: const grades.ParentGradeScreen(),
          );
          return;
      }
    }
    // Legacy: only the parent path was wired before — admin and teacher
    // paths kept silent (no nav). Preserve that behavior to avoid
    // surprising users with a flag-off behavior change.
    if (role != 'admin' && role != 'guru' && role != 'teacher') {
      _legacyPush((_) => const grades.ParentGradeScreen());
    }
  }

  /// Tagihan (billing) — added per spec §6 (the legacy router only
  /// logged this payload type without navigating).
  void navigateToBillingScreen() {
    final role = _resolveRole();
    if (kEnableShell) {
      if (role == 'admin') {
        ShellNav.goToGlobal(role: 'admin', tab: ShellTab.finance);
      } else {
        ShellNav.goToGlobal(role: 'wali', tab: ShellTab.finance);
      }
      return;
    }
    // No legacy implementation existed — preserve no-op rather than
    // changing flag-off behavior.
    AppLogger.info('fcm', 'tagihan tap (legacy mode, no-op)');
  }

  void navigateToPresenceScreen(Map<String, dynamic> data) {
    try {
      final prefs = PreferencesService();
      final userDataString = prefs.getString('user');
      if (userDataString == null) return;
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final studentId = data['student_id']?.toString();
      final role = (userData['role'] as String? ?? 'wali').toLowerCase();

      if (kEnableShell) {
        switch (role) {
          case 'admin':
            ShellNav.goToGlobal(
              role: 'admin',
              tab: ShellTab.academic,
              pushOnTop: const admin_att.AdminAttendanceReportScreen(),
            );
            return;
          case 'guru':
          case 'teacher':
            // No push — the Grades tab's root surfaces both grades and
            // attendance; teacher picks Absensi from there.
            ShellNav.goToGlobal(role: 'guru', tab: ShellTab.grades);
            return;
          default:
            // For parent, attendance tab IS the screen (handled by
            // ParentAttendanceTab). Just switch to the tab; the per-
            // student studentId from the payload is informational only
            // — the tab loads the user's children itself. If the
            // payload student_id matters for selection, a future
            // enhancement could pass it through a tab arg.
            ShellNav.goToGlobal(role: 'wali', tab: ShellTab.attendance);
            return;
        }
      }

      // Legacy: only parent path was wired.
      if (studentId == null) return;
      _legacyPush(
        (_) => attendance.ParentAttendanceScreen(
          parent: userData,
          studentId: studentId,
        ),
      );
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to presence screen: $e');
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────

  /// Reads the role string off the cached user record. Defaults to
  /// 'wali' when missing — matches the legacy router's default.
  String _resolveRole() {
    try {
      final prefs = PreferencesService();
      final raw = prefs.getString('user');
      if (raw == null) return 'wali';
      final userData = jsonDecode(raw) as Map<String, dynamic>;
      return (userData['role'] as String? ?? 'wali').toLowerCase();
    } catch (_) {
      return 'wali';
    }
  }

  void _legacyPush(WidgetBuilder builder) {
    try {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: builder));
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating: $e');
    }
  }
}
