/**
 * Vue Router — role-aware route table and auth guard.
 *
 * Route layout mirrors Flutter's `main.dart` routes:
 *   /login         → LoginView (no shell)
 *   /              → AppShell (wraps everything below)
 *     /admin/*     → admin role
 *     /teacher/*   → teacher (guru / wali_kelas) role
 *     /parent/*    → parent (wali) role
 *     /staff/*     → staff role
 *     /profile     → ProfileView (all roles)
 *     /notifications → NotificationListView (all roles)
 *
 * Hub redirect at `/` sends the user to the dashboard for their active
 * role (same as Flutter's `Dashboard(role: …)` hub).
 *
 * Each role subtree is currently a stub `RoleHome` placeholder; real
 * dashboards will replace them per the task list (#18, #32, #43).
 */
import {
  createRouter,
  createWebHistory,
  type RouteRecordRaw,
} from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { tenantKindFromRaw } from '@/composables/useTenant';
import type { Role } from '@/types/auth';

/**
 * True when the active tenant is a tutoring center. Read from the
 * persisted user (`tenant_type`), falling back to the active school row.
 */
function isTutoringTenant(): boolean {
  const auth = useAuthStore();
  const raw =
    auth.user?.tenant_type ??
    auth.schools.find((s) => (s.id ?? s.school_id) === auth.schoolId)
      ?.tenant_type;
  return tenantKindFromRaw(raw) === 'TUTORING_CENTER';
}

// Lazy view loaders — keep initial bundle small.
const LoginView = () => import('@/views/auth/LoginView.vue');
const AppShell = () => import('@/layouts/AppShell.vue');
const AdminDashboardView = () => import('@/views/admin/AdminDashboardView.vue');
const AdminStudentManagementView = () =>
  import('@/views/admin/AdminStudentManagementView.vue');
const AdminTeacherManagementView = () =>
  import('@/views/admin/AdminTeacherManagementView.vue');
const AdminClassroomManagementView = () =>
  import('@/views/admin/AdminClassroomManagementView.vue');
const AdminSubjectManagementView = () =>
  import('@/views/admin/AdminSubjectManagementView.vue');
const AdminSubjectClassManagementView = () =>
  import('@/views/admin/AdminSubjectClassManagementView.vue');
const AdminLessonPlanReviewView = () =>
  import('@/views/admin/AdminLessonPlanReviewView.vue');
const AdminLessonPlanDetailView = () =>
  import('@/views/admin/AdminLessonPlanDetailView.vue');
const AdminScheduleManagementView = () =>
  import('@/views/admin/AdminScheduleManagementView.vue');
const AdminLessonHourSettingsView = () =>
  import('@/views/admin/AdminLessonHourSettingsView.vue');
const AdminAnnouncementView = () =>
  import('@/views/admin/AdminAnnouncementView.vue');
const AdminAttendanceDashboardView = () =>
  import('@/views/admin/AdminAttendanceDashboardView.vue');
const AdminAttendanceTingkatHeatmapView = () =>
  import('@/views/admin/AdminAttendanceTingkatHeatmapView.vue');
const AdminAttendanceReportView = () =>
  import('@/views/admin/AdminAttendanceReportView.vue');
const AdminAttendanceDetailView = () =>
  import('@/views/admin/AdminAttendanceDetailView.vue');
const AdminClassActivityView = () =>
  import('@/views/admin/AdminClassActivityView.vue');
const AdminFinanceView = () =>
  import('@/views/admin/AdminFinanceView.vue');
const AdminFinanceTagihanView = () =>
  import('@/views/admin/AdminFinanceTagihanView.vue');
const AdminFinancePembayaranView = () =>
  import('@/views/admin/AdminFinancePembayaranView.vue');
const AdminFinanceJenisView = () =>
  import('@/views/admin/AdminFinanceJenisView.vue');
const AdminFinanceBillGroupDetailView = () =>
  import('@/views/admin/AdminFinanceBillGroupDetailView.vue');
const AdminGradeOverviewView = () =>
  import('@/views/admin/AdminGradeOverviewView.vue');
const AdminGradeRecapView = () =>
  import('@/views/admin/AdminGradeRecapView.vue');
const AdminReportCardHubView = () =>
  import('@/views/admin/AdminReportCardHubView.vue');
const AdminReportCardClassView = () =>
  import('@/views/admin/AdminReportCardClassView.vue');
const AdminReportCardDetailView = () =>
  import('@/views/admin/AdminReportCardDetailView.vue');
const AdminSettingsView = () =>
  import('@/views/admin/AdminSettingsView.vue');
