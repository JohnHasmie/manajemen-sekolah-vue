// Routes a notification (push tap OR in-app list tap) to the right screen
// via the bottom-nav shell.
//
// This is the SINGLE source of truth for "notification → destination".
// Both entry points funnel through [FCMNotificationRouter.route]:
//
//   1. PUSH taps (terminated → getInitialMessage, background →
//      onMessageOpenedApp, foreground-local → onDidReceiveNotificationResponse)
//      arrive as the FCM `data` map and are dispatched by
//      `FCMNotificationHandler` (see fcm_message_handler.dart).
//   2. IN-APP list taps arrive from `NotificationNavigationMixin`, which
//      rebuilds a `data` map from the tapped `NotificationItem`.
//
// Why both must share one router: the backend emits DIFFERENT `type`
// strings on the FCM `data` payload vs. the persisted DB notification row
// (e.g. finance push sends `bill_generated`/`payment_verified` while the
// DB row stores `finance`; the class_activity push omits `type` entirely
// and only carries `screen: class_activity_detail`). Keeping two divergent
// switch statements is exactly why taps stopped landing. [_resolveKind]
// normalizes every known backend variant into one [_NotifKind] so the
// destination logic lives in one place.
//
// Dispatch goes through `ShellNav.goToGlobal` so the correct tab activates
// first and then the target screen pushes onto that tab's `Navigator`.
// Mapping (role-aware) per `P1_BottomNav_Spec.md` § 6.2:
//
//   kind             | wali           | guru          | admin
//   -----------------|----------------|---------------|----------------
//   announcement     | academic+Par.  | other+Teach.  | academic+Admin
//   classActivity    | academic+Par.  | teaching+Tea. | academic+Admin
//   grade            | academic+Par.  | grades (root) | academic+Admin
//   attendance       | attend. (root) | grades (root) | academic+Admin
//   billing          | finance (root) | —             | finance (root)
//   teachingReminder | —              | teach. (root) | —
//   (unknown)        | → in-app notification list (graceful fallback)
//
// The role is resolved from the cached `user` record (PreferencesService),
// which is what the app stores at sign-in.
import 'dart:convert';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart'
    as admin_ann;
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart'
    as parent_ann;
import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart'
    as teacher_ann;
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart'
    as admin_att;
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
import 'package:manajemensekolah/features/notifications/presentation/screens/notification_list_screen.dart'
    as notif_list;

/// Normalized notification category. Every backend `type`/`screen` variant
/// collapses into exactly one of these via [FCMNotificationRouter.kindFor].
///
/// Public so the pure type→kind mapping can be unit-tested without a
/// mounted navigator.
enum NotificationKind {
  announcement,
  classActivity,
  grade,
  attendance,
  billing,
  teachingReminder,
  unknown,
}

/// Routes notification taps to screen-specific destinations, role-aware.
///
/// Public API:
/// - [route] — the single entry point used by BOTH push taps and in-app
///   list taps. Pass the notification `data` map (push payload or a map
///   rebuilt from the tapped in-app item).
class FCMNotificationRouter {
  /// Single entry point. Maps [data] → destination and navigates.
  ///
  /// [data] is the FCM `data` map for push taps, or a `{'type': ...}` map
  /// rebuilt from a tapped in-app [NotificationItem]. Unknown / missing
  /// types fall back to opening the in-app notification list rather than
  /// doing nothing (the previous bug) or crashing.
  void route(Map<String, dynamic> data) {
    final kind = kindFor(data);
    AppLogger.debug(
      'fcm',
      'Routing notification: type=${data['type']} '
          'screen=${data['screen']} → kind=$kind',
    );

    switch (kind) {
      case NotificationKind.announcement:
        navigateToAnnouncementScreen();
      case NotificationKind.classActivity:
        navigateToClassActivityScreen();
      case NotificationKind.grade:
        navigateToGradeScreen();
      case NotificationKind.attendance:
        navigateToPresenceScreen(data);
      case NotificationKind.billing:
        navigateToBillingScreen();
      case NotificationKind.teachingReminder:
        navigateToTeachingReminder();
      case NotificationKind.unknown:
        _openNotificationList();
    }
  }

