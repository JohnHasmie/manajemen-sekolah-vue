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
 * chip (label + icon) and gate it by intersecting `path` with the
 * parent's already-ability-filtered quick-action list.
 */

export interface ReadinessRouteTarget {
  /** Vue route name — for `router.push({ name, params })`. */
  name: string;
  /** Concrete path — used to intersect with ability-filtered quick actions. */
  path: string;
  /** i18n key for a short chip label. */
  labelKey: string;
  /** NavIcon name for the chip. */
  icon: string;
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
  },
  admin_class_management: {
    name: 'admin.classes',
    path: '/admin/classes',
    labelKey: 'nav.classes',
    icon: 'layers',
  },
  admin_student_management: {
    name: 'admin.students',
    path: '/admin/students',
    labelKey: 'nav.students',
    icon: 'users',
  },
  admin_subject_management: {
    name: 'admin.subjects',
    path: '/admin/subjects',
    labelKey: 'nav.subjects',
    icon: 'book',
  },
  admin_schedule_management: {
    name: 'admin.schedule',
    path: '/admin/schedule',
    labelKey: 'nav.schedule',
    icon: 'calendar',
  },
  admin_academic_year: {
    name: 'admin.settings.manage-academic-years',
    path: '/admin/settings/academic-years',
    labelKey: 'nav.settings',
    icon: 'calendar',
  },
  admin_attendance: {
    name: 'admin.student-attendance',
    path: '/admin/student-attendance',
    labelKey: 'nav.attendance',
    icon: 'check-square',
  },
};

/** Full target for a hint, or null when unmapped. */
export function resolveReadinessTarget(
  hint: string,
): ReadinessRouteTarget | null {
  return READINESS_ROUTE_MAP[hint] ?? null;
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
