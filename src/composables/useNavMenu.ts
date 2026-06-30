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
import { useChildPicker } from '@/composables/useChildPicker';
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
      { to: '/admin/student-attendance', labelKey: 'nav.attendance', icon: 'check-square' },
      { to: '/admin/teacher-attendance/report', labelKey: 'nav.teacherAttendance', icon: 'camera' },
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
      // Phase E (RBAC): role & permission management. Sidebar visibility
      // can be tightened later via a `requiredAbility` field once the
      // web auth store mirrors mobile's /me consumption.
      { to: '/admin/roles', labelKey: 'nav.rolesAndPermissions', icon: 'shield' },
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
 * items (Dashboard/Announcement/Student/Teacher/Kelas etc.), because a
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
      { to: '/admin/tutoring/students', labelKey: 'tutoring.nav.students', icon: 'users' },
      { to: '/admin/tutoring/tutors', labelKey: 'tutoring.nav.tutors', icon: 'user-check' },
      { to: '/admin/tutoring/groups', labelKey: 'tutoring.nav.classes', icon: 'layers' },
    ],
  },
  {
    titleKey: 'tutoring.tenant.center',
    items: [
      { to: '/admin/tutoring/programs', labelKey: 'tutoring.nav.programs', icon: 'layers' },
      { to: '/admin/tutoring/sessions', labelKey: 'tutoring.nav.sessions', icon: 'calendar' },
      { to: '/admin/tutoring/bills', labelKey: 'tutoring.nav.bills', icon: 'wallet' },
      { to: '/admin/tutoring/billing-settings', labelKey: 'tutoring.nav.billingSettings', icon: 'settings' },
      { to: '/admin/tutoring/session-reminders', labelKey: 'tutoring.nav.sessionReminders', icon: 'bell' },
      { to: '/admin/tutoring/payouts', labelKey: 'tutoring.nav.payouts', icon: 'wallet' },
      { to: '/admin/tutoring/payout-requests', labelKey: 'tutoring.nav.payoutRequests', icon: 'wallet' },
      { to: '/admin/tutoring/payout-settings', labelKey: 'tutoring.nav.payoutSettings', icon: 'settings' },
      { to: '/admin/tutoring/leads', labelKey: 'tutoring.nav.leads', icon: 'users' },
      { to: '/admin/tutoring/vouchers', labelKey: 'tutoring.nav.vouchers', icon: 'wallet' },
      { to: '/admin/tutoring/group-announcements', labelKey: 'tutoring.nav.groupAnnouncements', icon: 'megaphone' },
      { to: '/admin/tutoring/leaderboard', labelKey: 'tutoring.nav.leaderboard', icon: 'bar-chart' },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionExtra',
    items: [
      { to: '/admin/tutoring/reports/activity', labelKey: 'tutoring.nav.activities', icon: 'bar-chart' },
      { to: '/admin/tutoring/reports/attendance', labelKey: 'tutoring.nav.attendance', icon: 'check-square' },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionAccount',
    items: [
      { to: '/admin/tutoring/notifications', labelKey: 'tutoring.nav.notifications', icon: 'bell' },
      { to: '/admin/tutoring/profile', labelKey: 'tutoring.nav.profile', icon: 'user' },
      { to: '/admin/tutoring/appearance', labelKey: 'tutoring.nav.appearance', icon: 'sun' },
    ],
  },
];

const TEACHER_TUTORING_NAV: NavSection[] = [
  {
    titleKey: 'tutoring.nav.sectionMain',
    items: [
      { to: '/teacher', labelKey: 'tutoring.nav.home', icon: 'home' },
      {
        to: '/teacher/tutoring/class',
        labelKey: 'tutoring.nav.classes',
        icon: 'layers',
      },
      {
        to: '/teacher/tutoring/sessions',
        labelKey: 'tutoring.nav.jadwal',
        icon: 'calendar',
      },
      {
        to: '/teacher/tutoring/earnings',
        labelKey: 'tutoring.nav.honor',
        icon: 'wallet',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionExtra',
    items: [
      { to: '/teacher/tutoring/materials', labelKey: 'tutoring.nav.materials', icon: 'book' },
      { to: '/teacher/tutoring/tryout-generator', labelKey: 'tutoring.nav.ai', icon: 'sparkles' },
      { to: '/teacher/tutoring/recurring', labelKey: 'tutoring.nav.recurring', icon: 'calendar' },
      { to: '/teacher/tutoring/activities', labelKey: 'tutoring.nav.activities', icon: 'check-circle' },
      { to: '/teacher/tutoring/ratings', labelKey: 'tutoring.nav.rating', icon: 'star' },
      { to: '/teacher/tutoring/announcements', labelKey: 'nav.announcements', icon: 'megaphone' },
      { to: '/teacher/tutoring/leaderboard', labelKey: 'tutoring.nav.leaderboard', icon: 'bar-chart' },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionAccount',
    items: [
      { to: '/teacher/tutoring/notifications', labelKey: 'tutoring.nav.notifications', icon: 'bell' },
      { to: '/teacher/tutoring/profile', labelKey: 'tutoring.nav.profile', icon: 'user' },
      { to: '/teacher/tutoring/appearance', labelKey: 'tutoring.nav.appearance', icon: 'sun' },
    ],
  },
];

/**
 * Parent bimbel sidebar. "Monitoring Anak" is the only per-anak route
 * (it embeds activeChildId from useChildPicker). Schedule / Grade /
 * Kehadiran all live inside that same overview screen, so they're
 * NOT separate entries — adding them would just duplicate the
 * Monitoring path and light up three rows at once.
 *
 * When activeChildId is empty (initial load, or parent never opened the
 * picker), Monitoring falls back to /parent so the parent lands on the
 * dashboard child-switcher instead of a broken /parent/tutoring/
 * route.
 */
function parentTutoringNav(activeChildId: string): NavSection[] {
  const child = activeChildId || ':studentId';
  const homePath = activeChildId ? `/parent/tutoring/${child}` : '/parent';
  return [
    {
      titleKey: '',
      items: [
        { to: homePath, labelKey: 'tutoring.nav.home', icon: 'home' },
        { to: `/parent/tutoring/${child}/classes`, labelKey: 'tutoring.nav.classes', icon: 'layers' },
        { to: `/parent/tutoring/${child}/sessions`, labelKey: 'tutoring.nav.sessions', icon: 'calendar' },
        { to: `/parent/tutoring/${child}/bills`, labelKey: 'tutoring.nav.bills', icon: 'wallet' },
      ],
    },
    {
      titleKey: 'tutoring.nav.sectionExtra',
      items: [
        { to: `/parent/tutoring/${child}/activities`, labelKey: 'tutoring.nav.activities', icon: 'book' },
        { to: `/parent/tutoring/${child}/progress`, labelKey: 'tutoring.nav.progress', icon: 'bar-chart' },
        { to: `/parent/tutoring/${child}/leaderboard`, labelKey: 'tutoring.nav.leaderboard', icon: 'check-square' },
        { to: `/parent/tutoring/${child}/announcements`, labelKey: 'nav.announcements', icon: 'megaphone' },
        { to: '/parent/tutoring/vouchers', labelKey: 'tutoring.nav.myVouchers', icon: 'sparkles' },
      ],
    },
    {
      titleKey: 'tutoring.nav.sectionAccount',
      items: [
        { to: '/parent/tutoring/notifications', labelKey: 'tutoring.nav.notifications', icon: 'bell' },
        { to: '/parent/tutoring/profile', labelKey: 'tutoring.nav.profile', icon: 'user' },
        { to: '/parent/tutoring/appearance', labelKey: 'tutoring.nav.appearance', icon: 'sun' },
      ],
    },
  ];
}

/** Static tenant menus. `parent` resolves dynamically (needs child id). */
const TUTORING_MENUS: Partial<Record<Role, NavSection[]>> = {
  admin: ADMIN_TUTORING_NAV,
  guru: TEACHER_TUTORING_NAV,
  wali_kelas: TEACHER_TUTORING_NAV,
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
  // useChildPicker exposes a module-singleton activeChildId that
  // updates reactively when the parent switches kid on the dashboard.
  const { activeChildId } = useChildPicker();
  return computed(() => {
    // Super-admins ALWAYS get the dedicated platform menu — never the
    // school-admin items. The getter also covers the case where the
    // super-admin grant sits alongside an `admin` role.
    if (auth.isSuperAdmin) return SUPER_ADMIN_NAV;
    const role = auth.activeRole;
    if (!role) return [];
    // Tutoring-center tenants get the bimbel menu (the school
    // data-management pages read empty for them).
    if (isTutoringCenter.value) {
      // Parent nav is dynamic — Monitoring/Schedule/Grade entries embed
      // the active child id so a single click lands directly on the
      // overview without a child-picker detour.
      if (role === 'wali') return parentTutoringNav(activeChildId.value);
      if (TUTORING_MENUS[role]) return TUTORING_MENUS[role]!;
    }
    return MENUS[role] ?? [];
  });
}
