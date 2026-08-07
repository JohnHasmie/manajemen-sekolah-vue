/**
 * Type contracts for the greenfield admin bimbel dashboard (BE-27).
 *
 * Mirrors `App\Modules\Tutoring\Http\Controllers\AdminStatsController`:
 *
 *   GET /api/tutoring-v2/admin/stats     → { data: AdminDashboardStats }
 *   GET /api/tutoring-v2/admin/activity  → { data: AdminActivityEvent[], meta }
 *
 * ⚠ Wire-key note — the `billing` bucket ships THREE Indonesian keys
 * (`tertagih` / `terbayar` / `menunggak`). That is the backend's
 * existing contract, shared verbatim with `BimbelBillsSummary` in
 * `@/services/tutoring-bimbel.service`; the greenfield
 * `BillController::summary` emits the exact same four keys. We honour
 * the wire rather than renaming client-side, because a local alias
 * would make the payload ungreppable against the controller. Every
 * identifier we own in this file is English.
 */

/** `GET /tutoring-v2/admin/stats` — every bucket is always present. */
export interface AdminDashboardStats {
  students: {
    /** Distinct students that have EVER been enrolled at this tenant. */
    total: number;
    active_enrollments: number;
    trial: number;
  };
  sessions: {
    today: number;
    this_week: number;
    /** 0..1 ratio (hadir / total attendance rows over the last 7 days). */
    attendance_rate_7d: number;
  };
  assessments: {
    published_this_month: number;
    /** 0 when nothing was graded this month (not null). */
    avg_score_this_month: number;
  };
  billing: {
    /** Total billed. Indonesian wire key — see the file header. */
    tertagih: number;
    /** Total paid. */
    terbayar: number;
    /** Total unpaid AND past due. */
    menunggak: number;
    overdue_count: number;
  };
  leads: {
    new_this_week: number;
    converted_this_month: number;
  };
}

/**
 * Event flavours emitted by the merged feed. The `?type=` query param
 * filters on the CATEGORY (the leading segment), not the flavour — so
 * `type=bill` returns both `bill_created` and `bill_paid`.
 */
export type AdminActivityEventType =
  | 'bill_created'
  | 'bill_paid'
  | 'session_done'
  | 'enrollment_created'
  | 'assessment_published'
  | 'feedback_submitted'
  | 'lead_converted';

/** Accepted values for the `?type=` narrowing param. */
export type AdminActivityCategory =
  | 'bill'
  | 'session'
  | 'enrollment'
  | 'assessment'
  | 'feedback'
  | 'lead';

/**
 * One row of the tenant activity feed (last 30 days).
 *
 * `snippet` is composed server-side and already localised to
 * Indonesian ("Tagihan Rp 250.000 dibuat"). There is no structured
 * payload behind it, so the view renders it as-is rather than
 * re-deriving copy from `type`.
 */
export interface AdminActivityEvent {
  type: AdminActivityEventType;
  /** ISO-8601 with offset. Nullable where the source timestamp was. */
  at: string | null;
  actor_name: string | null;
  subject_name: string | null;
  snippet: string | null;
}

/**
 * Feed pagination. Deliberately NOT `@/types/api`'s `Pagination` —
 * this endpoint paginates in memory and emits Laravel's
 * `current_page / per_page / total / last_page` quartet, not the
 * `total_items / has_next_page` shape that type describes.
 */
export interface AdminActivityMeta {
  current_page: number;
  per_page: number;
  total: number;
  last_page: number;
}

/** Query params for `GET /tutoring-v2/admin/activity`. */
export interface AdminActivityParams {
  page?: number;
  /** Server clamps to 1..50; default 20. */
  per_page?: number;
  type?: AdminActivityCategory;
}
