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

  // ── User (non-auth context) ──
  static const userRolesList = '/user/roles';
  static const userSchoolsList = '/user/schools';

  // ── Dashboard ──
  static const dashboardStats = '/dashboard/stats';
  static const parentAcademicRecent = '/dashboard/parent-academic-recent';
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
  static const classBySubject = '/class-by-mata-pelajaran';

  // ── Subjects ──
  static const subjects = '/subject';
  static const subjectTemplate = '/subject/template';
  static const subjectImport = '/subject/import';
  static const subjectWithClass = '/subject-with-class';

  // ── Schedules ──
  static const schedules = '/schedule';
  static const scheduleTemplate = '/schedule/template';
  static const scheduleImport = '/schedule/import';

  // ── Attendance ──
  static const attendance = '/attendance';
  static const attendanceBulk = '/attendance/bulk';
  static const attendanceTeacherSummary = '/attendance/teacher-summary';
  static const attendanceSummary = '/attendance/summary';
  static const attendanceStats = '/attendance/stats';
  static const attendanceMarkRead = '/attendance/mark-read';
  static const attendanceUnreadCount = '/attendance/unread-count';
  static const attendanceDashboardChart = '/attendance/dashboard-chart';

  // ── Grades ──
  static const grades = '/grades';
  static const gradesTeacherSummary = '/grades/teacher-summary';
  static const gradesAdminOverview = '/grades/admin-overview';
  static const gradeRecaps = '/grade-recaps';
  static const gradeRecapsTeacherSummary = '/grade-recaps/teacher-summary';
  static const gradeMarkRead = '/grade/mark-read';
  static const gradeUnreadCount = '/grade/unread-count';

  // ── Lesson Plans (RPP) ──
  static const lessonPlans = '/rpp';
  static const uploadLessonPlan = '/upload/rpp';

  // ── Announcements ──
  static const announcements = '/announcement';
  static const announcementUnreadCount = '/announcement/unread-count';
  static const announcementMarkRead = '/announcement/mark-read';

  // ── Class Activity ──
  static const classActivity = '/class-activity';
  static const classActivityTeacherSummary =
      '/class-activities/teacher-summary';

  // ── Report Cards ──
  static const reportCards = '/raport';
  static const raportsTeacherSummary = '/raports/teacher-summary';

  // ── Finance / Billing ──
  static const bills = '/bills';
  static const billMarkRead = '/bill/mark-read';
  static const billMarkSingleRead = '/bill/mark-single-read';
  static const billUnreadCount = '/bill/unread-count';
  static const generateBill = '/generate-bill';
  static const financeDashboard = '/finance/dashboard';
  static const financeGeneratedMonths = '/finance/generated-months';
  static const financeBillStats = '/finance/bills/stats';
  static const financeDashboardChart = '/finance/dashboard-chart';
  static const paymentManual = '/payment/manual';

  // ── Notifications ──
  static const notifications = '/notification';

  // ── Settings ──
  static const profile = '/profile';
  static const profilePassword = '/profile/password';
  static const lessonHours = '/lesson-hour-session';
  static const academicYears = '/academic-year';
  static const gradeLevels = '/grade-level';
  static const schoolSettings = '/school-settings';
  static const schoolConfigGradeLevels = '/school-configs/grade-levels';

  // ── Tour ──
  static const tour = '/tour';

  // ── FCM ──
  static const fcmToken = '/fcm-token';
  static const fcmTokenEndpoint = '/fcm/token';

  // ── Material Progress ──
  static const materialProgressTeacherSummary =
      '/material-progress/teacher-summary';

  // ── Days / Semesters ──
  static const days = '/day';
  static const semesters = '/semester';

  // ── Mobile (web routes, not under /api) ──
  static const appcast = '/mobile/appcast.xml';
}
