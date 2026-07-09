/**
 * Vue Router — role-aware route table and auth guard.
 *
 * Route layout mirrors Flutter's `main.dart` routes:
 *   /login         → LoginView (no shell)
 *   /              → AppShell (wraps everything below)
 *     /admin/*     → admin role
 *     /teacher/*   → teacher (teacher / wali_kelas) role
 *     /parent/*    → parent (parent) role
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
import { useMeStore } from '@/stores/me';
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
const AdminAnnouncementsHub = () =>
  import('@/views/admin/AdminAnnouncementsHub.vue');
const AdminAnnouncementView = () =>
  import('@/views/admin/AdminAnnouncementView.vue');
const AdminStudentAttendanceHub = () =>
  import('@/views/admin/AdminStudentAttendanceHub.vue');
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
const AdminFinanceBillsView = () =>
  import('@/views/admin/AdminFinanceBillsView.vue');
const AdminFinancePaymentsView = () =>
  import('@/views/admin/AdminFinancePaymentsView.vue');
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
const AdminRolesView = () => import('@/views/admin/AdminRolesView.vue');
const AdminRoleDetailView = () =>
  import('@/views/admin/AdminRoleDetailView.vue');
const AdminDataManagementView = () =>
  import('@/views/admin/AdminDataManagementView.vue');
const AdminSchoolLevelSettingsView = () =>
  import('@/views/admin/AdminSchoolLevelSettingsView.vue');
const AdminAcademicYearsView = () =>
  import('@/views/admin/AdminAcademicYearsView.vue');
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
// Unified "Pengaturan Kehadiran" (Wave 2 IA refactor) — merges the old
// teacher-attendance settings tabs + the QR methods form into one
// 3-tab screen, mirroring mobile's AdminTeacherAttendanceSettingsScreen.
const AdminAttendanceConfigView = () =>
  import('@/views/admin/AdminAttendanceConfigView.vue');
// Gate QR + personnel cards (MR !226). Lazy so the qrcode.vue payload
// stays out of the main admin chunk.
const GateQrDisplayView = () =>
  import('@/views/admin/attendance/GateQrDisplayView.vue');
const PersonnelCardManagerView = () =>
  import('@/views/admin/attendance/PersonnelCardManagerView.vue');
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
const SuperAdminTenantModulesView = () =>
  import('@/views/super-admin/SuperAdminTenantModulesView.vue');
const SuperAdminBroadcastView = () =>
  import('@/views/super-admin/SuperAdminBroadcastView.vue');
const SuperAdminIncompleteRegistrationsView = () =>
  import('@/views/super-admin/SuperAdminIncompleteRegistrationsView.vue');
const SuperAdminSubscriptionApprovalsView = () =>
  import('@/views/super-admin/SuperAdminSubscriptionApprovalsView.vue');
const SuperAdminDiscountCodesView = () =>
  import('@/views/super-admin/SuperAdminDiscountCodesView.vue');
const SubscribeNewWizardView = () =>
  import('@/views/subscribe/SubscribeNewWizardView.vue');
const SubscribeAddonView = () =>
  import('@/views/subscribe/SubscribeAddonView.vue');
const ManageModulesView = () =>
  import('@/views/subscribe/ManageModulesView.vue');
const TeacherMyAttendanceHub = () =>
  import('@/views/teacher/TeacherMyAttendanceHub.vue');
const TeacherCheckInView = () =>
  import('@/views/teacher/TeacherCheckInView.vue');
const TeacherAttendanceHistoryView = () =>
  import('@/views/teacher/TeacherAttendanceHistoryView.vue');
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
const TeacherGradeMatrixView = () =>
  import('@/views/teacher/TeacherGradeMatrixView.vue');
const TeacherGradeRecapView = () =>
  import('@/views/teacher/TeacherGradeRecapView.vue');
const TeacherGradeRecapDetailView = () =>
  import('@/views/teacher/TeacherGradeRecapDetailView.vue');
const TeacherClassActivityView = () =>
  import('@/views/teacher/TeacherClassActivityView.vue');
const ClassHubListView = () => import('@/views/teacher/ClassHubListView.vue');
const ClassHubView = () => import('@/views/teacher/ClassHubView.vue');
const ParentClassHubListView = () =>
  import('@/views/parent/ParentClassHubListView.vue');
const ParentClassHubView = () =>
  import('@/views/parent/ParentClassHubView.vue');
const AdminClassOversightView = () =>
  import('@/views/admin/AdminClassOversightView.vue');
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
// Staff role home — a REAL self-attendance surface (F3), not a stub. The
// staff self check-in reuses the teacher check-in stack (staff-aware
// server-side, Phase C) under a staff-role route subtree.
const StaffHomeView = () => import('@/views/staff/StaffHomeView.vue');
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

  // ── /subscribe — tenant subscription flow ─────────────────────────
  // Publicly reachable: an unauthenticated visitor can open the page,
  // see pricing + the calculator, hit Google Sign-In (rendered inside
  // the signup card), and complete signup + payment in a single flow.
  // Authenticated users see their demo-tenant banner instead. The page
  // stands alone (no AppShell chrome) so the pricing hero + calculator
  // feel like a marketing surface rather than an app screen.
  {
    path: '/subscribe',
    name: 'subscribe',
    component: () => import('@/views/subscribe/SubscribeView.vue'),
    meta: { public: true },
  },
  {
    // Multi-step wizard for brand-new paid tenants (no demo, no seed
    // data). Distinct from /subscribe which handles the existing-demo
    // conversion path plus a one-page new-signup form.
    path: '/subscribe/new',
    name: 'subscribe-new',
    component: SubscribeNewWizardView,
    meta: { public: true },
  },
  {
    // Mid-cycle top-up. Requires an active subscription id in the
    // query string; the view rejects the load otherwise.
    path: '/subscribe/addon',
    name: 'subscribe-addon',
    component: SubscribeAddonView,
  },
  {
    // Admin self-service module management. Path matches the upgrade_url
    // the kamiledu-ai EnsureAiModuleEntitled middleware emits on 402, so
    // clicking "upgrade" on a locked AI feature lands here directly.
    // Requires a signed-in user + an active subscription for the scoped
    // tenant; empty-state renders when neither is true.
    path: '/subscribe/manage-modules',
    name: 'subscribe-manage-modules',
    component: ManageModulesView,
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
        meta: { role: 'admin' satisfies Role, needs: 'student-context' },
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
        meta: { role: 'admin' satisfies Role, needs: 'student-context' },
      },
      {
        // Class-first read-only oversight (distinct from the class-management
        // screen above, which stays at admin.classes / "Kelas").
        path: 'admin/class-oversight',
        name: 'admin.class-oversight',
        component: AdminClassOversightView,
        meta: { role: 'admin' satisfies Role, ability: 'school.class.view' },
      },
      {
        path: 'admin/class-oversight/:id',
        name: 'admin.class-oversight.detail',
        component: ClassHubView,
        props: (route) => ({ id: route.params.id, roleName: 'admin' }),
        meta: { role: 'admin' satisfies Role, ability: 'activity.view' },
      },
      {
        path: 'admin/subjects',
        name: 'admin.subjects',
        component: AdminSubjectManagementView,
        meta: { role: 'admin' satisfies Role, needs: 'academic-context' },
      },
      {
        path: 'admin/subjects/:subjectId/classes',
        name: 'admin.subjects.classes',
        component: AdminSubjectClassManagementView,
        meta: { role: 'admin' satisfies Role, needs: 'academic-context' },
      },
      {
        path: 'admin/lesson-plans',
        name: 'admin.lesson-plans',
        component: AdminLessonPlanReviewView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.lesson_plan.view' },
      },
      {
        path: 'admin/lesson-plans/:id',
        name: 'admin.lesson-plans.detail',
        component: AdminLessonPlanDetailView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.lesson_plan.view' },
      },
      {
        path: 'admin/schedule',
        name: 'admin.schedule',
        component: AdminScheduleManagementView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.schedule.view' },
      },
      {
        path: 'admin/schedule/lesson-hours',
        name: 'admin.schedule.lesson-hours',
        component: AdminLessonHourSettingsView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.schedule.view' },
      },
      {
        // Wave 4 IA merge — Pengumuman hub: "Daftar" + "Kalender" as sibling
        // tabs under one parent. AdminAnnouncementsHub renders a tab bar above
        // <router-view>; the two former standalone views become children with
        // their route names preserved, so all cross-navigation between them
        // keeps working and the sidebar entry (/admin/announcements) still lands
        // on the list tab.
        path: 'admin/announcements',
        component: AdminAnnouncementsHub,
        meta: { role: 'admin' satisfies Role, ability: 'communication.announcement.view' },
        children: [
          {
            path: '',
            name: 'admin.announcements',
            component: AdminAnnouncementView,
            meta: { role: 'admin' satisfies Role, ability: 'communication.announcement.view' },
          },
          {
            path: 'calendar',
            name: 'admin.announcements.calendar',
            component: AdminAnnouncementCalendarView,
            meta: { role: 'admin' satisfies Role, ability: 'communication.announcement.view' },
          },
        ],
      },
      {
        // Wave 4 IA merge — Kehadiran Siswa hub: "Ringkasan" (dashboard) +
        // "Laporan" + "Detail" as sibling tabs under one parent. The three
        // former standalone routes become children with their names preserved
        // (report/detail cross-navigate via named routes + query params, which
        // stay intact). The grade-level heatmap remains a standalone drill-down
        // route below — it is a parametric :tingkat view, not a sibling tab.
        path: 'admin/student-attendance',
        component: AdminStudentAttendanceHub,
        meta: {
          role: 'admin' satisfies Role,
          abilityAny: ['attendance.student.view', 'attendance.student.export'],
        },
        children: [
          {
            path: '',
            name: 'admin.student-attendance',
            component: AdminAttendanceDashboardView,
            meta: {
              role: 'admin' satisfies Role,
              abilityAny: ['attendance.student.view', 'attendance.student.export'],
            },
          },
          {
            path: 'report',
            name: 'admin.student-attendance.report',
            component: AdminAttendanceReportView,
            meta: {
              role: 'admin' satisfies Role,
              abilityAny: ['attendance.student.view', 'attendance.student.export'],
            },
          },
          {
            path: 'detail',
            name: 'admin.student-attendance.detail',
            component: AdminAttendanceDetailView,
            meta: {
              role: 'admin' satisfies Role,
              abilityAny: ['attendance.student.view', 'attendance.student.export'],
            },
          },
        ],
      },
      {
        // Grade-level heatmap — parametric drill-down (kept standalone, NOT a
        // hub tab). Reached from the dashboard's tingkat cards.
        path: 'admin/student-attendance/grade-level/:tingkat',
        name: 'admin.student-attendance.grade-level',
        component: AdminAttendanceTingkatHeatmapView,
        meta: {
          role: 'admin' satisfies Role,
          abilityAny: ['attendance.student.view', 'attendance.student.export'],
        },
      },
      {
        path: 'admin/class-activity',
        name: 'admin.class-activity',
        component: AdminClassActivityView,
        meta: { role: 'admin' satisfies Role, ability: 'activity.view' },
      },
      {
        path: 'admin/finance',
        component: AdminFinanceView,
        meta: { role: 'admin' satisfies Role, ability: 'finance.bill.view' },
        redirect: { name: 'admin.finance.bills' },
        children: [
          {
            path: 'bills',
            name: 'admin.finance.bills',
            component: AdminFinanceBillsView,
            meta: { role: 'admin' satisfies Role, ability: 'finance.bill.view' },
          },
          {
            path: 'payments',
            name: 'admin.finance.payments',
            component: AdminFinancePaymentsView,
            meta: { role: 'admin' satisfies Role, ability: 'finance.payment.view' },
          },
          {
            path: 'types',
            name: 'admin.finance.types',
            component: AdminFinanceJenisView,
            meta: { role: 'admin' satisfies Role, ability: 'finance.bill_type.manage' },
          },
        ],
      },
      {
        // Back-compat redirect — existing menu items use `admin.finance`.
        path: 'admin/finance/index',
        name: 'admin.finance',
        redirect: { name: 'admin.finance.bills' },
      },
      {
        path: 'admin/finance/bills/:classId/:paymentTypeId',
        name: 'admin.finance.bills.detail',
        component: AdminFinanceBillGroupDetailView,
        meta: { role: 'admin' satisfies Role, ability: 'finance.bill.view' },
      },
      {
        path: 'admin/finance/class/:classId',
        name: 'admin.finance.class',
        component: AdminClassFinanceReportView,
        meta: { role: 'admin' satisfies Role, ability: 'finance.bill.view' },
      },
      {
        path: 'admin/grades',
        name: 'admin.grades',
        component: AdminGradeOverviewView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.grade.view' },
      },
      {
        path: 'admin/grade-recap',
        name: 'admin.grade-recap',
        component: AdminGradeRecapView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.grade.recap.view' },
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
        meta: { role: 'admin' satisfies Role, ability: 'academic.grade.recap.view' },
      },
      {
        // Admin matrix drill — parallels `teacher.grades.matrix` but
        // under the admin role gate so an admin clicking a subject
        // card in the read-only teacher gradebook doesn't get bounced
        // by the `role: 'guru'` guard from the sibling teacher route.
        // The component reads `teacherId` + `admin_view=1` the same
        // way `admin.grades.teacher` below does, so read-only
        // affordances stay in place. `openMatrix()` in the view
        // route-detects `isAdminView` and picks between this route
        // and the teacher one.
        //
        // Route ordering matters — this more-specific path must sit
        // BEFORE the `:teacherId?` variant below so vue-router picks
        // it up first when both `:classId` + `:subjectId` are present.
        path: 'admin/grades/teacher/:teacherId/:classId/:subjectId',
        name: 'admin.grades.teacher.matrix',
        component: TeacherGradeMatrixView,
        props: true,
        meta: { role: 'admin' satisfies Role, ability: 'academic.grade.view' },
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
        meta: { role: 'admin' satisfies Role, ability: 'academic.grade.view' },
      },
      {
        path: 'admin/report-cards',
        name: 'admin.report-cards',
        component: AdminReportCardHubView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'admin/report-cards/class/:classId',
        name: 'admin.report-cards.class',
        component: AdminReportCardClassView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'admin/report-cards/class/:classId/student/:studentClassId',
        name: 'admin.report-cards.detail',
        component: AdminReportCardDetailView,
        meta: { role: 'admin' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'admin/settings',
        name: 'admin.settings',
        component: AdminSettingsView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        path: 'admin/roles',
        name: 'admin-roles',
        component: AdminRolesView,
        // Route ability gate — RBAC is a paid/optional module. Without
        // this, any admin whose tenant hasn't entitled RBAC could
        // navigate to the roles list; backend rejects mutations via
        // Gate::before but the UI leaked the list. Aligned with the
        // nav menu, which already filters this entry by the same key.
        meta: {
          role: 'admin' satisfies Role,
          ability: 'rbac.role.view',
        },
      },
      {
        path: 'admin/roles/:roleId',
        name: 'admin-role-detail',
        component: AdminRoleDetailView,
        props: true,
        meta: {
          role: 'admin' satisfies Role,
          ability: 'rbac.role.view',
        },
      },
      {
        // Kelola Modul & Paket — embedded IN the admin shell so the
        // Pengaturan hub tile keeps the sidebar + shell chrome instead
        // of teleporting to the standalone /subscribe surface. Same
        // component, `embedded` prop suppresses its own top bar.
        // /subscribe/manage-modules stays as the out-of-shell entry
        // (topbar chip, mobile deep-link, AI 402 upgrade_url).
        path: 'admin/settings/modules',
        name: 'admin.settings.modules',
        component: ManageModulesView,
        props: { embedded: true },
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
        path: 'admin/settings/manage-academic-years',
        name: 'admin.settings.manage-academic-years',
        component: AdminAcademicYearsView,
        meta: { role: 'admin' satisfies Role },
      },
      {
        // PRESENSI GURU — admin config + report for teacher daily
        // attendance (camera/location/geofence settings + report list).
        path: 'admin/teacher-attendance/report',
        name: 'admin.teacher-attendance.report',
        component: AdminTeacherAttendanceView,
        meta: { role: 'admin' satisfies Role, ability: 'attendance.staff.report.view' },
      },
      {
        // Unified "Pengaturan Kehadiran" — Wave 2 IA refactor. ONE
        // screen for everything that PUTs /teacher-attendance/settings
        // (selfie/GPS/QR methods, geofence, rotation, time rules).
        path: 'admin/settings/attendance',
        name: 'admin.settings.attendance',
        component: AdminAttendanceConfigView,
        meta: { role: 'admin' satisfies Role, ability: 'attendance.staff.settings.manage' },
      },
      {
        // LEGACY redirect — the settings mode of the old teacher-
        // attendance screen moved into the unified attendance config.
        // Keep for old bookmarks.
        path: 'admin/teacher-attendance/settings',
        redirect: { name: 'admin.settings.attendance' },
      },

      // ── Gate QR + personnel cards (MR !226) ───────────────────────
      // Distinct from the existing presensi-guru pages: these surfaces
      // configure + drive the QR_GATE / QR_CARD check-in methods. The
      // `meta.ability` value names the RBAC token (backend MR !225);
      // the router guard maps it to `auth.hasAbility(...)` and bounces
      // a non-permitted admin home. Authoritative gate is server-side.
      {
        path: 'admin/attendance/gate-qr',
        name: 'admin.attendance.gate-qr',
        component: GateQrDisplayView,
        meta: {
          role: 'admin' satisfies Role,
          ability: 'attendance.gate_qr.manage',
        },
      },
      {
        // LEGACY redirect — the QR methods form merged into the unified
        // attendance config (Wave 2). Keep for old bookmarks.
        path: 'admin/attendance/settings',
        redirect: { name: 'admin.settings.attendance' },
      },
      {
        path: 'admin/attendance/cards',
        name: 'admin.attendance.cards',
        component: PersonnelCardManagerView,
        meta: {
          role: 'admin' satisfies Role,
          ability: 'attendance.cards.issue',
        },
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
        // Modular-SaaS super-admin surface — grant/revoke/comp modules
        // on any tenant. Backed by /billing/admin/tenants/*/modules.
        path: 'super-admin/tenant-modules',
        name: 'super-admin.tenant-modules',
        component: SuperAdminTenantModulesView,
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
      {
        // Manual-transfer subscription verification queue. Every row is
        // an `awaiting_verify` subscription — customer claims to have
        // transferred, KamilEdu bendahara must reconcile against BSI
        // mutation history before approving.
        path: 'super-admin/subscription-approvals',
        name: 'super-admin.subscription-approvals',
        component: SuperAdminSubscriptionApprovalsView,
        meta: { superAdmin: true },
      },
      {
        // Discount code catalog CRUD. Backed by
        // /billing/admin/discount-codes/* (super_admin-gated).
        path: 'super-admin/discount-codes',
        name: 'super-admin.discount-codes',
        component: SuperAdminDiscountCodesView,
        meta: { superAdmin: true },
      },

      // Teacher / Homeroom Teacher subtree
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
        // attendance ("kehadiran student"). Named "my-attendance" so the
        // English path doesn't collide with that student route.
        //
        // Wave 4 IA merge — hosted under TeacherMyAttendanceHub which renders
        // a "Presensi" / "Riwayat" tab bar above <router-view>. The check-in
        // and history views become children with their names/paths preserved,
        // so the sidebar entry (/teacher/my-attendance) and the two views'
        // mutual navigation keep working.
        path: 'teacher/my-attendance',
        component: TeacherMyAttendanceHub,
        meta: { role: 'guru' satisfies Role, ability: 'attendance.self.view_own' },
        children: [
          {
            path: '',
            name: 'teacher.my-attendance',
            component: TeacherCheckInView,
            meta: { role: 'guru' satisfies Role, ability: 'attendance.self.view_own' },
          },
          {
            path: 'history',
            name: 'teacher.my-attendance.history',
            component: TeacherAttendanceHistoryView,
            meta: { role: 'guru' satisfies Role, ability: 'attendance.self.view_own' },
          },
        ],
      },
      {
        path: 'teacher/attendance',
        name: 'teacher.attendance',
        component: TeacherAttendanceView,
        meta: { role: 'guru' satisfies Role, abilityAny: ['attendance.student.submit', 'attendance.student.view'] },
      },
      {
        path: 'teacher/attendance/detail',
        name: 'teacher.attendance.detail',
        component: TeacherAttendanceDetailView,
        meta: { role: 'guru' satisfies Role, abilityAny: ['attendance.student.submit', 'attendance.student.view'] },
      },
      {
        path: 'teacher/attendance/input',
        name: 'teacher.attendance.input',
        component: TeacherAttendanceInputView,
        meta: { role: 'guru' satisfies Role, ability: 'attendance.student.submit' },
      },
      {
        path: 'teacher/grades',
        name: 'teacher.grades',
        component: TeacherGradeBookView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.grade.input' },
      },
      {
        // Matrix mode — drilled into from a subject-class card on the
        // gradebook grid. Shares the TeacherGradeBookView component
        // with the list route; the view watches route.params to
        // decide whether to render summary or matrix. Parallels the
        // grade-recap detail route below so bookmarks + browser back
        // + refresh-on-matrix all behave the way teachers expect.
        path: 'teacher/grades/:classId/:subjectId',
        name: 'teacher.grades.matrix',
        component: TeacherGradeMatrixView,
        props: true,
        meta: { role: 'guru' satisfies Role, ability: 'academic.grade.input' },
      },
      {
        path: 'teacher/grade-recap',
        name: 'teacher.grade-recap',
        component: TeacherGradeRecapView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.grade.recap.view' },
      },
      {
        // Detail / matrix mode — drilled into from a recap card.
        path: 'teacher/grade-recap/:classId/:subjectId',
        name: 'teacher.grade-recap.detail',
        component: TeacherGradeRecapDetailView,
        props: true,
        meta: { role: 'guru' satisfies Role, ability: 'academic.grade.recap.view' },
      },
      {
        path: 'teacher/classes',
        name: 'teacher.classes',
        component: ClassHubListView,
        meta: { role: 'guru' satisfies Role, ability: 'school.class.view' },
      },
      {
        path: 'teacher/classes/:id',
        name: 'teacher.classes.detail',
        component: ClassHubView,
        props: true,
        meta: { role: 'guru' satisfies Role, ability: 'activity.view' },
      },
      {
        path: 'teacher/class-activity',
        name: 'teacher.class-activity',
        component: TeacherClassActivityView,
        meta: { role: 'guru' satisfies Role, ability: 'activity.view' },
      },
      {
        path: 'teacher/materials',
        name: 'teacher.materials',
        component: TeacherMaterialView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.material.view' },
      },
      {
        path: 'teacher/lesson-plans',
        name: 'teacher.lesson-plans',
        component: TeacherLessonPlanView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.lesson_plan.view' },
      },
      {
        path: 'teacher/lesson-plans/:id',
        name: 'teacher.lesson-plans.detail',
        component: TeacherLessonPlanDetailView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.lesson_plan.view' },
      },
      {
        path: 'teacher/recommendations',
        name: 'teacher.recommendations',
        component: TeacherRecommendationView,
        meta: { role: 'guru' satisfies Role, abilityAny: ['communication.recommendation.view', 'communication.recommendation.create'] },
      },
      {
        path: 'teacher/recommendations/class/:classId',
        name: 'teacher.recommendations.students',
        component: TeacherRecommendationStudentsView,
        meta: { role: 'guru' satisfies Role, abilityAny: ['communication.recommendation.view', 'communication.recommendation.create'] },
      },
      {
        path: 'teacher/recommendations/class/:classId/student/:studentId',
        name: 'teacher.recommendations.result',
        component: TeacherRecommendationResultView,
        meta: { role: 'guru' satisfies Role, abilityAny: ['communication.recommendation.view', 'communication.recommendation.create'] },
      },
      {
        path: 'teacher/recommendations/edit/:recId',
        name: 'teacher.recommendations.edit',
        component: TeacherRecommendationEditView,
        meta: { role: 'guru' satisfies Role, ability: 'communication.recommendation.create' },
      },
      {
        path: 'teacher/schedule',
        name: 'teacher.schedule',
        component: TeacherScheduleView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.schedule.view' },
      },
      {
        path: 'teacher/announcements',
        name: 'teacher.announcements',
        component: TeacherAnnouncementView,
        meta: { role: 'guru' satisfies Role, ability: 'communication.announcement.view' },
      },
      {
        path: 'teacher/report-cards',
        name: 'teacher.report-cards',
        component: TeacherReportCardHubView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'teacher/report-cards/class/:classId',
        name: 'teacher.report-cards.class',
        component: TeacherReportCardClassView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'teacher/report-cards/class/:classId/student/:studentClassId',
        name: 'teacher.report-cards.detail',
        component: TeacherReportCardDetailView,
        meta: { role: 'guru' satisfies Role, ability: 'academic.report_card.view' },
      },

      // Parent / Parent subtree
      {
        path: 'parent',
        name: 'parent.home',
        component: ParentDashboardView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/classes',
        name: 'parent.classes',
        component: ParentClassHubListView,
        meta: { role: 'wali' satisfies Role },
      },
      {
        path: 'parent/classes/:id',
        name: 'parent.classes.detail',
        component: ParentClassHubView,
        props: true,
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
        meta: { role: 'wali' satisfies Role, ability: 'finance.bill.view_own' },
      },
      {
        path: 'parent/billing/checkout/:billId',
        name: 'parent.bill-checkout',
        component: ParentBillCheckoutView,
        meta: { role: 'wali' satisfies Role, ability: 'finance.bill.view_own' },
      },
      {
        path: 'parent/billing/success/:paymentId',
        name: 'parent.payment-success',
        component: ParentPaymentSuccessView,
        meta: { role: 'wali' satisfies Role, ability: 'finance.bill.view_own' },
      },
      {
        path: 'parent/attendance',
        name: 'parent.attendance',
        component: ParentAttendanceView,
        meta: { role: 'wali' satisfies Role, ability: 'attendance.student.view_own' },
      },
      {
        path: 'parent/attendance/calendar',
        name: 'parent.attendance.calendar',
        component: ParentAttendanceCalendarView,
        meta: { role: 'wali' satisfies Role, ability: 'attendance.student.view_own' },
      },
      {
        path: 'parent/grades',
        name: 'parent.grades',
        component: ParentGradeView,
        meta: { role: 'wali' satisfies Role, ability: 'academic.grade.view' },
      },
      {
        path: 'parent/class-activity',
        name: 'parent.class-activity',
        component: ParentClassActivityView,
        meta: { role: 'wali' satisfies Role, ability: 'activity.view' },
      },
      {
        path: 'parent/report-cards',
        name: 'parent.report-cards',
        component: ParentReportCardView,
        meta: { role: 'wali' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'parent/report-cards/:studentClassId',
        name: 'parent.report-cards.detail',
        component: ParentReportCardDetailView,
        meta: { role: 'wali' satisfies Role, ability: 'academic.report_card.view' },
      },
      {
        path: 'parent/announcements',
        name: 'parent.announcements',
        component: ParentAnnouncementView,
        meta: { role: 'wali' satisfies Role, ability: 'communication.announcement.view' },
      },
      {
        path: 'parent/recommendations',
        name: 'parent.recommendations',
        component: ParentRecommendationView,
        meta: { role: 'wali' satisfies Role, ability: 'communication.recommendation.view' },
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
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/classes',
        name: 'parent.tutoring.classes',
        component: () => import('@/views/parent/tutoring/ParentClassesView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/classes/:groupId',
        name: 'parent.tutoring.class-detail',
        component: () =>
          import('@/views/parent/tutoring/ParentClassDetailView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/sessions',
        name: 'parent.tutoring.sessions',
        component: () => import('@/views/parent/tutoring/ParentSessionsView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/bills',
        name: 'parent.tutoring.bills',
        component: () => import('@/views/parent/tutoring/ParentBillsView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/bills/:billId/pay',
        name: 'parent.tutoring.pay-bill',
        component: () =>
          import('@/views/parent/tutoring/ParentPayBillView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/activities',
        name: 'parent.tutoring.activities',
        component: () =>
          import('@/views/parent/tutoring/ParentActivitiesView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/progress',
        name: 'parent.tutoring.progress',
        component: () => import('@/views/parent/tutoring/ParentProgressView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/voucher',
        name: 'parent.tutoring.vouchers',
        component: () =>
          import('@/views/parent/tutoring/ParentVouchersView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/leaderboard',
        name: 'parent.tutoring.leaderboard',
        component: () =>
          import('@/views/parent/tutoring/ParentLeaderboardView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/:studentId/announcements',
        name: 'parent.tutoring.announcements',
        component: () =>
          import('@/views/parent/tutoring/ParentAnnouncementsView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/notifikasi',
        name: 'parent.tutoring.notifications',
        component: () =>
          import('@/views/parent/tutoring/ParentNotificationsView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/lainnya',
        name: 'parent.tutoring.more',
        component: () =>
          import('@/views/parent/tutoring/ParentMoreView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/profil',
        name: 'parent.tutoring.profile',
        component: () => import('@/views/parent/tutoring/ParentProfileView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/profil/ubah-sandi',
        name: 'parent.tutoring.change-password',
        component: () =>
          import('@/views/parent/tutoring/ParentChangePasswordView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/tampilan',
        name: 'parent.tutoring.appearance',
        component: () =>
          import('@/views/parent/tutoring/ParentAppearanceView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/daftar-calon',
        name: 'parent.tutoring.register-lead',
        component: () =>
          import('@/views/parent/tutoring/ParentRegisterLeadView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'parent/tutoring/daftar-anak',
        name: 'parent.tutoring.enroll-new',
        component: () =>
          import('@/views/parent/tutoring/ParentEnrollWizardView.vue'),
        meta: { role: 'wali' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring',
        name: 'admin.tutoring.dashboard',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringDashboardView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/sessions',
        name: 'admin.tutoring.sessions',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringSessionsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        // Admin-scoped view of a single session: roster + attendance
        // (read-write for admin) + catatan session. Reuses the tutor's
        // attendance component because the backend already gates by
        // tenant + role; the only difference is the URL prefix so the
        // 'teacher'-only router guard doesn't bounce the admin.
        path: 'admin/tutoring/sessions/:sessionId/attendance',
        name: 'admin.tutoring.session-attendance',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionAttendanceView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/students',
        name: 'admin.tutoring.students',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringStudentsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/tutors',
        name: 'admin.tutoring.tutors',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringTutorsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/tutors/:userId',
        name: 'admin.tutoring.tutor-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringTutorDetailView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/bills',
        name: 'admin.tutoring.bills',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringBillsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/programs',
        name: 'admin.tutoring.programs',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringProgramsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/programs/:programId',
        name: 'admin.tutoring.program-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringProgramDetailView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/programs/:programId/enroll',
        name: 'admin.tutoring.enroll',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringEnrollView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        // Standalone enroll route — used from the Student list where the
        // admin hasn't picked a program yet. The wizard picks program
        // + package in step 2.
        path: 'admin/tutoring/enroll',
        name: 'admin.tutoring.enroll-any',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringEnrollView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/assessments/:assessmentId',
        name: 'admin.tutoring.assessment-detail',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringAssessmentDetailView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/billing-settings',
        name: 'admin.tutoring.billing-settings',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringBillingSettingsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/session-reminders',
        name: 'admin.tutoring.session-reminders',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringSessionReminderSettingsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/payouts',
        name: 'admin.tutoring.payouts',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringPayoutsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/payout-requests',
        name: 'admin.tutoring.payout-requests',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringPayoutRequestsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/payout-settings',
        name: 'admin.tutoring.payout-settings',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringPayoutSettingsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/leads',
        name: 'admin.tutoring.leads',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringLeadsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/vouchers',
        name: 'admin.tutoring.vouchers',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringVouchersView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/group-announcements',
        name: 'admin.tutoring.group-announcements',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringGroupAnnouncementsView.vue'),
        meta: {
          role: 'admin' satisfies Role,
          needs: 'tutoring-module',
          ability: 'tutoring.announcement.view',
        },
      },
      {
        path: 'admin/tutoring/leaderboard',
        name: 'admin.tutoring.leaderboard',
        component: () =>
          import('@/views/admin/tutoring/AdminTutoringLeaderboardView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/groups',
        name: 'admin.tutoring.groups',
        component: () => import('@/views/admin/tutoring/AdminTutoringGroupsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/groups/:groupId',
        name: 'admin.tutoring.group-detail',
        component: () => import('@/views/admin/tutoring/AdminTutoringGroupDetailView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/reports/activity',
        name: 'admin.tutoring.report-activity',
        component: () => import('@/views/admin/tutoring/AdminTutoringActivityReportView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/reports/attendance',
        name: 'admin.tutoring.report-attendance',
        component: () => import('@/views/admin/tutoring/AdminTutoringAttendanceReportView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/profile',
        name: 'admin.tutoring.profile',
        component: () => import('@/views/admin/tutoring/AdminTutoringProfileView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/profile/change-password',
        name: 'admin.tutoring.change-password',
        component: () => import('@/views/admin/tutoring/AdminTutoringChangePasswordView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/appearance',
        name: 'admin.tutoring.appearance',
        component: () => import('@/views/admin/tutoring/AdminTutoringAppearanceView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'admin/tutoring/notifications',
        name: 'admin.tutoring.notifications',
        component: () => import('@/views/admin/tutoring/AdminTutoringNotificationsView.vue'),
        meta: { role: 'admin' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/class',
        name: 'teacher.tutoring.classes',
        component: () =>
          import('@/views/teacher/tutoring/TutorClassesView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/class/:groupId',
        name: 'teacher.tutoring.class-detail',
        component: () =>
          import('@/views/teacher/tutoring/TutorClassDetailView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/sessions',
        name: 'teacher.tutoring.sessions',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/sessions/:sessionId/attendance',
        name: 'teacher.tutoring.attendance',
        component: () =>
          import('@/views/teacher/tutoring/TutorSessionAttendanceView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/tryout-generator',
        name: 'teacher.tutoring.tryout-generator',
        component: () =>
          import('@/views/teacher/tutoring/TutorTryoutGenerateView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/sessions/new',
        name: 'teacher.tutoring.session-create',
        component: () =>
          import('@/views/teacher/tutoring/TutorCreateSessionView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/activities',
        name: 'teacher.tutoring.activities',
        component: () =>
          import('@/views/teacher/tutoring/TutorActivitiesView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/activities/:activityId/submissions',
        name: 'teacher.tutoring.activity-submissions',
        component: () =>
          import('@/views/teacher/tutoring/TutorActivitySubmissionsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/earnings',
        name: 'teacher.tutoring.earnings',
        component: () =>
          import('@/views/teacher/tutoring/TutorEarningsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/materials',
        name: 'teacher.tutoring.materials',
        component: () =>
          import('@/views/teacher/tutoring/TutorMaterialsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/recurring',
        name: 'teacher.tutoring.recurring',
        component: () =>
          import('@/views/teacher/tutoring/TutorRecurringSessionsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        // Tutor Appearance — the light/dark mode picker for the bimbel
        // (tutor) surface. Route NAME contains "tutoring" so AppShell's
        // isTutoringRoute guard fires and the page renders on the bimbel
        // surface; it picks `tutoring-light` / `tutoring-dark` via the
        // useTutoringThemeStore state so the user can preview their choice
        // live on this very screen.
        path: 'teacher/tutoring/appearance',
        name: 'teacher.tutoring.appearance',
        component: () =>
          import('@/views/teacher/tutoring/TutorAppearanceView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/profile',
        name: 'teacher.tutoring.profile',
        component: () => import('@/views/teacher/tutoring/TutorProfileView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/profile/change-password',
        name: 'teacher.tutoring.change-password',
        component: () => import('@/views/teacher/tutoring/TutorChangePasswordView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/ratings',
        name: 'teacher.tutoring.ratings',
        component: () => import('@/views/teacher/tutoring/TutorRatingsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/notifications',
        name: 'teacher.tutoring.notifications',
        component: () => import('@/views/teacher/tutoring/TutorNotificationsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/announcements',
        name: 'teacher.tutoring.announcements',
        component: () => import('@/views/teacher/tutoring/TutorAnnouncementsView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },
      {
        path: 'teacher/tutoring/leaderboard',
        name: 'teacher.tutoring.leaderboard',
        component: () => import('@/views/teacher/tutoring/TutorLeaderboardView.vue'),
        meta: { role: 'guru' satisfies Role, needs: 'tutoring-module' },
      },

      // Staff subtree (F3). The `staff` role now has a REAL web
      // self-service surface: self-attendance check-in. The check-in +
      // history views are the SAME components teachers use — the
      // /teacher-attendance endpoints are staff-aware server-side
      // (Phase C: the backend resolves the caller as teacher OR staff
      // and writes the correct personnel_type row), so no separate
      // endpoint or duplicate view is invented. Route NAME `staff.home`
      // is preserved for bookmarks.
      {
        path: 'staff',
        name: 'staff.home',
        component: StaffHomeView,
        meta: { role: 'staff' satisfies Role },
      },
      {
        // Staff · Presensi Saya — mirrors teacher/my-attendance but under
        // the staff role guard. Same hub + check-in + history components,
        // same `attendance.self.view_own` ability gate.
        path: 'staff/my-attendance',
        component: TeacherMyAttendanceHub,
        meta: { role: 'staff' satisfies Role, ability: 'attendance.self.view_own' },
        children: [
          {
            path: '',
            name: 'staff.my-attendance',
            component: TeacherCheckInView,
            meta: { role: 'staff' satisfies Role, ability: 'attendance.self.view_own' },
          },
          {
            path: 'history',
            name: 'staff.my-attendance.history',
            component: TeacherAttendanceHistoryView,
            meta: { role: 'staff' satisfies Role, ability: 'attendance.self.view_own' },
          },
        ],
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

router.beforeEach(async (to) => {
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

  // ── /me hydration before the ability / module gates ──────────────
  // The checks below read the GET /me snapshot (via `auth.hasAbility` +
  // the me store's context flags). On a HARD REFRESH that snapshot
  // starts null — it is NOT persisted, it's fetched from /me after the
  // app boots — so evaluating the gates against empty data would DENY
  // every gated sub-route and bounce the user back to their role home.
  // That's the "refresh always returns to /teacher" bug, and it hit
  // every role (admin/parent/bimbel routes are gated the same way).
  //
  // Await one (coalesced) /me fetch here so the gates see real data.
  // In-app navigations already have the snapshot loaded, so this is a
  // no-op after the first load. If the fetch fails, we SKIP the
  // client-side gates entirely and defer to the authoritative
  // server-side gate rather than misrouting the user.
  const me = useMeStore();
  if (auth.step === 'done' && me.snapshot === null) {
    try {
      await me.refresh();
    } catch {
      /* network hiccup — fall through to the skip below */
    }
  }
  // No snapshot (fetch failed / still booting) → don't gate client-side.
  if (me.snapshot === null) return true;

  // Per-permission guard (RBAC Phase A — backend MR !225). Routes that
  // need a specific ability set `meta.ability = 'attendance.gate_qr.manage'`
  // (or similar). The authoritative gate stays server-side; this just
  // avoids dropping a school admin onto a page that's going to 403.
  const requiredAbility = to.meta.ability as string | undefined;
  if (requiredAbility && !auth.hasAbility(requiredAbility)) {
    return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
  }

  // "Any of" ability gate. Same intent as `ability` — a single route
  // sometimes legitimately covers two flows (e.g. admin absensi is
  // useful to a tenant with EITHER attendance_class OR attendance_gate
  // alone). Passes if the user holds at least one.
  const requiredAny = to.meta.abilityAny as readonly string[] | undefined;
  if (requiredAny && !requiredAny.some((a) => auth.hasAbility(a))) {
    return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
  }

  // Module-context gate. `needs: 'student-context'` on a route means:
  // route only makes sense if the tenant owns any module that uses
  // students (attendance_class, grades, finance, etc.). Same for
  // `academic-context` (grades/lms/schedule etc use subjects). Uses
  // the me store's derived flags so the router agrees with useNavMenu.
  const needs = to.meta.needs as
    | 'student-context'
    | 'academic-context'
    | 'tutoring-module'
    | undefined;
  if (needs) {
    if (needs === 'student-context' && !me.hasStudentContext) {
      return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
    }
    if (needs === 'academic-context' && !me.hasAcademicContext) {
      return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
    }
    if (needs === 'tutoring-module' && !me.hasTutoringContext) {
      return { path: roleHomePath[auth.activeRole ?? ''] ?? '/login' };
    }
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