const AdminDataManagementView = () =>
  import('@/views/admin/AdminDataManagementView.vue');
const AdminSchoolLevelSettingsView = () =>
  import('@/views/admin/AdminSchoolLevelSettingsView.vue');
const AdminKelolaTahunAjaranView = () =>
  import('@/views/admin/AdminKelolaTahunAjaranView.vue');
const PriorityInboxView = () =>
  import('@/views/common/PriorityInboxView.vue');
const AdminAnnouncementCalendarView = () =>
  import('@/views/admin/AdminAnnouncementCalendarView.vue');
const AdminClassFinanceReportView = () =>
  import('@/views/admin/AdminClassFinanceReportView.vue');
const ParentBillingView = () =>
  import('@/views/parent/ParentBillingView.vue');
const ParentBillCheckoutView = () =>
  import('@/views/parent/ParentBillCheckoutView.vue');
const ParentPaymentSuccessView = () =>
  import('@/views/parent/ParentPaymentSuccessView.vue');
const ParentAttendanceView = () =>
  import('@/views/parent/ParentAttendanceView.vue');
const ParentAttendanceCalendarView = () =>
  import('@/views/parent/ParentAttendanceCalendarView.vue');
const ParentGradeView = () => import('@/views/parent/ParentGradeView.vue');
const ParentClassActivityView = () =>
  import('@/views/parent/ParentClassActivityView.vue');
const ParentReportCardView = () =>
  import('@/views/parent/ParentReportCardView.vue');
const ParentReportCardDetailView = () =>
  import('@/views/parent/ParentReportCardDetailView.vue');
const ParentAnnouncementView = () =>
  import('@/views/parent/ParentAnnouncementView.vue');
const ParentRecommendationView = () =>
  import('@/views/parent/ParentRecommendationView.vue');
const AdminTeacherAttendanceView = () =>
  import('@/views/admin/AdminTeacherAttendanceView.vue');
// ── Super-admin (KamilEdu-team) area ──────────────────────────────────
// Dedicated /super-admin subtree, visually distinct from the school-admin
// shell but on the same theme tokens. Guarded to super_admin only.
const SuperAdminOverviewView = () =>
  import('@/views/super-admin/SuperAdminOverviewView.vue');
const SuperAdminDemoRequestView = () =>
  import('@/views/super-admin/SuperAdminDemoRequestView.vue');
const SuperAdminDemoRequestDetailView = () =>
  import('@/views/super-admin/SuperAdminDemoRequestDetailView.vue');
const SuperAdminSchoolsView = () =>
  import('@/views/super-admin/SuperAdminSchoolsView.vue');
const SuperAdminBroadcastView = () =>
  import('@/views/super-admin/SuperAdminBroadcastView.vue');
const SuperAdminIncompleteRegistrationsView = () =>
  import('@/views/super-admin/SuperAdminIncompleteRegistrationsView.vue');
const TeacherPresensiView = () =>
  import('@/views/teacher/TeacherPresensiView.vue');
const TeacherPresensiHistoryView = () =>
  import('@/views/teacher/TeacherPresensiHistoryView.vue');
// School-teacher dashboard view is loaded indirectly via
// TeacherHomeRouter — that wrapper imports it AND the bimbel
// equivalent, then picks based on the active tenant.
const TeacherHomeRouter = () =>
  import('@/views/teacher/TeacherHomeRouter.vue');
const TeacherAttendanceView = () =>
  import('@/views/teacher/TeacherAttendanceView.vue');
const TeacherAttendanceDetailView = () =>
  import('@/views/teacher/TeacherAttendanceDetailView.vue');
const TeacherAttendanceInputView = () =>
  import('@/views/teacher/TeacherAttendanceInputView.vue');
const TeacherGradeBookView = () =>
  import('@/views/teacher/TeacherGradeBookView.vue');
const TeacherGradeRecapView = () =>
  import('@/views/teacher/TeacherGradeRecapView.vue');
const TeacherGradeRecapDetailView = () =>
  import('@/views/teacher/TeacherGradeRecapDetailView.vue');
const TeacherClassActivityView = () =>
  import('@/views/teacher/TeacherClassActivityView.vue');
const TeacherMaterialView = () =>
  import('@/views/teacher/TeacherMaterialView.vue');
const TeacherLessonPlanView = () =>
  import('@/views/teacher/TeacherLessonPlanView.vue');
const TeacherLessonPlanDetailView = () =>
  import('@/views/teacher/TeacherLessonPlanDetailView.vue');
