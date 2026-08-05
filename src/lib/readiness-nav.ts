/**
 * readiness-nav — single source of truth for mapping the backend
 * `/admin/readiness` route hints onto real Vue routes + chip metadata.
 *
 * Both readiness lanes carry a `target_route` that is a snake_case
 * BACKEND hint (e.g. `admin_student_management`), NOT a literal Vue
 * route name. The backend stays agnostic to the FE router shape, so the
 * FE owns this translation. It used to live inline in
 * AdminReadinessView.vue; three surfaces now need it — the full page,
 * the dashboard "Perlu Perhatian" panel, and the control-center
 * contextual chips — so it is centralised here to avoid drift.
 *
 * Each entry also carries `path`, `labelKey` and `icon` so the
 * control-center card can render a compact "jump to what's incomplete"
 * chip (label + icon).
 *
 * ACCESS IS PART OF THE MAP. Every entry declares the gate its
 * destination actually enforces (`requiredAbilities` + `requiredContext`),
 * copied VERBATIM from the matching entry in `useNavMenu.ts` (or, for a
 * destination the sidebar doesn't front, from that route's `meta` in
 * `router/index.ts`). Before this, the map carried destination only, so
 * every consumer improvised its own gate: the contextual chips
 * intersected the resolved `path` against the parent's already-filtered
 * `quickActions`, and the Lane B rows had NO gate at all — an admin
 * without the finance module was shown "Verifikasi pembayaran" and
 * tapped into a 403. One map, one gate, every surface.
 *
 * Mobile parity: `lib/features/readiness/presentation/readiness_todo_router.dart`
 * carries the same table key-for-key. Change one, change both.
 */

export interface ReadinessRouteTarget {
  /** Vue route name — for `router.push({ name, params })`. */
  name: string;
  /** Concrete path — for `router.push(path)`. */
  path: string;
  /** i18n key for a short chip label. */
  labelKey: string;
  /** NavIcon name for the chip. */
  icon: string;
  /**
   * Abilities that admit the destination, ANY-OF: holding at least one
   * is enough (mirrors `NavItem.abilityAny`; a single-element array is
   * the `NavItem.ability` case). An EMPTY array means the destination
   * carries no ability gate in the nav either — see the two
   * context-only entries below.
   */
  requiredAbilities: readonly string[];
  /**
   * Module-context gate, mirroring `NavItem.needs`. Some destinations
   * are backed by CORE permissions every tenant holds, so the ability
   * gate alone leaves them reachable-but-dead when the tenant owns no
   * module that consumes the entity.
   */
  requiredContext?: 'student-context' | 'academic-context';
}

/**
 * Minimal slice of the `me` store this module needs. Declared
 * structurally so `useMeStore()` satisfies it without an import here —
 * keeps this map a pure lib, and keeps it unit-testable with a literal.
 */
export interface ReadinessAccess {
  canAny(abilities: Iterable<string>): boolean;
  hasStudentContext: boolean;
  hasAcademicContext: boolean;
}

/**
 * Backend Lane-A/B `target_route` hints → Vue route + chip metadata.
 * Keys mirror the backend readiness check catalogue; keep in lockstep
 * with the server's `target_route` emitter.
 */
