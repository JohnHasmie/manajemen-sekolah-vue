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
import { useMeStore } from '@/stores/me';
import { useTenant } from '@/composables/useTenant';
import { useChildPicker } from '@/composables/useChildPicker';
import type { Role } from '@/types/auth';

export interface NavItem {
  to: string;
  labelKey: string;
  icon: string;
  badge?: number;
  /**
   * RBAC permission token (backend MR !225). When set, the item is
   * filtered out unless `auth.hasAbility(ability)` returns true. The
   * authoritative gate stays server-side — this only hides items the
   * user can't act on.
   */
  ability?: string;
  /**
   * "Any of" ability gate. Used when a single nav item legitimately
   * fronts multiple flows — e.g. Absensi is useful to a tenant that
   * owns EITHER attendance_class (student.view/submit) OR only
   * attendance_gate (student.view_own/export). Filter passes if the
   * user holds at least one.
   */
  abilityAny?: readonly string[];
  /**
   * Module-context gate for entries backed by CORE permissions but
   * only meaningful when the tenant owns a module that USES the
   * entity. Siswa/Kelas need `student-context`; Mata Pelajaran needs
   * `academic-context`. Without this a staff-only tenant sees dead
   * roster screens they have no reason to model.
   */
  needs?: 'student-context' | 'academic-context';
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
      // Dashboard is always available — every role home.
      { to: '/admin', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/admin/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
      },
    ],
  },
  {
    titleKey: 'nav.dataManagement',
    items: [
      // Siswa/Kelas/Mapel are backed by CORE `school.*` permissions
      // that every tenant holds, so the ability gate alone leaves them
      // visible even when the tenant has nothing to do with students
      // (e.g. only attendance_staff). Use `needs` to hide them when
      // no student- / academic-touching module is entitled.
      {
        to: '/admin/students',
        labelKey: 'nav.students',
        icon: 'users',
        needs: 'student-context',
      },
      // Guru roster stays available — every tenant with
      // attendance_staff needs it to model non-teaching personnel
      // and assign QR cards.
      { to: '/admin/teachers', labelKey: 'nav.teachers', icon: 'user-check' },
      {
        to: '/admin/classes',
        labelKey: 'nav.classes',
        icon: 'layers',
        needs: 'student-context',
      },
      {
        to: '/admin/subjects',
        labelKey: 'nav.subjects',
        icon: 'book',
        needs: 'academic-context',
      },
      {
        to: '/admin/schedule',
        labelKey: 'nav.schedule',
        icon: 'calendar',
        ability: 'academic.schedule.view',
      },
    ],
  },
  {
    titleKey: 'nav.reports',
    items: [
      // Absensi (student) — attendance_class owners get view+submit;
      // attendance_gate-only owners get view_own+export. Either is
      // enough to justify the menu entry.
      {
        to: '/admin/student-attendance',
        labelKey: 'nav.attendance',
        icon: 'check-square',
        abilityAny: ['attendance.student.view', 'attendance.student.export'],
      },
      {
        to: '/admin/teacher-attendance/report',
        labelKey: 'nav.teacherAttendance',
        icon: 'camera',
        ability: 'attendance.staff.report.view',
      },
      {
        to: '/admin/class-activity',
        labelKey: 'nav.classActivity',
        icon: 'activity',
        ability: 'activity.view',
      },
      {
        to: '/admin/grades',
        labelKey: 'nav.grades',
        icon: 'bar-chart',
        ability: 'academic.grade.view',
      },
      {
        to: '/admin/grade-recap',
        labelKey: 'nav.gradeRecap',
        icon: 'check-square',
        ability: 'academic.grade.recap.view',
      },
      {
        to: '/admin/lesson-plans',
        labelKey: 'nav.lessonPlans',
        icon: 'file-text',
        ability: 'academic.lesson_plan.view',
      },
      {
        to: '/admin/report-cards',
        labelKey: 'nav.reportCards',
        icon: 'clipboard',
        ability: 'academic.report_card.view',
      },
      {
        to: '/admin/finance',
        labelKey: 'nav.finance',
        icon: 'wallet',
        ability: 'finance.bill.view',
      },
    ],
  },
  {
    // ── PENGATURAN — school settings + attendance-QR configuration ──
    // Merged the former standalone "PRESENSI QR" section in here so the
    // three attendance-QR tiles (settings, gate display, personnel
    // cards) live alongside general school settings instead of getting
    // their own heading. Order: schoolSettings → attendance settings →
    // gate QR → personnel cards → roles. Each item keeps its RBAC
    // ability gate (settings + schoolSettings + roles have none — any
    // admin can read them).
    titleKey: 'nav.settings',
    items: [
      { to: '/admin/settings', labelKey: 'nav.schoolSettings', icon: 'settings' },
      {
        to: '/admin/attendance/settings',
        labelKey: 'nav.attendanceQrSettings',
        icon: 'sliders',
        ability: 'attendance.staff.settings.manage',
      },
      {
        to: '/admin/attendance/gate-qr',
        labelKey: 'nav.attendanceQrGate',
        icon: 'qr-code',
        ability: 'attendance.gate_qr.manage',
      },
      {
        to: '/admin/attendance/cards',
        labelKey: 'nav.attendanceQrCards',
        icon: 'id-card',
        ability: 'attendance.cards.issue',
      },
      // Phase E (RBAC): role & permission management. Gated by Phase D's
      // /me consumption — a Bendahara / TU with a stripped-down custom
      // role no longer sees this entry.
      {
        to: '/admin/roles',
        labelKey: 'nav.rolesAndPermissions',
        icon: 'shield',
        ability: 'rbac.role.view',
      },
    ],
  },
];

