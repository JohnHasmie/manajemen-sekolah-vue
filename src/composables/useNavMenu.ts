/**
 * useNavMenu — returns the sidebar nav items for the active role.
 *
 * Mirrors Flutter's role-specific dashboard menu trees from
 * `lib/features/dashboard/presentation/screens/dashboard_screen.dart`.
 *
 * Each menu item has:
 *   - to:       Vue Router target path
 *   - labelKey: i18n key for the label
 *   - icon:     lucide-style SVG name (rendered by NavIcon.vue)
 *   - badge?:   notification count slot (resolved by the shell)
 */
import { computed, type ComputedRef } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useTenant } from '@/composables/useTenant';
import type { Role } from '@/types/auth';

export interface NavItem {
  to: string;
  labelKey: string;
  icon: string;
  badge?: number;
}

export interface NavSection {
  /** i18n key for the section heading, or empty string for an unlabeled group. */
  titleKey: string;
  items: NavItem[];
}

const ADMIN_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/admin', labelKey: 'nav.dashboard', icon: 'home' },
      { to: '/admin/announcements', labelKey: 'nav.announcements', icon: 'megaphone' },
    ],
  },
  {
    titleKey: 'nav.dataManagement',
    items: [
      { to: '/admin/students', labelKey: 'nav.students', icon: 'users' },
      { to: '/admin/teachers', labelKey: 'nav.teachers', icon: 'user-check' },
      { to: '/admin/classes', labelKey: 'nav.classes', icon: 'layers' },
      { to: '/admin/subjects', labelKey: 'nav.subjects', icon: 'book' },
      { to: '/admin/schedule', labelKey: 'nav.schedule', icon: 'calendar' },
    ],
  },
  {
    titleKey: 'nav.reports',
    items: [
      { to: '/admin/attendance', labelKey: 'nav.attendance', icon: 'check-square' },
      { to: '/admin/teacher-attendance', labelKey: 'nav.teacherAttendance', icon: 'camera' },
      { to: '/admin/class-activity', labelKey: 'nav.classActivity', icon: 'activity' },
      { to: '/admin/grades', labelKey: 'nav.grades', icon: 'bar-chart' },
      { to: '/admin/grade-recap', labelKey: 'nav.gradeRecap', icon: 'check-square' },
      { to: '/admin/lesson-plans', labelKey: 'nav.lessonPlans', icon: 'file-text' },
      { to: '/admin/report-cards', labelKey: 'nav.reportCards', icon: 'clipboard' },
      { to: '/admin/finance', labelKey: 'nav.finance', icon: 'wallet' },
    ],
  },
  {
    titleKey: 'nav.settings',
    items: [
      { to: '/admin/settings', labelKey: 'nav.schoolSettings', icon: 'settings' },
    ],
  },
];

const TEACHER_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/teacher', labelKey: 'nav.dashboard', icon: 'home' },
      { to: '/teacher/my-attendance', labelKey: 'nav.myAttendance', icon: 'camera' },
      { to: '/teacher/schedule', labelKey: 'nav.schedule', icon: 'calendar' },
      { to: '/teacher/announcements', labelKey: 'nav.announcements', icon: 'megaphone' },
    ],
  },
  {
    titleKey: 'role.guru',
    items: [
      { to: '/teacher/attendance', labelKey: 'nav.attendance', icon: 'check-square' },
      { to: '/teacher/grades', labelKey: 'nav.grades', icon: 'edit' },
      { to: '/teacher/grade-recap', labelKey: 'nav.gradeRecap', icon: 'bar-chart' },
      { to: '/teacher/class-activity', labelKey: 'nav.classActivity', icon: 'activity' },
      { to: '/teacher/materials', labelKey: 'nav.materials', icon: 'book' },
      { to: '/teacher/lesson-plans', labelKey: 'nav.lessonPlans', icon: 'file-text' },
      { to: '/teacher/recommendations', labelKey: 'nav.recommendations', icon: 'sparkles' },
      { to: '/teacher/report-cards', labelKey: 'nav.reportCards', icon: 'clipboard' },
    ],
  },
];

const PARENT_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/parent', labelKey: 'nav.dashboard', icon: 'home' },
      { to: '/parent/announcements', labelKey: 'nav.announcements', icon: 'megaphone' },
    ],
  },
  {
    titleKey: 'role.wali',
    items: [
      { to: '/parent/attendance', labelKey: 'nav.attendance', icon: 'check-square' },
      { to: '/parent/grades', labelKey: 'nav.grades', icon: 'bar-chart' },
      { to: '/parent/class-activity', labelKey: 'nav.classActivity', icon: 'activity' },
      { to: '/parent/recommendations', labelKey: 'nav.recommendations', icon: 'sparkles' },
      { to: '/parent/report-cards', labelKey: 'nav.reportCards', icon: 'clipboard' },
      { to: '/parent/billing', labelKey: 'nav.billing', icon: 'wallet' },
    ],
  },
];

const STAFF_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/staff', labelKey: 'nav.dashboard', icon: 'home' },
    ],
  },
];

