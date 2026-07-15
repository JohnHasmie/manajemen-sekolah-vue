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
import { canonicalRole, ROLE_PARENT, ROLE_STAFF, ROLE_TEACHER } from '@/utils/role';

export interface NavItem {
  to: string;
  labelKey: string;
  icon: string;
  badge?: number;
  /**
   * Boolean attention indicator, rendered by the shell as a small red
   * dot (no number). Used when the signal is "something needs
   * attention here" without a meaningful count — e.g. the parent has
   * an outstanding/overdue bill total (a rupiah amount, not a count).
   */
  dot?: boolean;
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
   * `academic-context`; every bimbel surface needs `tutoring-module`.
   * Without this a staff-only tenant sees dead roster screens, and a
   * school tenant can URL-nav into bimbel routes it doesn't own.
   */
  needs?: 'student-context' | 'academic-context' | 'tutoring-module';
}

export interface NavSection {
  /** i18n key for the section heading, or empty string for an unlabeled group. */
  titleKey: string;
  items: NavItem[];
}

/**
 * ADMIN_NAV — domain-first grouping (Refactor Map Wave 1).
 *
 * Sections mirror the sellable MODULE GROUPS, so `applyGates` (which
 * drops empty sections) makes a whole section disappear when the
 * tenant doesn't own any module in that domain. That turns "1 item
 * silently missing from a pile of 8" into "the KEUANGAN section is
 * gone" — a legible signal that pairs naturally with the Langganan &
 * Modul upsell.
 *
 * The former PENGATURAN section (6 entries) collapsed to a single
 * "Pengaturan" item: /admin/settings is already a tile hub, and the
 * Role & Permission / Langganan & Modul / attendance-method entries
 * moved into it (AdminSettingsView). QR Gerbang + Kartu QR are
 * OPERATIONAL screens (display + card CRUD), not settings — they live
 * in the Kehadiran section where the daily work happens.
 */