const TEACHER_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/teacher', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/teacher/my-attendance',
        labelKey: 'nav.myAttendance',
        icon: 'camera',
        ability: 'attendance.self.view_own',
      },
      {
        to: '/teacher/schedule',
        labelKey: 'nav.schedule',
        icon: 'calendar',
        ability: 'academic.schedule.view',
      },
      {
        to: '/teacher/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
      },
    ],
  },
  {
    titleKey: 'role.guru',
    items: [
      {
        to: '/teacher/attendance',
        labelKey: 'nav.attendance',
        icon: 'check-square',
        abilityAny: ['attendance.student.submit', 'attendance.student.view'],
      },
      {
        to: '/teacher/grades',
        labelKey: 'nav.grades',
        icon: 'edit',
        ability: 'academic.grade.input',
      },
      {
        to: '/teacher/grade-recap',
        labelKey: 'nav.gradeRecap',
        icon: 'bar-chart',
        ability: 'academic.grade.recap.view',
      },
      {
        to: '/teacher/class-activity',
        labelKey: 'nav.classActivity',
        icon: 'activity',
        ability: 'activity.view',
      },
      {
        to: '/teacher/materials',
        labelKey: 'nav.materials',
        icon: 'book',
        ability: 'academic.material.view',
      },
      {
        to: '/teacher/lesson-plans',
        labelKey: 'nav.lessonPlans',
        icon: 'file-text',
        ability: 'academic.lesson_plan.view',
      },
      {
        to: '/teacher/recommendations',
        labelKey: 'nav.recommendations',
        icon: 'sparkles',
        abilityAny: [
          'communication.recommendation.view',
          'communication.recommendation.create',
        ],
      },
      {
        to: '/teacher/report-cards',
        labelKey: 'nav.reportCards',
        icon: 'clipboard',
        ability: 'academic.report_card.view',
      },
    ],
  },
];

const PARENT_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/parent', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/parent/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
      },
    ],
  },
  {
    titleKey: 'role.wali',
    items: [
      {
        to: '/parent/attendance',
        labelKey: 'nav.attendance',
        icon: 'check-square',
        ability: 'attendance.student.view_own',
      },
      {
        to: '/parent/grades',
        labelKey: 'nav.grades',
        icon: 'bar-chart',
        ability: 'academic.grade.view',
      },
      {
        to: '/parent/class-activity',
        labelKey: 'nav.classActivity',
        icon: 'activity',
        ability: 'activity.view',
      },
      {
        to: '/parent/recommendations',
        labelKey: 'nav.recommendations',
        icon: 'sparkles',
        ability: 'communication.recommendation.view',
      },
      {
        to: '/parent/report-cards',
        labelKey: 'nav.reportCards',
        icon: 'clipboard',
        ability: 'academic.report_card.view',
      },
      {
        to: '/parent/billing',
        labelKey: 'nav.billing',
        icon: 'wallet',
        ability: 'finance.bill.view_own',
      },
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
        to: '/super-admin/subscription-approvals',
        labelKey: 'superAdmin.nav.subscriptionApprovals',
        icon: 'credit-card',
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

/**
 * Filter nav items by their declared gates.
 *
 * Passing rules (all must hold):
 *   - `ability`     → `hasAbility(ability)` returns true.
 *   - `abilityAny`  → at least one of the listed abilities is held.
 *   - `needs`       → the corresponding entitlement flag on the me
 *                     store is true (`hasStudentContext` /
 *                     `hasAcademicContext`). This is how siswa/kelas/
 *                     mapel disappear when the tenant has no module
 *                     that actually consumes those entities.
 *
 * Sections that empty out after filtering are dropped wholesale so
 * the sidebar doesn't render a blank section heading.
 */
function applyGates(
  sections: NavSection[],
  hasAbility: (perm: string) => boolean,
  hasStudentContext: boolean,
  hasAcademicContext: boolean,
): NavSection[] {
  const out: NavSection[] = [];
  for (const sec of sections) {
    const items = sec.items.filter((it) => {
      if (it.ability && !hasAbility(it.ability)) return false;
      if (it.abilityAny && !it.abilityAny.some((a) => hasAbility(a))) return false;
      if (it.needs === 'student-context' && !hasStudentContext) return false;
      if (it.needs === 'academic-context' && !hasAcademicContext) return false;
      return true;
    });
    if (items.length > 0) out.push({ titleKey: sec.titleKey, items });
  }
  return out;
}

export function useNavMenu(): ComputedRef<NavSection[]> {
  const auth = useAuthStore();
  const me = useMeStore();
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
    const studentCtx = me.hasStudentContext;
    const academicCtx = me.hasAcademicContext;
    // Tutoring-center tenants get the bimbel menu (the school
    // data-management pages read empty for them).
    if (isTutoringCenter.value) {
      // Parent nav is dynamic — Monitoring/Schedule/Grade entries embed
      // the active child id so a single click lands directly on the
      // overview without a child-picker detour.
      if (role === 'wali') return parentTutoringNav(activeChildId.value);
      if (TUTORING_MENUS[role]) {
        return applyGates(TUTORING_MENUS[role]!, auth.hasAbility, studentCtx, academicCtx);
      }
    }
    return applyGates(MENUS[role] ?? [], auth.hasAbility, studentCtx, academicCtx);
  });
}