  /// Normalizes the heterogeneous backend payloads into a single
  /// [NotificationKind]. Reads `type` first, then falls back to the
  /// `screen` hint (class_activity push carries `screen:
  /// class_activity_detail` but no `type`).
  ///
  /// Pure and side-effect free so it can be unit-tested directly.
  static NotificationKind kindFor(Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.toLowerCase();
    final screen = (data['screen'] as String?)?.toLowerCase();

    switch (type) {
      // ── Announcements (incl. scheduled-event reminders) ──────────────
      case 'announcement':
      case 'pengumuman':
      case 'announcement_event':
      case 'announcement_event_personal':
        return NotificationKind.announcement;

      // ── Class activity ───────────────────────────────────────────────
      case 'class_activity':
      case 'class_activity_detail':
      case 'activity':
        return NotificationKind.classActivity;

      // ── Grades ───────────────────────────────────────────────────────
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return NotificationKind.grade;

      // ── Attendance ───────────────────────────────────────────────────
      case 'attendance':
      case 'absensi':
        return NotificationKind.attendance;

      // ── Teaching reminder (post-teaching data completion) ────────────
      case 'reminder_teaching':
        return NotificationKind.teachingReminder;
    }

    // ── Finance / billing ──────────────────────────────────────────────
    // The DB notification row uses `finance`; the FCM push uses granular
    // event types (`bill_generated`, `payment_verified`, `payment_rejected`,
    // `payment_confirmed`, `payment_submitted`). Match the family by prefix
    // plus the legacy `tagihan`/`bill` aliases.
    if (type != null &&
        (type == 'finance' ||
            type == 'tagihan' ||
            type == 'bill' ||
            type.startsWith('bill') ||
            type.startsWith('payment'))) {
      return NotificationKind.billing;
    }

    // ── `screen` fallback (push payloads that omit `type`) ──────────────
    if (screen != null) {
      if (screen.startsWith('class_activity')) {
        return NotificationKind.classActivity;
      }
      if (screen.startsWith('finance')) return NotificationKind.billing;
      if (screen.startsWith('attendance')) return NotificationKind.attendance;
      if (screen.startsWith('grade')) return NotificationKind.grade;
      if (screen.startsWith('announcement')) {
        return NotificationKind.announcement;
      }
    }

    return NotificationKind.unknown;
  }

  void navigateToAnnouncementScreen() {
    final role = _resolveRole();
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

  void navigateToClassActivityScreen() {
    final role = _resolveRole();
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

  void navigateToGradeScreen() {
    final role = _resolveRole();
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

  /// Tagihan (billing) — added per spec §6.
  void navigateToBillingScreen() {
    final role = _resolveRole();
    if (role == 'admin') {
      ShellNav.goToGlobal(role: 'admin', tab: ShellTab.finance);
    } else {
      ShellNav.goToGlobal(role: 'wali', tab: ShellTab.finance);
    }
  }

  /// Post-teaching reminder — teacher-only. Lands on the Teaching tab root
  /// where the teacher completes the outstanding attendance / materi data.
  void navigateToTeachingReminder() {
    ShellNav.goToGlobal(role: 'guru', tab: ShellTab.teaching);
  }

  void navigateToPresenceScreen(Map<String, dynamic> data) {
    try {
      final role = _resolveRole();

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
          // ParentAttendanceTab). The per-student studentId from the
          // payload is informational only — the tab loads the user's
          // children itself. If the payload student_id matters for
          // selection, a future enhancement could pass it through a
          // tab arg.
          ShellNav.goToGlobal(role: 'wali', tab: ShellTab.attendance);
          return;
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to presence screen: $e');
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────

  /// Graceful fallback: open the in-app notification list so a tap never
  /// does nothing (and never crashes) when the type is unrecognized. The
  /// list lands on the role's home tab — its always-present surface.
  void _openNotificationList() {
    final role = _resolveRole();
    final shellRole = (role == 'teacher')
        ? 'guru'
        : (role == 'parent' || role == 'orang_tua')
        ? 'wali'
        : role;
    AppLogger.debug('fcm', 'Unknown notification type → opening inbox list');
    ShellNav.goToGlobal(
      role: shellRole,
      tab: ShellTab.home,
      pushOnTop: notif_list.NotificationListScreen(role: shellRole),
    );
  }

  /// Reads the role string off the cached user record. Defaults to
  /// 'wali' when missing.
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
}
