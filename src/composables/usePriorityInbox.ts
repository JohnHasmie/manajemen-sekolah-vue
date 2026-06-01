/**
 * usePriorityInbox — shared parser + tap router for the
 * "Perlu Perhatian" priority inbox feed.
 *
 * The backend returns a generic shape for all three roles:
 *   { id, type, severity, label, subtitle, count, occurred_at,
 *     target_route, target_params }
 *
 * Mirrors Flutter's `PriorityInboxItem.parseList` + the
 * per-role tap routers in each dashboard.
 *
 * Usage:
 *   const { mapToPriorityItems, handlePriorityTap, totalLabel }
 *     = usePriorityInbox('teacher');
 *
 *   const items = computed(() => mapToPriorityItems(rawItems.value));
 *   <PriorityInbox :items="items" @itemTap="handlePriorityTap" />
 */
import { useRouter } from 'vue-router';
import type { PriorityItem } from '@/components/feature/PriorityInbox.vue';

export type PriorityRole = 'admin' | 'teacher' | 'parent';

type RouteMap = Record<string, string>;

/**
 * `target_route` strings the backend ships per role.
 *
 * Same keys may appear across roles but point to different Vue
 * routes (e.g. `lesson_plan_detail` → admin RPP review hub vs
 * teacher RPP list). Falling through to the default does nothing,
 * matching Flutter's behaviour.
 */
const ROUTE_MAPS: Record<PriorityRole, RouteMap> = {
  teacher: {
    teacher_attendance: '/teacher/attendance',
    attendance: '/teacher/attendance',
    lesson_plan_detail: '/teacher/lesson-plans',
    lesson_plan: '/teacher/lesson-plans',
    rpp: '/teacher/lesson-plans',
    report_card_class: '/teacher/report-cards',
    report_card: '/teacher/report-cards',
    grade_book: '/teacher/grades',
    grade_input: '/teacher/grades',
    grade: '/teacher/grades',
    recommendation_detail: '/teacher/recommendations',
    recommendation: '/teacher/recommendations',
    material: '/teacher/materials',
    class_activity: '/teacher/class-activity',
    announcement: '/teacher/announcements',
  },
  admin: {
    lesson_plan_detail: '/admin/lesson-plans',
    lesson_plan: '/admin/lesson-plans',
    rpp: '/admin/lesson-plans',
    teacher: '/admin/teachers',
    student: '/admin/students',
    classroom: '/admin/classrooms',
    subject: '/admin/subjects',
    schedule: '/admin/schedules',
    finance: '/admin/finance',
    payment_verification: '/admin/finance',
    announcement: '/admin/announcements',
    attendance: '/admin/attendance',
    class_activity: '/admin/class-activity',
    grade: '/admin/grade-overview',
    report_card: '/admin/report-cards',
    report_card_class: '/admin/report-cards',
    settings: '/admin/settings',
  },
  parent: {
    billing: '/parent/billing',
    payment: '/parent/billing',
    tagihan: '/parent/billing',
    grade: '/parent/grades',
    grades: '/parent/grades',
    nilai: '/parent/grades',
    attendance: '/parent/attendance',
    kehadiran: '/parent/attendance',
    class_activity: '/parent/class-activity',
    aktivitas: '/parent/class-activity',
    announcement: '/parent/announcements',
    pengumuman: '/parent/announcements',
    report_card: '/parent/report-cards',
    raport: '/parent/report-cards',
    recommendation: '/parent/recommendations',
    rekomendasi: '/parent/recommendations',
  },
};

export function usePriorityInbox(role: PriorityRole) {
  const router = useRouter();
  const routes = ROUTE_MAPS[role];

  /**
   * Parse a raw backend payload array into typed PriorityItems.
   * Skips any row missing the minimal required fields so the UI
   * never renders broken rows.
   */
  function mapToPriorityItems(raw: unknown): PriorityItem[] {
    if (!Array.isArray(raw)) return [];
    const out: PriorityItem[] = [];
    for (const r of raw as Array<Record<string, unknown>>) {
      if (!r || typeof r !== 'object') continue;
      const id = r.id;
      const type = r.type;
      const label = r.label;
      const subtitle = r.subtitle ?? '';
      if (!id || !type || !label) continue;
      const severityRaw = r.severity;
      const severity: PriorityItem['severity'] =
        severityRaw === 'critical' || severityRaw === 'warning'
          ? severityRaw
          : 'info';
      out.push({
        id: String(id),
        type: String(type),
        severity,
        label: String(label),
        subtitle: String(subtitle ?? ''),
        count: typeof r.count === 'number' ? r.count : Number(r.count) || 1,
        occurred_at: String(r.occurred_at ?? new Date().toISOString()),
        target_route: String(r.target_route ?? ''),
        target_params:
          (r.target_params as Record<string, unknown>) ?? {},
      });
    }
    return out;
  }

  /**
   * Navigate to the per-role target route for an item. Falls
   * through silently for unknown routes (matches Flutter).
   *
   * Resolves both `target_route` and a fallback derived from `type`
   * — backend sometimes ships only one.
   */
  function handlePriorityTap(item: PriorityItem): void {
    const targets = [item.target_route, item.type].filter(
      (t): t is string => typeof t === 'string' && t.length > 0,
    );
    for (const key of targets) {
      const path = routes[key];
      if (path) {
        router.push({
          path,
          query: pickQueryParams(item.target_params),
        });
        return;
      }
    }
  }

  /** Pass through scalar `target_params` as router query params. */
  function pickQueryParams(
    params: Record<string, unknown>,
  ): Record<string, string> {
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(params ?? {})) {
      if (v == null) continue;
      if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
        out[k] = String(v);
      }
    }
    return out;
  }

  /**
   * Build the "N" or "N/M" header label given the visible item count
   * and an optional `total` (from `priority_inbox_total` /
   * `/admin-priority-inbox` envelope's `total` field).
   */
  function priorityCountLabel(visible: number, total?: number): string {
    if (typeof total === 'number' && total > visible) {
      return `${visible}/${total}`;
    }
    return `${visible}`;
  }

  return { mapToPriorityItems, handlePriorityTap, priorityCountLabel };
}
