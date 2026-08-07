/**
 * TutoringAdminDashboardService — greenfield admin bimbel dashboard
 * client (BE-27).
 *
 *   GET /tutoring-v2/admin/stats     headline KPI aggregate
 *   GET /tutoring-v2/admin/activity  tenant activity feed (30 days)
 *
 * ⚠ Path shape — these live at `/admin/stats` + `/admin/activity`
 * (slash), NOT `/admin-stats` + `/admin-activity` (hyphen). The
 * hyphenated pair is the LEGACY `/tutoring/*` surface served by
 * `TutoringLegacy\...\TutoringAdminStatsController`, which carries the
 * `log.legacy-tutoring` middleware and is exactly what CLEAN-2 is
 * retiring. Verified against `routes/api.php` inside the
 * `Route::prefix('tutoring-v2')` group — there is no hyphenated route
 * in it.
 *
 * Both endpoints authorize on `dashboard.admin.view` (NOT
 * `tutoring.dashboard.view`, which tutors also hold), so a tutor
 * hitting these gets 403.
 *
 * Every method returns the UNWRAPPED payload, per the tutoring2
 * service convention.
 */
import { api } from '@/lib/http';
import type {
  AdminActivityEvent,
  AdminActivityMeta,
  AdminActivityParams,
  AdminDashboardStats,
} from '@/types/tutoring2/dashboard';

interface OneEnvelope<T> {
  data: T;
}

interface ActivityEnvelope {
  data: AdminActivityEvent[];
  meta?: AdminActivityMeta;
}

export interface AdminActivityResult {
  items: AdminActivityEvent[];
  meta: AdminActivityMeta | undefined;
}

export const TutoringAdminDashboardService = {
  /** GET /tutoring-v2/admin/stats */
  async getStats(): Promise<AdminDashboardStats> {
    const r = await api.get<OneEnvelope<AdminDashboardStats>>('/tutoring-v2/admin/stats');
    return r.data.data;
  },

  /** GET /tutoring-v2/admin/activity */
  async listActivity(params: AdminActivityParams = {}): Promise<AdminActivityResult> {
    const r = await api.get<ActivityEnvelope>('/tutoring-v2/admin/activity', { params });
    return { items: r.data.data, meta: r.data.meta };
  },
};