const TeacherRecommendationView = () =>
  import('@/views/teacher/TeacherRecommendationView.vue');
const TeacherRecommendationStudentsView = () =>
  import('@/views/teacher/TeacherRecommendationStudentsView.vue');
const TeacherRecommendationResultView = () =>
  import('@/views/teacher/TeacherRecommendationResultView.vue');
const TeacherRecommendationEditView = () =>
  import('@/views/teacher/TeacherRecommendationEditView.vue');
const TeacherScheduleView = () =>
  import('@/views/teacher/TeacherScheduleView.vue');
const TeacherAnnouncementView = () =>
  import('@/views/teacher/TeacherAnnouncementView.vue');
const TeacherReportCardHubView = () =>
  import('@/views/teacher/TeacherReportCardHubView.vue');
const TeacherReportCardClassView = () =>
  import('@/views/teacher/TeacherReportCardClassView.vue');
const TeacherReportCardDetailView = () =>
  import('@/views/teacher/TeacherReportCardDetailView.vue');
const ParentDashboardView = () =>
  import('@/views/parent/ParentDashboardView.vue');
const StaffStubView = () => import('@/views/RoleHomeStub.vue');
const ProfileView = () => import('@/views/account/ProfileView.vue');
const NotificationListView = () => import('@/views/common/NotificationListView.vue');