const ADMIN_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      // Dashboard is always available — every role home.
      { to: '/admin', labelKey: 'nav.dashboard', icon: 'home' },
    ],
  },
  {
    // ── DATA SEKOLAH — core rosters ─────────────────────────────────
    titleKey: 'nav.sectionSchoolData',
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
        // Ability-tagged so a staff (Kesiswaan/TU) holding the student
        // ability sees it too — matching the mobile "People" tab. Admins
        // hold both keys so they are unaffected. Without a gate the staff
        // strict-filter (see the staff branch below) would drop it.
        abilityAny: ['school.student.view', 'school.student.manage'],
      },
      // Guru roster stays available — every tenant with
      // attendance_staff needs it to model non-teaching personnel
      // and assign QR cards.
      {
        to: '/admin/teachers',
        labelKey: 'nav.teachers',
        icon: 'user-check',
        abilityAny: ['school.teacher.view', 'school.teacher.manage'],
      },
      {
        // "Data Staf" — non-teaching personnel. No student-context needed
        // (staff exist regardless of student modules). Ability-gated so a
        // TU/Kesiswaan staff holding school.staff.* sees it too.
        to: '/admin/staff',
        labelKey: 'nav.staff',
        icon: 'briefcase',
        abilityAny: ['school.staff.view', 'school.staff.manage'],
      },
      {
        to: '/admin/classes',
        labelKey: 'nav.classes',
        icon: 'layers',
        needs: 'student-context',
      },
      {
        // "Data Terhapus" — recycle bin for soft-deleted guru/siswa/mapel.
        // Admin-only + destructive, so gated on school.settings.manage to
        // match the backend TrashController (a staff never sees it).
        to: '/admin/trash',
        labelKey: 'nav.dataTerhapus',
        icon: 'trash-2',
        ability: 'school.settings.manage',
      },
      // Class-first read-only oversight (health + Perlu Perhatian), distinct
      // from the class-management entry above.
      {
        to: '/admin/class-oversight',
        labelKey: 'classHub.oversightTitle',
        icon: 'eye',
        ability: 'school.class.view',
      },
      {
        to: '/admin/subjects',
        labelKey: 'nav.subjects',
        icon: 'book',
        needs: 'academic-context',
      },
    ],
  },
  // ── KEHADIRAN — modules: attendance_class · attendance_gate ·
  //    attendance_staff. Two legible buckets: the attendance-RECORD
  //    views (Kehadiran Siswa + Kehadiran Pegawai) under one "Kehadiran"
  //    header, and the QR gate/card OPS screens under "Gerbang & Kartu".
  //    Same routes, same abilities, same icons — pure regrouping. Each
  //    section gates independently (applyGates drops any item — and any
  //    section that empties out), so a tenant that only owns
  //    attendance_staff sees just "Kehadiran Pegawai". The QR config
  //    still lives in the Pengaturan hub (Wave 2). ───────────
  {
    // Both attendance-record views share one header. Item gates are
    // independent: attendance_class owners get view+submit (or, for
    // gate-only owners, view_own+export) → Kehadiran Siswa;
    // attendance_staff owners → Kehadiran Pegawai. The section shows
    // whenever EITHER item survives gating.
    titleKey: 'nav.sectionAttendance',
    items: [
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
    ],
  },
  {
    // Gerbang & Kartu — the operational QR screens: gate poster display
    // + personnel card CRUD. Grouped together as the "hardware-adjacent"
    // ops surface, distinct from the two attendance-record views above.
    titleKey: 'nav.sectionAttendanceGate',
    items: [
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
    ],
  },
  {
    // ── AKADEMIK — modules: schedule · grades · report_cards · lms ·
    //    class_activity. Nilai & Rekap Nilai stay as SEPARATE entries
    //    on purpose: formative vs summative are distinct data models
    //    (consolidation audit verdict) — adjacency is enough. ──────
    titleKey: 'nav.sectionAcademic',
    items: [
      {
        to: '/admin/schedule',
        labelKey: 'nav.schedule',
        icon: 'calendar',
        ability: 'academic.schedule.view',
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
        to: '/admin/report-cards',
        labelKey: 'nav.reportCards',
        icon: 'clipboard',
        ability: 'academic.report_card.view',
      },
      {
        to: '/admin/lesson-plans',
        labelKey: 'nav.lessonPlans',
        icon: 'file-text',
        ability: 'academic.lesson_plan.view',
      },
      {
        to: '/admin/class-activity',
        labelKey: 'nav.classActivity',
        icon: 'activity',
        ability: 'activity.view',
      },
    ],
  },
  {
    // ── KEUANGAN — module: finance ──────────────────────────────────
    titleKey: 'nav.sectionFinance',
    items: [
      {
        to: '/admin/finance',
        labelKey: 'nav.financeBilling',
        icon: 'wallet',
        ability: 'finance.bill.view',
      },
    ],
  },
  {
    // ── KOMUNIKASI — module: communication ──────────────────────────
    titleKey: 'nav.sectionCommunication',
    items: [
      {
        to: '/admin/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
      },
    ],
  },
  {
    // ── PENGATURAN — single entry into the settings hub. Everything
    //    config-shaped (profil, tahun ajaran, jam pelajaran, metode
    //    kehadiran, jenis tagihan, role & permission, langganan &
    //    modul, data, reset demo) lives INSIDE /admin/settings as
    //    tiles — one door, no more six-entry sprawl. ───────────────
    titleKey: '',
    items: [
      {
        to: '/admin/settings',
        labelKey: 'nav.settings',
        icon: 'settings',
        // Ability-tagged so a staff holding settings access sees the
        // hub too (mobile "System" tab parity). Admins hold both keys.
        abilityAny: ['school.settings.view', 'school.settings.manage'],
      },
    ],
  },
];