export const READINESS_ROUTE_MAP: Record<string, ReadinessRouteTarget> = {
  admin_teacher_management: {
    name: 'admin.teachers',
    path: '/admin/teachers',
    labelKey: 'nav.teachers',
    icon: 'user-check',
    // nav: /admin/teachers
    requiredAbilities: ['school.teacher.view', 'school.teacher.manage'],
  },
  admin_class_management: {
    name: 'admin.classes',
    path: '/admin/classes',
    labelKey: 'nav.classes',
    icon: 'layers',
    // nav: /admin/classes — context-gated ONLY, no ability in the nav
    // entry (school.class.* backs the oversight page, not this one), so
    // there is no precedent to copy and we deliberately leave it open.
    requiredAbilities: [],
    requiredContext: 'student-context',
  },
  admin_student_management: {
    name: 'admin.students',
    path: '/admin/students',
    labelKey: 'nav.students',
    icon: 'users',
    // nav: /admin/students
    requiredAbilities: ['school.student.view', 'school.student.manage'],
    requiredContext: 'student-context',
  },
  admin_subject_management: {
    name: 'admin.subjects',
    path: '/admin/subjects',
    labelKey: 'nav.subjects',
    icon: 'book',
    // nav: /admin/subjects — context-gated ONLY, same as Kelas above.
    requiredAbilities: [],
    requiredContext: 'academic-context',
  },
  admin_schedule_management: {
    name: 'admin.schedule',
    path: '/admin/schedule',
    labelKey: 'nav.schedule',
    icon: 'calendar',
    // nav: /admin/schedule
    requiredAbilities: ['academic.schedule.view'],
  },

  // ── Lane B (Perlu Perhatian) — operational targets ────────────────
  //
  // These were emitted by the backend from the start but never mapped
  // here, so every operational row rendered as a dead card: the backend
  // deliberately tolerates unknown hints by dropping the onTap, which
  // meant the omission failed silently instead of erroring.
  admin_announcement_drafts: {
    name: 'admin.announcements',
    path: '/admin/announcements',
    labelKey: 'nav.announcements',
    icon: 'megaphone',
    // nav: /admin/announcements
    requiredAbilities: ['communication.announcement.view'],
  },
  admin_overdue_bills: {
    name: 'admin.finance.bills',
    path: '/admin/finance/bills',
    labelKey: 'nav.finance',
    icon: 'wallet',
    // nav: /admin/finance (the hub redirects here); the route's own
    // meta carries the same key.
    requiredAbilities: ['finance.bill.view'],
  },
  admin_payment_verification: {
    name: 'admin.finance.payments',
    path: '/admin/finance/payments',
    labelKey: 'nav.finance',
    icon: 'credit-card',
    // NOT finance.bill.view. The sidebar only fronts the hub, but the
    // Pembayaran child route's meta gates on its own key — an admin with
    // bills-only access is bounced by the router guard, so the row has to
    // drop for exactly the same set of users.
    requiredAbilities: ['finance.payment.view'],
  },
  admin_report_card_hub: {
    name: 'admin.report-cards',
    path: '/admin/report-cards',
    labelKey: 'nav.reportCards',
    icon: 'file-text',
    // nav: /admin/report-cards
    requiredAbilities: ['academic.report_card.view'],
  },
  admin_rpp_review: {
    name: 'admin.lesson-plans',
    path: '/admin/lesson-plans',
    labelKey: 'nav.lessonPlans',
    icon: 'clipboard-list',
    // nav: /admin/lesson-plans
    requiredAbilities: ['academic.lesson_plan.view'],
  },
  // Conflicts live on the schedule hub itself — there is no separate
  // conflicts screen, and the hub surfaces them inline with a red badge.
  admin_schedule_conflicts: {
    name: 'admin.schedule',
    path: '/admin/schedule',
    labelKey: 'nav.schedule',
    icon: 'alert-triangle',
    // nav: /admin/schedule — same destination, same gate.
    requiredAbilities: ['academic.schedule.view'],
  },
  admin_staff_attendance_report: {
    name: 'admin.teacher-attendance.report',
    path: '/admin/teacher-attendance/report',
    labelKey: 'nav.teacherAttendance',
    icon: 'camera',
    // nav: /admin/teacher-attendance/report
    requiredAbilities: ['attendance.staff.report.view'],
  },
  admin_academic_year: {
    name: 'admin.settings.manage-academic-years',
    // Was `/admin/settings/academic-years`, which matches no route —
    // the alerts grid pushes by PATH, so a Lane B academic-year row was
    // navigating into a 404. The router path is `manage-academic-years`.
    path: '/admin/settings/manage-academic-years',
    labelKey: 'nav.settings',
    icon: 'calendar',
    // nav: /admin/settings (the hub that fronts this page); the route's
    // own meta carries the same pair.
    requiredAbilities: ['school.settings.view', 'school.settings.manage'],
  },
  admin_attendance: {
    name: 'admin.student-attendance',
    path: '/admin/student-attendance',
    labelKey: 'nav.attendance',
    icon: 'check-square',
    // nav: /admin/student-attendance
    requiredAbilities: ['attendance.student.view', 'attendance.student.export'],
  },
  // WA blast trigger (MR-C) — jump-off from the "guru belum instal
  // aplikasi mobile" readiness lane item (MR-A).
  admin_mobile_app_broadcast: {
    name: 'admin.mobile-app-broadcast',
    path: '/admin/mobile-app-broadcast',
    labelKey: 'readiness.actions.mobile_app_broadcast',
    icon: 'brand-whatsapp',
    // No sidebar entry (it is a remedial jump-off, not a destination you
    // browse to), so the gate comes from the route's own meta. In
    // practice a no-op: every surface that can render this hint already
    // requires readiness.view to render at all.
    requiredAbilities: ['readiness.view'],
  },
};

/** Full target for a hint, or null when unmapped. */
export function resolveReadinessTarget(
  hint: string,
): ReadinessRouteTarget | null {
  return READINESS_ROUTE_MAP[hint] ?? null;
}

/**
 * Whether this user can actually OPEN the destination a hint points at.
 *
 * The single gate every readiness surface uses:
 *   · Lane B rows — DROPPED when false. They are unscored operational
 *     nudges, so hiding one costs nothing and showing one the user can't
 *     open costs a 403.
 *   · Lane A rows — kept VISIBLE but rendered non-tappable when false.
 *     They drive the score, and silently hiding one makes an 83% that
 *     the admin can't account for.
 *   · Contextual chips — dropped when false (they are pure shortcuts).
 *
 * An UNMAPPED hint returns true: those fall back to the full Pusat
 * Kendali page, which the caller already holds `readiness.view` for.
 * That keeps a mid-session backend schema drift visible instead of
 * silently blanking the lane.
 *
 * Pass the `me` store directly — it satisfies [ReadinessAccess]
 * structurally, and reading its fields inside a computed keeps the
 * result reactive to /me hydration.
 */
export function canReachReadinessTarget(
  hint: string,
  access: ReadinessAccess,
): boolean {
  const target = READINESS_ROUTE_MAP[hint];
  if (!target) return true;
  if (
    target.requiredAbilities.length > 0 &&
    !access.canAny(target.requiredAbilities)
  ) {
    return false;
  }
  if (target.requiredContext === 'student-context') {
    return access.hasStudentContext;
  }
  if (target.requiredContext === 'academic-context') {
    return access.hasAcademicContext;
  }
  return true;
}

/**
 * Vue route NAME for a backend hint, or null when unmapped. Logs a warn
 * on a miss so a mid-session backend schema drift is visible in QA
 * (parity with the old inline `mapRouteName`).
 */
export function resolveReadinessRouteName(hint: string): string | null {
  const target = READINESS_ROUTE_MAP[hint];
  if (!target) {
    // eslint-disable-next-line no-console
    console.warn(`[readiness-nav] Unmapped target_route: ${hint}`);
    return null;
  }
  return target.name;
}