const roleHomePath: Record<string, string> = {
  admin: '/admin',
  administrator: '/admin',
  guru: '/teacher',
  teacher: '/teacher',
  wali_kelas: '/teacher',
  wali: '/parent',
  parent: '/parent',
  orang_tua: '/parent',
  staff: '/staff',
  // KamilEdu-team super-admin: no school/role — land on the DEDICATED
  // super-admin area (Ringkasan Platform overview), NEVER the
  // school-admin shell or the school/role picker. Mirrors the backend
  // super-admin login short-circuit (edu_backend_core_api MR !115).
  super_admin: '/super-admin',
};

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { public: true },
  },

  // Register-demo wizard — used by Google-login users with no
  // existing school relation. Treated like the login flow: routes
  // are gated by auth.step rather than by role. The view itself is
  // a full-page wizard with no AppShell chrome.
  // /register-demo is now the tenant-choice landing (sekolah vs bimbel).
  // The actual wizard moved to /register-demo/wizard. The legacy stepped
  // layout stays under /register-demo/legacy for back-compat in case any
  // existing link / sign-in resume target sends users there — guard
  // logic below still routes auth.step='register_demo' to /register-demo
  // (the landing), so a partially-completed sekolah wizard hand-off
  // continues to work via the conversational shell.
  {
    path: '/register-demo',
    name: 'register-demo',
    component: () =>
      import('@/views/register-demo/RegisterDemoTenantChoiceView.vue'),
    meta: { public: true, registerDemo: true },
  },
  {
    path: '/register-demo/wizard',
    name: 'register-demo-wizard',
    component: () =>
      import('@/views/register-demo/conversational/ConversationalWizard.vue'),
    meta: { public: true, registerDemo: true },
  },
  {
    path: '/register-demo/legacy',
    name: 'register-demo-legacy',
    component: () => import('@/views/register-demo/RegisterDemoView.vue'),
    meta: { public: true, registerDemo: true },
  },

  // Separate "Data Diri" (requester identity) screen — reached AFTER
  // the wizard's last step is submitted. Distinct route, NOT a wizard
  // step: a fresh visitor fills the wizard (school data) first and only
  // then lands here to enter identity + do the final send. Same public
  // gating as the wizard. The view itself guards against direct nav /
  // refresh with no wizard data by redirecting back to /register-demo.
  {
    path: '/register-demo/identity',
    name: 'register-demo-identity',
    component: () => import('@/views/register-demo/RegisterDemoIdentityView.vue'),
    meta: { public: true, registerDemo: true },
  },

  // Authenticated routes are nested under the AppShell layout.
  {
    path: '/',
    component: AppShell,
    children: [
      // Hub redirect — sends the user to their role's home.
      {
        path: '',
        name: 'hub',
        redirect: () => {
          const auth = useAuthStore();
          if (!auth.isAuthenticated || !auth.activeRole) return '/login';
          return roleHomePath[auth.activeRole] ?? '/login';
        },
      },

      // Admin subtree
      {
        path: 'admin',
        name: 'admin.home',
        component: AdminDashboardView,
        meta: { role: 'admin' satisfies Role },
        // A bimbel admin's school dashboard reads empty — bounce to the
        // tutoring-native dashboard instead.
        beforeEnter: () =>
          isTutoringTenant() ? { name: 'admin.tutoring.dashboard' } : true,
      },
      {
        path: 'admin/inbox',
        name: 'admin.inbox',
        component: PriorityInboxView,
        props: { role: 'admin' },
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/students',
        name: 'admin.students',
        component: AdminStudentManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/teachers',
        name: 'admin.teachers',
        component: AdminTeacherManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/classes',
        name: 'admin.classes',
        component: AdminClassroomManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/subjects',
        name: 'admin.subjects',
        component: AdminSubjectManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/subjects/:subjectId/classes',
        name: 'admin.subjects.classes',
        component: AdminSubjectClassManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/lesson-plans',
        name: 'admin.lesson-plans',
        component: AdminLessonPlanReviewView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/lesson-plans/:id',
        name: 'admin.lesson-plans.detail',
        component: AdminLessonPlanDetailView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/schedule',
        name: 'admin.schedule',
        component: AdminScheduleManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/schedule/lesson-hours',
        name: 'admin.schedule.lesson-hours',
        component: AdminLessonHourSettingsView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/announcements',
        name: 'admin.announcements',
        component: AdminAnnouncementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/announcements/calendar',
        name: 'admin.announcements.calendar',
        component: AdminAnnouncementCalendarView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/attendance',
        name: 'admin.attendance',
        component: AdminAttendanceDashboardView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/attendance/tingkat/:tingkat',
        name: 'admin.attendance.tingkat',
        component: AdminAttendanceTingkatHeatmapView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/attendance/laporan',
        name: 'admin.attendance.laporan',
        component: AdminAttendanceReportView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/attendance/detail',
        name: 'admin.attendance.detail',
        component: AdminAttendanceDetailView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/class-activity',
        name: 'admin.class-activity',
        component: AdminClassActivityView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/finance',
        component: AdminFinanceView,
        meta: { role: 'admin' satisfies Role },
        redirect: { name: 'admin.finance.tagihan' },
        children: [
          {
            path: 'tagihan',
            name: 'admin.finance.tagihan',
            component: AdminFinanceTagihanView,
            meta: { role: 'admin' satisfies Role },
          },
          {
            path: 'pembayaran',
            name: 'admin.finance.pembayaran',
            component: AdminFinancePembayaranView,
            meta: { role: 'admin' satisfies Role },
          },
          {
            path: 'jenis',
            name: 'admin.finance.jenis',
            component: AdminFinanceJenisView,
            meta: { role: 'admin' satisfies Role },
          },
        ],
      },
      {
        // Back-compat redirect — existing menu items use `admin.finance`.
        path: 'admin/finance/index',
        name: 'admin.finance',
        redirect: { name: 'admin.finance.tagihan' },
      },
      {
        path: 'admin/finance/tagihan/:classId/:paymentTypeId',
        name: 'admin.finance.tagihan.detail',
        component: AdminFinanceBillGroupDetailView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/finance/class/:classId',
        name: 'admin.finance.class',
        component: AdminClassFinanceReportView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/grades',
        name: 'admin.grades',
        component: AdminGradeOverviewView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/grade-recap',
        name: 'admin.grade-recap',
        component: AdminGradeRecapView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        // Admin-side drill from AdminGradeRecapView per-slice card —
        // reuses the teacher matrix component. Same path shape as
        // `teacher.grade-recap.detail`; the underlying component
        // accepts the `:classId` / `:subjectId` params + `className`
        // / `subjectName` query already.
        path: 'admin/grade-recap/:classId/:subjectId',
        name: 'admin.grade-recap.detail',
        component: TeacherGradeRecapDetailView,
        props: true,
        meta: { role: 'admin' satisfies Role },
      },
      {
        // Admin-side drill from AdminGradeOverviewView per-teacher
        // card. Reuses TeacherGradeBookView; the underlying component
        // reads `teacher_id` + `admin_view=1` from the query so it
        // can render the read-only admin view.
        path: 'admin/grades/teacher/:teacherId?',
        name: 'admin.grades.teacher',
        component: TeacherGradeBookView,
        props: true,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/report-cards',
        name: 'admin.report-cards',
        component: AdminReportCardHubView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/report-cards/kelas/:classId',
        name: 'admin.report-cards.class',
        component: AdminReportCardClassView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/report-cards/kelas/:classId/siswa/:studentClassId',
        name: 'admin.report-cards.detail',
        component: AdminReportCardDetailView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/settings',
        name: 'admin.settings',
        component: AdminSettingsView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/settings/data',
        name: 'admin.settings.data',
        component: AdminDataManagementView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/settings/school',
        name: 'admin.settings.school',
        component: AdminSchoolLevelSettingsView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/settings/kelola-tahun-ajaran',
        name: 'admin.settings.kelola-tahun-ajaran',
        component: AdminKelolaTahunAjaranView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        // PRESENSI GURU — admin config + report for teacher daily
        // attendance (camera/location/geofence settings + report list).
        path: 'admin/teacher-attendance',
        name: 'admin.teacher-attendance',
        component: AdminTeacherAttendanceView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        // LEGACY redirect — the Demo Requests review page moved into the
        // dedicated /super-admin area. Keep this so old bookmarks and any
        // cached super-admin landing target still resolve.
        path: 'admin/demo-requests',
        name: 'admin.demo-requests',
        redirect: { name: 'super-admin.demo-requests' },
      },

      // ── SUPER-ADMIN (KamilEdu-team) AREA ──────────────────────────
      // Dedicated subtree, separate from the school-admin /admin tree.
      // Every route is gated by `meta.superAdmin: true` (client guard
      // below) AND the backend EnsureSuperAdmin middleware. A normal
      // school-admin who lands here is bounced to their own home.
      {
        path: 'super-admin',
        name: 'super-admin.home',
        component: SuperAdminOverviewView,
        meta: { superAdmin: true },
      },
      {
        path: 'super-admin/demo-requests',
        name: 'super-admin.demo-requests',
        component: SuperAdminDemoRequestView,
        meta: { superAdmin: true },
      },
      {
        // Full detail of one demo request — EVERY form input the
        // requester submitted in the register-demo wizard + identity
        // screen. Opened from a list row. Approve/Reject is available
        // inline while the request is still pending.
        path: 'super-admin/demo-requests/:id',
        name: 'super-admin.demo-requests.detail',
        component: SuperAdminDemoRequestDetailView,
        meta: { superAdmin: true },
      },
      {
        path: 'super-admin/schools',
        name: 'super-admin.schools',
        component: SuperAdminSchoolsView,
        meta: { superAdmin: true },
      },
      {
        // Abandoned demo registrations — people who started the
        // register-demo wizard but never finished/submitted, with a
        // "step X of Y" progress indicator so the team can follow up.
        path: 'super-admin/demo-incomplete',
        name: 'super-admin.demo-incomplete',
        component: SuperAdminIncompleteRegistrationsView,
        meta: { superAdmin: true },
      },
      {
        path: 'super-admin/broadcast',
        name: 'super-admin.broadcast',
        component: SuperAdminBroadcastView,
        meta: { superAdmin: true },
      },

      // Teacher / Wali Kelas subtree
      {
        path: 'teacher',
        name: 'teacher.home',
        // Wrapper that swaps body based on tenant_type — school
        // teacher dashboard vs bimbel-native tutor home.
        component: TeacherHomeRouter,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/inbox',
        name: 'teacher.inbox',
        component: PriorityInboxView,
        props: { role: 'teacher' },
        meta: { role: 'guru' satisfies Role },
      },
      {
        // PRESENSI GURU — the teacher's own daily check-in/out flow
        // (webcam selfie + GPS geofence). Distinct from
        // `teacher/attendance`, which is the per-session STUDENT
        // attendance ("kehadiran siswa"). Named "my-attendance" so the
        // English path doesn't collide with that student route.
        path: 'teacher/my-attendance',
        name: 'teacher.my-attendance',
        component: TeacherPresensiView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/my-attendance/history',
        name: 'teacher.my-attendance.history',
        component: TeacherPresensiHistoryView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/attendance',
        name: 'teacher.attendance',
        component: TeacherAttendanceView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/attendance/detail',
        name: 'teacher.attendance.detail',
        component: TeacherAttendanceDetailView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/attendance/input',
        name: 'teacher.attendance.input',
        component: TeacherAttendanceInputView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/grades',
        name: 'teacher.grades',
        component: TeacherGradeBookView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/grade-recap',
        name: 'teacher.grade-recap',
        component: TeacherGradeRecapView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        // Detail / matrix mode — drilled into from a recap card.
        path: 'teacher/grade-recap/:classId/:subjectId',
        name: 'teacher.grade-recap.detail',
        component: TeacherGradeRecapDetailView,
        props: true,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/class-activity',
        name: 'teacher.class-activity',
        component: TeacherClassActivityView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/materials',
        name: 'teacher.materials',
        component: TeacherMaterialView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/lesson-plans',
        name: 'teacher.lesson-plans',
        component: TeacherLessonPlanView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/lesson-plans/:id',
        name: 'teacher.lesson-plans.detail',
        component: TeacherLessonPlanDetailView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/recommendations',
        name: 'teacher.recommendations',
        component: TeacherRecommendationView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/recommendations/kelas/:classId',
        name: 'teacher.recommendations.students',
        component: TeacherRecommendationStudentsView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/recommendations/kelas/:classId/siswa/:studentId',
        name: 'teacher.recommendations.result',
        component: TeacherRecommendationResultView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/recommendations/edit/:recId',
        name: 'teacher.recommendations.edit',
        component: TeacherRecommendationEditView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/schedule',
        name: 'teacher.schedule',
        component: TeacherScheduleView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/announcements',
        name: 'teacher.announcements',
        component: TeacherAnnouncementView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/report-cards',
        name: 'teacher.report-cards',
        component: TeacherReportCardHubView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/report-cards/kelas/:classId',
        name: 'teacher.report-cards.class',
        component: TeacherReportCardClassView,
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/report-cards/kelas/:classId/siswa/:studentClassId',
        name: 'teacher.report-cards.detail',
        component: TeacherReportCardDetailView,
        meta: { role: 'guru' satisfies Role },
      },

      // Parent / Wali Murid subtree
      {
        path: 'parent',
        name: 'parent.home',
        component: ParentDashboardView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/inbox',
        name: 'parent.inbox',
        component: PriorityInboxView,
        props: { role: 'parent' },
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/billing',
        name: 'parent.billing',
        component: ParentBillingView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/billing/checkout/:billId',
        name: 'parent.bill-checkout',
        component: ParentBillCheckoutView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/billing/success/:paymentId',
        name: 'parent.payment-success',
        component: ParentPaymentSuccessView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/attendance',
        name: 'parent.attendance',
        component: ParentAttendanceView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/attendance/calendar',
        name: 'parent.attendance.calendar',
        component: ParentAttendanceCalendarView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/grades',
        name: 'parent.grades',
        component: ParentGradeView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/class-activity',
        name: 'parent.class-activity',
        component: ParentClassActivityView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/report-cards',
        name: 'parent.report-cards',
        component: ParentReportCardView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/report-cards/:studentClassId',
        name: 'parent.report-cards.detail',
        component: ParentReportCardDetailView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/announcements',
        name: 'parent.announcements',
        component: ParentAnnouncementView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/recommendations',
        name: 'parent.recommendations',
        component: ParentRecommendationView,
        meta: { role: 'wali' satisfies Role },
      },

      // ── Tutoring (bimbel) ─────────────────────────────────────────
      // Reached when the active tenant is a TUTORING_CENTER. Routes are
      // gated by meta.role like every other entry; their position in
      // this array doesn't matter (Vue Router matches by path). Lazy
      // imports keep the bimbel bundle out of the school-only flows.
      {
        path: 'parent/tutoring/:studentId',
        name: 'parent.tutoring.overview',
        component: () =>
          import('@/views/parent/ParentTutoringOverviewView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/kelas',
        name: 'parent.tutoring.kelas',
        component: () => import('@/views/parent/tutoring/ParentKelasView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/kelas/:groupId',
        name: 'parent.tutoring.kelas-detail',
        component: () =>
          import('@/views/parent/tutoring/ParentKelasDetailView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/sesi',
        name: 'parent.tutoring.sesi',
        component: () => import('@/views/parent/tutoring/ParentSesiView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/tagihan',
        name: 'parent.tutoring.tagihan',
        component: () => import('@/views/parent/tutoring/ParentTagihanView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/bills/:billId/bayar',
        name: 'parent.tutoring.bill-pay',
        component: () =>
          import('@/views/parent/tutoring/ParentBayarTagihanView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/kegiatan',
        name: 'parent.tutoring.kegiatan',
        component: () =>
          import('@/views/parent/tutoring/ParentKegiatanView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/nilai',
        name: 'parent.tutoring.nilai',
        component: () => import('@/views/parent/tutoring/ParentNilaiView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/voucher',
        name: 'parent.tutoring.voucher',
        component: () =>
          import('@/views/parent/tutoring/ParentVoucherView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/peringkat',
        name: 'parent.tutoring.peringkat',
        component: () =>
          import('@/views/parent/tutoring/ParentPeringkatView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/:studentId/pengumuman',
        name: 'parent.tutoring.pengumuman',
        component: () =>
          import('@/views/parent/tutoring/ParentPengumumanView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/notifikasi',
        name: 'parent.tutoring.notifikasi',
        component: () =>
          import('@/views/parent/tutoring/ParentNotifikasiView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/lainnya',
        name: 'parent.tutoring.lainnya',
        component: () =>
          import('@/views/parent/tutoring/ParentLainnyaView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/profil',
        name: 'parent.tutoring.profil',
        component: () => import('@/views/parent/tutoring/ParentProfilView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/profil/ubah-sandi',
        name: 'parent.tutoring.ubah-sandi',
        component: () =>
          import('@/views/parent/tutoring/ParentUbahSandiView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/tampilan',
        name: 'parent.tutoring.tampilan',
        component: () =>
          import('@/views/parent/tutoring/ParentTampilanView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/daftar-calon',
        name: 'parent.tutoring.daftar-lead',
        component: () =>
          import('@/views/parent/tutoring/ParentDaftarLeadView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/tutoring/daftar-anak',
        name: 'parent.tutoring.enroll-new',
        component: () =>
          import('@/views/parent/tutoring/ParentEnrollWizardView.vue'),
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'admin/tutoring',
        name: 'admin.tutoring.dashboard',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringDashboardView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/sessions',
        name: 'admin.tutoring.sessions',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringSessionsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        // Admin-scoped view of a single session: roster + attendance
        // (read-write for admin) + catatan sesi. Reuses the tutor's
        // attendance component because the backend already gates by
        // tenant + role; the only difference is the URL prefix so the
        // 'guru'-only router guard doesn't bounce the admin.
        path: 'admin/tutoring/sessions/:sessionId/attendance',
        name: 'admin.tutoring.session-attendance',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionAttendanceView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/students',
        name: 'admin.tutoring.students',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringStudentsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/tutors',
        name: 'admin.tutoring.tutors',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringTutorsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/tutors/:userId',
        name: 'admin.tutoring.tutor-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringTutorDetailView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/bills',
        name: 'admin.tutoring.bills',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringBillsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/programs',
        name: 'admin.tutoring.programs',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringProgramsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/programs/:programId',
        name: 'admin.tutoring.program-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringProgramDetailView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/programs/:programId/enroll',
        name: 'admin.tutoring.enroll',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringEnrollView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/assessments/:assessmentId',
        name: 'admin.tutoring.assessment-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringAssessmentDetailView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/billing-settings',
        name: 'admin.tutoring.billing-settings',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringBillingSettingsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/payouts',
        name: 'admin.tutoring.payouts',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringPayoutsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/leads',
        name: 'admin.tutoring.leads',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringLeadsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/vouchers',
        name: 'admin.tutoring.vouchers',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringVouchersView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/group-announcements',
        name: 'admin.tutoring.group-announcements',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringGroupAnnouncementsView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/tutoring/leaderboard',
        name: 'admin.tutoring.leaderboard',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringLeaderboardView.vue'),
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'teacher/tutoring/kelas',
        name: 'teacher.tutoring.classes',
        component: () =>
          import('@/views/teacher/tutoring/TutorKelasView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/kelas/:groupId',
        name: 'teacher.tutoring.class-detail',
        component: () =>
          import('@/views/teacher/tutoring/TutorKelasDetailView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/sessions',
        name: 'teacher.tutoring.sessions',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionsView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/sessions/:sessionId/attendance',
        name: 'teacher.tutoring.attendance',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionAttendanceView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/tryout-generator',
        name: 'teacher.tutoring.tryout-generator',
        component: () =>
          import('@/views/teacher/tutoring/TutorTryoutGenerateView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/sessions/new',
        name: 'teacher.tutoring.session-create',
        component: () =>
          import('@/views/teacher/tutoring/TutorCreateSessionView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/activities',
        name: 'teacher.tutoring.activities',
        component: () =>
          import('@/views/teacher/tutoring/TutorActivitiesView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/activities/:activityId/submissions',
        name: 'teacher.tutoring.activity-submissions',
        component: () =>
          import('@/views/teacher/tutoring/TutorActivitySubmissionsView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/earnings',
        name: 'teacher.tutoring.earnings',
        component: () =>
          import('@/views/teacher/tutoring/TutorEarningsView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/materials',
        name: 'teacher.tutoring.materials',
        component: () =>
          import('@/views/teacher/tutoring/TutorMaterialsView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        path: 'teacher/tutoring/recurring',
        name: 'teacher.tutoring.recurring',
        component: () =>
          import('@/views/teacher/tutoring/TutorRecurringSessionsView.vue'),
        meta: { role: 'guru' satisfies Role },
      },
      {
        // Tutor Tampilan — the light/dark mode picker for the bimbel
        // (tutor) surface. Route NAME contains "tutoring" so AppShell's
        // isBimbelRoute guard fires and the page renders on the bimbel
        // surface; it picks `bimbel-light` / `bimbel-dark` via the
        // useBimbelThemeStore state so the user can preview their choice
        // live on this very screen.
        path: 'teacher/tutoring/appearance',
        name: 'teacher.tutoring.appearance',
        component: () =>
          import('@/views/teacher/tutoring/TutorAppearanceView.vue'),
        meta: { role: 'guru' satisfies Role },
      },

      // Staff subtree (placeholder until staff feature surfaces are
      // confirmed — see task #51).
      {
        path: 'staff',
        name: 'staff.home',
        component: StaffStubView,
        meta: { role: 'staff' satisfies Role },
      },

      // Cross-role: profile + notifications
      {
        path: 'profile',
        name: 'profile',
        component: ProfileView,
      },
      {
        path: 'notifications',
        name: 'notifications',
        component: NotificationListView,
      },
    ],
  },

  // Catch-all
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  // Rehydrate from storage on first navigation if needed.
  if (!auth.isAuthenticated) auth.restore();

  // If the auth step is 'register_demo' the user has a valid token
  // but no school yet. Any non-public route should bounce to the
  // wizard rather than /login.
  if (auth.step === 'register_demo' && to.name !== 'register-demo' && to.meta.public !== true) {
    return { name: 'register-demo' };
  }

  const isPublic = to.meta.public === true;

  // Already logged in → skip /login entirely and go to dashboard.
  if (isPublic && to.path === '/login' && auth.isAuthenticated && auth.step === 'done') {
    return { path: '/' };
  }

  if (isPublic) return true;

  if (!auth.isAuthenticated) {
    return { path: '/login' };
  }

  const requiredRole = to.meta.role as Role | undefined;
  if (requiredRole && auth.activeRole) {
    // Teacher and wali_kelas share the /teacher subtree.
    const matches =
      requiredRole === auth.activeRole ||
      (requiredRole === 'guru' && auth.activeRole === 'wali_kelas') ||
      // A super-admin acts as `admin` for routing — the platform pages
      // (e.g. admin.demo-requests) live in the /admin subtree under
      // `meta.role: 'admin'`. Without this, a pure super-admin (whose
      // activeRole is 'super_admin', not 'admin') would never match an
      // admin route and bounce in a redirect loop on its own home.
      (requiredRole === 'admin' && auth.isSuperAdmin);
    if (!matches) {
      return { path: roleHomePath[auth.activeRole] ?? '/login' };
    }
  }

  // Super-admin-only routes (platform pages, e.g. demo-requests). The
  // backend EnsureSuperAdmin middleware is the authoritative gate; this
  // client guard just keeps a non-super-admin admin from landing on a
  // page they can't use (they'd only see 403s). Bounce to their home.
  if (to.meta.superAdmin === true && !auth.isSuperAdmin) {
    return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
  }

  return true;
});

/**
 * Recover from stale lazy-chunk failures after a new deploy.
 *
 * When a fresh build ships (Vercel), the previous hashed chunk filenames
 * (e.g. `RegisterDemoIdentityView-CgGh-UKk.js`) are purged. A browser still
 * running the OLD `index.html` then fails the dynamic `import()` on the next
 * navigation with "Failed to fetch dynamically imported module" — leaving the
 * user stuck (the exact error reported on "lanjut ke data diri").
 *
 * Here we detect that class of error and hard-navigate to the intended path
 * so the browser pulls the new `index.html` + current chunks. A sessionStorage
 * timestamp guards against a reload loop when the failure is genuinely
 * persistent (offline / server actually down) — at most one auto-reload per
 * 10s. The companion `vite:preloadError` handler in `main.ts` covers
 * preloads (vs navigation imports) using the same guard key.
 */
router.onError((error, to) => {
  const msg = String((error as Error | undefined)?.message ?? '');
  const isChunkLoadError =
    /Failed to fetch dynamically imported module/i.test(msg) ||
    /error loading dynamically imported module/i.test(msg) ||
    /Importing a module script failed/i.test(msg);
  if (!isChunkLoadError) return;

  const KEY = 'chunk-reload-at';
  const last = Number(sessionStorage.getItem(KEY) ?? '0');
  if (Date.now() - last < 10_000) return; // already tried recently — avoid a loop
  sessionStorage.setItem(KEY, String(Date.now()));

  window.location.assign(to?.fullPath ?? window.location.pathname);
});

export default router;
