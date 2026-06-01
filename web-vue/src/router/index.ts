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
import type { Role } from '@/types/auth';

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
const TeacherDashboardView = () =>
  import('@/views/teacher/TeacherDashboardView.vue');
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
  {
    path: '/register-demo',
    name: 'register-demo',
    component: () => import('@/views/register-demo/RegisterDemoView.vue'),
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

      // Teacher / Wali Kelas subtree
      {
        path: 'teacher',
        name: 'teacher.home',
        component: TeacherDashboardView,
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
  if (isPublic) return true;

  if (!auth.isAuthenticated) {
    return { path: '/login' };
  }

  const requiredRole = to.meta.role as Role | undefined;
  if (requiredRole && auth.activeRole) {
    // Teacher and wali_kelas share the /teacher subtree.
    const matches =
      requiredRole === auth.activeRole ||
      (requiredRole === 'guru' && auth.activeRole === 'wali_kelas');
    if (!matches) {
      return { path: roleHomePath[auth.activeRole] ?? '/login' };
    }
  }

  return true;
});

export default router;