const TEACHER_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/teacher', labelKey: 'nav.dashboard', icon: 'home' },
      // Inbox (Prioritas / Perlu Perhatian). Route existed but was
      // orphaned from the nav — re-added, Wave 7. Ungated: every
      // teacher can see their own priority inbox.
      { to: '/teacher/inbox', labelKey: 'nav.inbox', icon: 'inbox' },
      // Class-first "Kelas" hub — promoted to the top as the primary
      // working surface (the per-class Riwayat Sesi / Tugas / Anggota /
      // Nilai). The older per-module views stay under their sections.
      {
        to: '/teacher/classes',
        labelKey: 'nav.classHub',
        icon: 'users',
        // The hub shows the teacher's OWN classes (GET /classes/mine), gated on
        // `activity.view` — which every guru holds. NOT `school.class.view`:
        // that's the admin-only school-wide read, so it hid Kelas from teachers.
        ability: 'activity.view',
      },
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
    titleKey: 'role.teacher',
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

/**
 * WALI_KELAS_NAV — homeroom-teacher (wali kelas) identity.
 *
 * ── Why this exists ──────────────────────────────────────────────────
 * A `wali_kelas` is a `guru` who ALSO owns a homeroom class. On web they
 * previously reused `TEACHER_NAV` verbatim, so their homeroom identity
 * was invisible: the class-scoped work (kehadiran, nilai, kegiatan,
 * pengumuman, rapor for THEIR kelas) sat mixed in with subject-teaching
 * items, undifferentiated. This nav FOREGROUNDS that homeroom work in a
 * "Kelas Saya" (`nav.sectionHomeroom`) section at the top, then keeps
 * every teacher-shared item below.
 *
 * ── HONEST scope: invents NOTHING ────────────────────────────────────
 * Every entry here is an EXISTING teacher route (see router/index.ts
 * `/teacher/*`) with its EXISTING label/icon/ability. No new screen,
 * endpoint, path, or ability is introduced. The homeroom section just
 * RE-GROUPS routes the teacher nav already exposed. The class-scoped
 * views (TeacherAttendanceView / TeacherGradeBookView /
 * TeacherGradeRecapView / TeacherScheduleView / TeacherRecommendationView
 * / TeacherAnnouncementView / report-card views) already read
 * `auth.homeroomClasses` to offer a "Wali {kelas}" filter mode, so these
 * are the genuinely homeroom-relevant surfaces — nothing fabricated.
 *
 * ── Runtime-role caveat (important) ──────────────────────────────────
 * `auth.activeRole` is NEVER the literal `'wali_kelas'` at runtime:
 * `normalizeRole()` in stores/auth.ts collapses `'wali_kelas'` → `'guru'`
 * on every authenticated path. The homeroom identity is carried by
 * `auth.homeroomClasses` (populated from the teacher_profile). So this
 * nav is selected by `useNavMenu` on the `homeroomClasses.length > 0`
 * signal — NOT on the role string. The `MENUS.wali_kelas` mapping below
 * is kept for exhaustiveness/type-safety but is not the live selector.
 */
