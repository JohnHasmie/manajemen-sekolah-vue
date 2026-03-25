/// api_endpoints.dart - Centralized API endpoint path constants.
/// Like Laravel's `routes/api.php` — single source of truth for all API paths.
///
/// Replaces hardcoded string paths scattered across api_service.dart and feature services.
library;

/// All API endpoint paths used by the app.
/// Paths are relative to the base URL (e.g., '/auth/login' not 'https://api.example.com/auth/login').
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──
  static const login = '/auth/login';
  static const verifyOtp = '/auth/verify-otp';
  static const googleLogin = '/auth/google-login';
  static const logout = '/auth/logout';
  static const switchSchool = '/auth/switch-school';
  static const switchRole = '/auth/switch-role';
  static const userRoles = '/auth/roles';
  static const userSchools = '/auth/schools';

  // ── Dashboard ──
  static const dashboardStats = '/dashboard/stats';
  static const health = '/health';

  // ── Students ──
  static const students = '/student';
  static const studentTemplate = '/student/template';
  static const studentImport = '/student/import';

  // ── Teachers ──
  static const teachers = '/teacher';
  static const teacherTemplate = '/teacher/template';
  static const teacherImport = '/teacher/import';
  static const teacherByUser = '/teacher/by-user';
  static const teacherClasses = '/teacher-classes';

  // ── Classes ──
  static const classes = '/class';
  static const classTemplate = '/class/template';
  static const classImport = '/class/import';

  // ── Subjects ──
  static const subjects = '/subject';
  static const subjectTemplate = '/subject/template';
  static const subjectImport = '/subject/import';

  // ── Schedules ──
  static const schedules = '/schedule';
  static const scheduleTemplate = '/schedule/template';
  static const scheduleImport = '/schedule/import';

  // ── Attendance ──
  static const attendance = '/attendance';
  static const attendanceSummary = '/attendance-summary';

  // ── Grades ──
  static const grades = '/grades';
  static const gradeRecaps = '/grade-recaps';

  // ── Lesson Plans (RPP) ──
  static const lessonPlans = '/rpp';

  // ── Announcements ──
  static const announcements = '/announcement';

  // ── Class Activity ──
  static const classActivity = '/class-activity';

  // ── Report Cards ──
  static const reportCards = '/raport';

  // ── Finance / Billing ──
  static const bills = '/bills';

  // ── Notifications ──
  static const notifications = '/notification';

  // ── Settings ──
  static const profile = '/profile';
  static const profilePassword = '/profile/password';
  static const lessonHours = '/lesson-hour-session';
  static const academicYears = '/academic-year';
  static const gradeLevels = '/grade-level';
  static const schoolSettings = '/school-settings';

  // ── Tour ──
  static const tour = '/tour';

  // ── FCM ──
  static const fcmToken = '/fcm-token';

  // ── Days / Semesters ──
  static const days = '/day';
  static const semesters = '/semester';
}