/**
 * DEDICATED super-admin (KamilEdu-team) nav. This is the WHOLE menu for
 * a super-admin — it deliberately does NOT include any school-admin
 * items (Dashboard/Pengumuman/Siswa/Guru/Kelas etc.), because a
 * super-admin has no school of their own. Surfaces only the platform
 * pages under the /super-admin subtree (see router/index.ts).
 */
const SUPER_ADMIN_NAV: NavSection[] = [
  {
    titleKey: 'nav.platform',
    items: [
      { to: '/super-admin', labelKey: 'superAdmin.nav.overview', icon: 'home' },
      {
        to: '/super-admin/demo-requests',
        labelKey: 'superAdmin.nav.demoRequests',
        icon: 'clipboard-list',
      },
      {
        to: '/super-admin/schools',
        labelKey: 'superAdmin.nav.schools',
        icon: 'school',
      },
      {
        to: '/super-admin/demo-incomplete',
        labelKey: 'superAdmin.nav.incomplete',
        icon: 'clock',
      },
      {
        to: '/super-admin/broadcast',
        labelKey: 'superAdmin.nav.broadcast',
        icon: 'megaphone',
      },
    ],
  },
];

// ── Tutoring-center (bimbel) menus ─────────────────────────────────
// Shown when the active tenant is a TUTORING_CENTER. They replace the
// school menus, whose data-management pages (students/teachers/classes)
// read empty for a bimbel — its data lives in the tutoring tables.
const ADMIN_TUTORING_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/admin/tutoring', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/admin/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.manajemen',
    items: [
      {
        to: '/admin/tutoring/students',
        labelKey: 'tutoring.nav.students',
        icon: 'users',
      },
      {
        to: '/admin/tutoring/tutors',
        labelKey: 'tutoring.nav.tutors',
        icon: 'user-check',
      },
    ],
  },
  {
    titleKey: 'tutoring.tenant.center',
    items: [
      {
        to: '/admin/tutoring/programs',
        labelKey: 'tutoring.nav.programs',
        icon: 'layers',
      },
      {
        to: '/admin/tutoring/sessions',
        labelKey: 'tutoring.nav.sessions',
        icon: 'calendar',
      },
      {
        to: '/admin/tutoring/bills',
        labelKey: 'tutoring.nav.bills',
        icon: 'wallet',
      },
      {
        to: '/admin/tutoring/billing-settings',
        labelKey: 'tutoring.nav.billingSettings',
        icon: 'settings',
      },
      {
        to: '/admin/tutoring/payouts',
        labelKey: 'tutoring.nav.payouts',
        icon: 'wallet',
      },
    ],
  },
];

const TEACHER_TUTORING_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/teacher', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/teacher/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
      },
    ],
  },
  {
    titleKey: 'tutoring.tenant.center',
    items: [
      {
        to: '/teacher/tutoring/sessions',
        labelKey: 'tutoring.nav.sessions',
        icon: 'calendar',
      },
      {
        to: '/teacher/tutoring/recurring',
        labelKey: 'tutoring.nav.recurring',
        icon: 'calendar',
      },
      {
        to: '/teacher/tutoring/activities',
        labelKey: 'tutoring.nav.activities',
        icon: 'book',
      },
      {
        to: '/teacher/tutoring/materials',
        labelKey: 'tutoring.nav.materials',
        icon: 'book',
      },
      {
        to: '/teacher/tutoring/tryout-generator',
        labelKey: 'tutoring.nav.ai',
        icon: 'sparkles',
      },
      {
        to: '/teacher/tutoring/earnings',
        labelKey: 'tutoring.nav.earnings',
        icon: 'wallet',
      },
    ],
  },
];

const PARENT_TUTORING_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/parent', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/parent/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
      },
    ],
  },
];

const TUTORING_MENUS: Partial<Record<Role, NavSection[]>> = {
  admin: ADMIN_TUTORING_NAV,
  guru: TEACHER_TUTORING_NAV,
  wali_kelas: TEACHER_TUTORING_NAV,
  wali: PARENT_TUTORING_NAV,
};

const MENUS: Record<Role, NavSection[]> = {
  admin: ADMIN_NAV,
  guru: TEACHER_NAV,
  wali_kelas: TEACHER_NAV,
  wali: PARENT_NAV,
  staff: STAFF_NAV,
  // Super-admins get their OWN dedicated menu (handled in useNavMenu via
  // the isSuperAdmin check below). Map entry kept for exhaustiveness
  // over the `Role` union.
  super_admin: SUPER_ADMIN_NAV,
};

export function useNavMenu(): ComputedRef<NavSection[]> {
  const auth = useAuthStore();
  const { isTutoringCenter } = useTenant();
  return computed(() => {
    // Super-admins ALWAYS get the dedicated platform menu — never the
    // school-admin items. The getter also covers the case where the
    // super-admin grant sits alongside an `admin` role.
    if (auth.isSuperAdmin) return SUPER_ADMIN_NAV;
    const role = auth.activeRole;
    if (!role) return [];
    // Tutoring-center tenants get the bimbel menu (the school
    // data-management pages read empty for them).
    if (isTutoringCenter.value && TUTORING_MENUS[role]) {
      return TUTORING_MENUS[role]!;
    }
    return MENUS[role] ?? [];
  });
}