const WALI_KELAS_NAV: NavSection[] = [
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
    ],
  },
  {
    // ── KELAS SAYA — the homeroom teacher's class-scoped work. Same
    //    routes/abilities as the teacher nav, just promoted to the top
    //    so the wali kelas lands on THEIR class work first. ─────────
    titleKey: 'nav.sectionHomeroom',
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
        to: '/teacher/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
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
  {
    // ── MENGAJAR — teacher-shared items (subject teaching), kept below
    //    the homeroom section. These are the TEACHER_NAV items NOT
    //    promoted above; schedule/materials/lesson-plans are general
    //    teaching tools, not homeroom-specific. ─────────────────────
    titleKey: 'role.teacher',
    items: [
      {
        to: '/teacher/schedule',
        labelKey: 'nav.schedule',
        icon: 'calendar',
        ability: 'academic.schedule.view',
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
    ],
  },
];

const PARENT_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/parent', labelKey: 'nav.dashboard', icon: 'home' },
      // Inbox (Perlu Perhatian). Route existed but was orphaned from
      // the nav — re-added, Wave 7. Ungated: every parent can see
      // their own priority inbox.
      { to: '/parent/inbox', labelKey: 'nav.inbox', icon: 'inbox' },
      // Class-first "Kelas" hub — the child's per-class Riwayat Sesi /
      // Tugas / Anggota / Nilai (read-only). Promoted to the top.
      {
        to: '/parent/classes',
        labelKey: 'nav.classHub',
        icon: 'users',
        ability: 'activity.view',
      },
      {
        to: '/parent/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
        ability: 'communication.announcement.view',
      },
    ],
  },
  {
    titleKey: 'role.parent',
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

/**
 * STAFF_NAV — Dashboard + the staff self-attendance surface (F3).
 *
 * The `staff` role now HAS a real web self-service capability: self
 * check-in. The check-in + history screens are the SAME ones teachers
 * use, mounted under `/staff/my-attendance` — the /teacher-attendance
 * endpoints are staff-aware server-side (Phase C: the backend resolves
 * the caller as teacher OR staff and writes the correct personnel_type
 * row), so nothing is fabricated or duplicated.
 *
 * The Presensi/Riwayat items are gated on `attendance.self.view_own` —
 * the exact same ability the teacher my-attendance nav + route gate on.
 * A staff user who lacks it (e.g. no `staff` roster row at this school)
 * sees only Dashboard + Akun, and the Dashboard renders the honest
 * empty state (see StaffHomeView.vue). We still surface NO fabricated
 * KPIs and NO admin-management tiles — the `attendance_staff` module
 * stays ADMIN-side only.
 */
const STAFF_NAV: NavSection[] = [
  {
    titleKey: '',
    items: [
      { to: '/staff', labelKey: 'nav.dashboard', icon: 'home' },
      {
        to: '/staff/my-attendance',
        labelKey: 'nav.myAttendance',
        icon: 'camera',
        ability: 'attendance.self.view_own',
      },
      {
        to: '/staff/my-attendance/history',
        labelKey: 'nav.attendanceHistory',
        icon: 'clipboard-list',
        ability: 'attendance.self.view_own',
      },
      { to: '/profile', labelKey: 'nav.account', icon: 'user' },
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
        // Modular-SaaS grant/revoke surface (route existed but was
        // orphaned from the nav — re-added, Wave 7). Reuses the same
        // "package" icon as the admin settings "Kelola Modul" tile.
        to: '/super-admin/tenant-modules',
        labelKey: 'superAdmin.nav.tenantModules',
        icon: 'package',
      },
      {
        to: '/super-admin/subscription-approvals',
        labelKey: 'superAdmin.nav.subscriptionApprovals',
        icon: 'credit-card',
      },
      {
        to: '/super-admin/discount-codes',
        labelKey: 'superAdmin.nav.discountCodes',
        icon: 'sparkles',
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
  // ── Wave 7 regroup ──────────────────────────────────────────────────
  // The former single "Tutoring" catch-all (13 items) was an
  // undifferentiated pile. It's split into coherent buckets purely by
  // MOVING existing items between sections — every route, ability and
  // icon is preserved; no routes added or removed. The buckets:
  //   Manajemen        → the rosters + CRM (students/tutors/groups/leads)
  //   Program & Sesi   → programs, sessions, reminders, group announcements
  //   Pendapatan Tutor → tutor payouts (payouts/requests/settings)
  //   Keuangan Anak    → student-facing money (bills, billing cfg, vouchers)
  //   Lainnya          → leaderboard + activity/attendance reports
  //   Akun             → notifications/profile/appearance (unchanged)
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
      // "Groups" reused the school "Classes" label/icon confusingly —
      // relabel to a bimbel-native "Kelompok Belajar" / "Study groups"
      // and swap the `layers` (classes/stacks) icon for `users` (a group
      // of learners). Label/icon change only — same /admin/tutoring/groups
      // route.
      {
        to: '/admin/tutoring/groups',
        labelKey: 'tutoring.nav.groups',
        icon: 'users',
      },
      {
        to: '/admin/tutoring/leads',
        labelKey: 'tutoring.nav.leads',
        icon: 'users',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionPrograms',
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
        to: '/admin/tutoring/session-reminders',
        labelKey: 'tutoring.nav.sessionReminders',
        icon: 'bell',
      },
      {
        to: '/admin/tutoring/group-announcements',
        labelKey: 'tutoring.nav.groupAnnouncements',
        icon: 'megaphone',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionTutorIncome',
    items: [
      {
        to: '/admin/tutoring/payouts',
        labelKey: 'tutoring.nav.payouts',
        icon: 'wallet',
      },
      {
        to: '/admin/tutoring/payout-requests',
        labelKey: 'tutoring.nav.payoutRequests',
        icon: 'wallet',
      },
      {
        to: '/admin/tutoring/payout-settings',
        labelKey: 'tutoring.nav.payoutSettings',
        icon: 'settings',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionStudentFinance',
    items: [
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
        to: '/admin/tutoring/vouchers',
        labelKey: 'tutoring.nav.vouchers',
        icon: 'wallet',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionExtra',
    items: [
      {
        to: '/admin/tutoring/leaderboard',
        labelKey: 'tutoring.nav.leaderboard',
        icon: 'bar-chart',
      },
      {
        to: '/admin/tutoring/reports/activity',
        labelKey: 'tutoring.nav.activities',
        icon: 'bar-chart',
      },
      {
        to: '/admin/tutoring/reports/attendance',
        labelKey: 'tutoring.nav.attendance',
        icon: 'check-square',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionAccount',
    items: [
      {
        to: '/admin/tutoring/notifications',
        labelKey: 'tutoring.nav.notifications',
        icon: 'bell',
      },
      {
        to: '/admin/tutoring/profile',
        labelKey: 'tutoring.nav.profile',
        icon: 'user',
      },
      {
        to: '/admin/tutoring/appearance',
        labelKey: 'tutoring.nav.appearance',
        icon: 'sun',
      },
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
        to: '/teacher/tutoring/recurring',
        labelKey: 'tutoring.nav.recurring',
        icon: 'calendar',
      },
      {
        to: '/teacher/tutoring/activities',
        labelKey: 'tutoring.nav.activities',
        icon: 'check-circle',
      },
      {
        to: '/teacher/tutoring/ratings',
        labelKey: 'tutoring.nav.rating',
        icon: 'star',
      },
      {
        to: '/teacher/tutoring/announcements',
        labelKey: 'nav.announcements',
        icon: 'megaphone',
      },
      {
        to: '/teacher/tutoring/leaderboard',
        labelKey: 'tutoring.nav.leaderboard',
        icon: 'bar-chart',
      },
    ],
  },
  {
    titleKey: 'tutoring.nav.sectionAccount',
    items: [
      {
        to: '/teacher/tutoring/notifications',
        labelKey: 'tutoring.nav.notifications',
        icon: 'bell',
      },
      {
        to: '/teacher/tutoring/profile',
        labelKey: 'tutoring.nav.profile',
        icon: 'user',
      },
      {
        to: '/teacher/tutoring/appearance',
        labelKey: 'tutoring.nav.appearance',
        icon: 'sun',
      },
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
        {
          to: `/parent/tutoring/${child}/classes`,
          labelKey: 'tutoring.nav.classes',
          icon: 'layers',
        },
        {
          to: `/parent/tutoring/${child}/sessions`,
          labelKey: 'tutoring.nav.sessions',
          icon: 'calendar',
        },
        {
          to: `/parent/tutoring/${child}/bills`,
          labelKey: 'tutoring.nav.bills',
          icon: 'wallet',
        },
      ],
    },
    {
      titleKey: 'tutoring.nav.sectionExtra',
      items: [
        {
          to: `/parent/tutoring/${child}/activities`,
          labelKey: 'tutoring.nav.activities',
          icon: 'book',
        },
        {
          to: `/parent/tutoring/${child}/progress`,
          labelKey: 'tutoring.nav.progress',
          icon: 'bar-chart',
        },
        {
          to: `/parent/tutoring/${child}/leaderboard`,
          labelKey: 'tutoring.nav.leaderboard',
          icon: 'check-square',
        },
        {
          to: `/parent/tutoring/${child}/announcements`,
          labelKey: 'nav.announcements',
          icon: 'megaphone',
        },
        {
          to: '/parent/tutoring/vouchers',
          labelKey: 'tutoring.nav.myVouchers',
          icon: 'sparkles',
        },
      ],
    },
    {
      titleKey: 'tutoring.nav.sectionAccount',
      items: [
        {
          to: '/parent/tutoring/notifications',
          labelKey: 'tutoring.nav.notifications',
          icon: 'bell',
        },
        {
          to: '/parent/tutoring/profile',
          labelKey: 'tutoring.nav.profile',
          icon: 'user',
        },
        {
          to: '/parent/tutoring/appearance',
          labelKey: 'tutoring.nav.appearance',
          icon: 'sun',
        },
      ],
    },
  ];
}

/** Static tenant menus. `parent` resolves dynamically (needs child id). */
const TUTORING_MENUS: Partial<Record<Role, NavSection[]>> = {
  admin: ADMIN_TUTORING_NAV,
  teacher: TEACHER_TUTORING_NAV,
  // A tutoring center (bimbel) has NO homeroom concept — tutors teach
  // session groups, not homeroom classes, and none of the bimbel views
  // read `homeroomClasses`. So a wali_kelas on the bimbel surface is just
  // a tutor; the homeroom "Kelas Saya" regrouping would surface nothing
  // meaningful. Keep the shared tutor nav here on purpose.
  wali_kelas: TEACHER_TUTORING_NAV,
};

// Partial: `student` has no web dashboard shell (parent-mediated), so it has
// no menu — the `MENUS[role] ?? []` lookup covers the gap.
const MENUS: Partial<Record<Role, NavSection[]>> = {
  admin: ADMIN_NAV,
  teacher: TEACHER_NAV,
  // NOTE: `activeRole` is never literally 'wali_kelas' at runtime
  // (normalizeRole collapses it to 'guru'), so this map entry is not the
  // live selector. `useNavMenu` picks WALI_KELAS_NAV off the real
  // homeroom signal (`auth.homeroomClasses.length > 0`). Kept mapped for
  // Role-union exhaustiveness and so a future un-collapsed role still
  // gets the homeroom-first nav rather than the plain teacher nav.
  wali_kelas: WALI_KELAS_NAV,
  parent: PARENT_NAV,
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
  hasTutoringContext: boolean,
): NavSection[] {
  const out: NavSection[] = [];
  for (const sec of sections) {
    const items = sec.items.filter((it) => {
      if (it.ability && !hasAbility(it.ability)) return false;
      if (it.abilityAny && !it.abilityAny.some((a) => hasAbility(a)))
        return false;
      if (it.needs === 'student-context' && !hasStudentContext) return false;
      if (it.needs === 'academic-context' && !hasAcademicContext) return false;
      if (it.needs === 'tutoring-module' && !hasTutoringContext) return false;
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
  // `hasOverdueBills` rides the SAME getStats('wali') fetch the picker
  // already makes — used to red-dot the parent Billing nav item.
  const { activeChildId, hasOverdueBills } = useChildPicker();
  return computed(() => {
    // Super-admins ALWAYS get the dedicated platform menu — never the
    // school-admin items. The getter also covers the case where the
    // super-admin grant sits alongside an `admin` role.
    if (auth.isSuperAdmin) return SUPER_ADMIN_NAV;
    const role = auth.activeRole;
    if (!role) return [];
    const studentCtx = me.hasStudentContext;
    const academicCtx = me.hasAcademicContext;
    const tutoringCtx = me.hasTutoringContext;
    // Tutoring-center tenants get the bimbel menu (the school
    // data-management pages read empty for them). Also require
    // `hasTutoringContext` — a bimbel tenant that (edge case) doesn't
    // own the tutoring module shouldn't see 175 broken bimbel routes;
    // it falls through to the empty-nav path below.
    if (isTutoringCenter.value && tutoringCtx) {
      // Parent nav is dynamic — Monitoring/Schedule/Grade entries embed
      // the active child id so a single click lands directly on the
      // overview without a child-picker detour.
      if (canonicalRole(role) === ROLE_PARENT)
        return parentTutoringNav(activeChildId.value);
      if (TUTORING_MENUS[role]) {
        return applyGates(
          TUTORING_MENUS[role]!,
          auth.hasAbility,
          studentCtx,
          academicCtx,
          tutoringCtx,
        );
      }
    }
    // Homeroom-teacher (wali kelas) identity on the SCHOOL surface.
    // `role` here is 'guru' even for a wali kelas — normalizeRole
    // collapses 'wali_kelas' → 'guru' on every auth path, so the ONLY
    // reliable runtime signal for "this teacher owns a homeroom" is
    // `auth.homeroomClasses` (populated from the teacher_profile). When
    // present, swap the plain teacher nav for the homeroom-first
    // WALI_KELAS_NAV so their "Kelas Saya" work leads. Same routes,
    // different ordering — a pure subject teacher (no homeroom) keeps
    // TEACHER_NAV untouched.
    let source = MENUS[role] ?? [];
    if (canonicalRole(role) === ROLE_TEACHER && auth.homeroomClasses.length > 0) {
      source = WALI_KELAS_NAV;
    } else if (canonicalRole(role) === ROLE_STAFF) {
      // Append the admin module sections so a staff with admin RBAC (e.g.
      // Bendahara Umum) can reach them. STRICT for staff: keep ONLY items
      // that carry an explicit ability/abilityAny gate. The blanket admin
      // items — the /admin dashboard, plus Classes/Subjects (context-gated
      // but not ability-gated) — have no per-user gate, and the router is
      // fail-closed for staff on un-gated admin routes, so surfacing them
      // here would only dangle links that bounce straight back. applyGates
      // then drops whatever the staff doesn't actually hold; empty sections
      // fall away. STAFF_NAV's own items (staff home + self check-in + Akun)
      // are always kept.
      const adminModuleSections = ADMIN_NAV.map((sec) => ({
        titleKey: sec.titleKey,
        items: sec.items.filter((it) => it.ability || it.abilityAny),
      }));
      source = [...STAFF_NAV, ...adminModuleSections];
    }
    const gated = applyGates(
      source,
      auth.hasAbility,
      studentCtx,
      academicCtx,
      tutoringCtx,
    );
    // School parent: red-dot the Billing item when there's an
    // outstanding/overdue total. Signal comes from the getStats('wali')
    // response useChildPicker already loads — no extra fetch here.
    if (canonicalRole(role) === ROLE_PARENT && hasOverdueBills.value) {
      return decorateBillingDot(gated);
    }
    return gated;
  });
}

/**
 * Return a copy of the nav with the `/parent/billing` item carrying a
 * red-dot flag. Non-mutating so the static PARENT_NAV const is never
 * touched (it's shared across renders / roles).
 */
function decorateBillingDot(sections: NavSection[]): NavSection[] {
  return sections.map((sec) => ({
    titleKey: sec.titleKey,
    items: sec.items.map((it) =>
      it.to === '/parent/billing' ? { ...it, dot: true } : it,
    ),
  }));
}
