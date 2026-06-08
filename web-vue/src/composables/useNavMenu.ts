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
 * Extra section appended for KamilEdu-team super-admins. Surfaces the
 * platform-level Demo Requests review page (super-admin-gated route,
 * see router/index.ts). Regular admins never see this section.
 */
const SUPER_ADMIN_NAV: NavSection = {
  titleKey: 'nav.platform',
  items: [
    {
      to: '/admin/demo-requests',
      labelKey: 'nav.demoRequests',
      icon: 'shield',
    },
  ],
};

const MENUS: Record<Role, NavSection[]> = {
  admin: ADMIN_NAV,
  guru: TEACHER_NAV,
  wali_kelas: TEACHER_NAV,
  wali: PARENT_NAV,
  staff: STAFF_NAV,
  // Super-admins route as `admin`; the super-admin extras are appended
  // dynamically in `useNavMenu` rather than via this map. Map entry
  // kept for exhaustiveness over the `Role` union.
  super_admin: ADMIN_NAV,
};

export function useNavMenu(): ComputedRef<NavSection[]> {
  const auth = useAuthStore();
  return computed(() => {
    const role = auth.activeRole;
    if (!role) return [];
    const base = MENUS[role] ?? [];
    // Append the platform section only for super-admins, and only on
    // an admin surface (super-admins act as `admin`).
    if (auth.isSuperAdmin && (role === 'admin' || role === 'super_admin')) {
      return [...base, SUPER_ADMIN_NAV];
    }
    return base;
  });
}
