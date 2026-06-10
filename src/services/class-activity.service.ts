/**
 * ClassActivityService — `/api/class-activity` + `/api/class-activities` wrapper.
 *
 * Mirrors Flutter's `ApiClassActivityService` plus the helper splits
 * (`*_query_helper.dart`, `*_crud_helper.dart`). Endpoint matrix:
 *
 *   GET    /class-activity            paginated list (legacy)
 *   GET    /class-activity/{id}       full detail (description + submissions roster)
 *   POST   /class-activity            create
 *   PUT    /class-activity/{id}       update
 *   DELETE /class-activity/{id}       delete
 *   GET    /class-activity/{id}/submissions      per-student roster
 *   POST   /class-activity/{id}/submissions      bulk-upsert status/score
 *   POST   /class-activity/mark-read              parent batch mark-as-read
 *   GET    /class-activity/unread-count           parent badge counter
 *   GET    /class-activities/teacher-summary      teacher hub
 *   GET    /class-activities/admin-summary        admin hub
 *
 * `academic_year_id` is auto-injected by the axios interceptor for
 * GETs. Submission payloads carry the period scope implicitly via
 * the activity's stored academic_year_id.
 */
import { api } from '@/lib/http';
import { localISODate } from '@/lib/format';
import type { Pagination } from '@/types/api';
import {
  activitySubmissionRowFromJson,
  adminActivitySummaryPageFromJson,
  classActivityFromJson,
  teacherActivitySummaryPageFromJson,
  type ActivityPeriod,
  type ActivitySubmissionRow,
  type ActivityType,
  type AdminActivitySummaryPage,
  type ClassActivity,
  type SubmissionStatus,
  type TeacherActivitySummaryPage,
} from '@/types/class-activity';

// ── List params ──

export interface ClassActivityListParams {
  teacher_id?: string;
  class_id?: string;
  subject_id?: string;
  /** Single-day filter — YYYY-MM-DD. */
  date?: string;
  /** Inclusive window — YYYY-MM-DD. */
  start_date?: string;
  end_date?: string;
  /** Convenience helper — computes start_date from today minus N days. */
  range_days?: number;
  search?: string;
  type?: ActivityType;
  page?: number;
  per_page?: number;
}

export interface AdminSummaryParams {
  /** Period chip ("today" | "7d" | "30d" | "semester" | "year"). */
  period?: ActivityPeriod;
  class_id?: string;
  subject_id?: string;
  teacher_id?: string;
  type?: ActivityType;
  search?: string;
  page?: number;
  per_page?: number;
}

export interface ListResult {
  items: ClassActivity[];
  pagination?: Pagination;
}

function computeWindow(
  startDate: string | undefined,
  endDate: string | undefined,
  rangeDays: number | undefined,
): { start_date?: string; end_date?: string } {
  if (startDate || endDate) return { start_date: startDate, end_date: endDate };
  if (!rangeDays || rangeDays <= 0) return {};
  const today = new Date();
  const start = new Date(today);
  start.setDate(today.getDate() - rangeDays);
  return {
    start_date: localISODate(start),
    end_date: localISODate(today),
  };
}

export const ClassActivityService = {
  /**
   * Legacy paginated list — kept for screens that still pre-date the
   * teacher-summary endpoint (parent feed). Returns plain items + the
   * Laravel pagination envelope.
   */
  async list(params: ClassActivityListParams = {}): Promise<ListResult> {
    const window = computeWindow(
      params.start_date,
      params.end_date,
      params.range_days,
    );
    try {
      const res = await api.get('/class-activity', {
        params: {
          ...(params.teacher_id ? { teacher_id: params.teacher_id } : {}),
          ...(params.class_id ? { class_id: params.class_id } : {}),
          ...(params.subject_id ? { subject_id: params.subject_id } : {}),
          ...(params.date ? { date: params.date } : {}),
          ...(window.start_date ? { start_date: window.start_date } : {}),
          ...(window.end_date ? { end_date: window.end_date } : {}),
          ...(params.search ? { search: params.search } : {}),
          ...(params.type ? { type: params.type } : {}),
          page: params.page ?? 1,
          limit: params.per_page ?? 30,
        },
      });
      const body = res.data;
      const data = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return {
        items: data.map((r: Record<string, unknown>) =>
          classActivityFromJson(r),
        ),
        pagination: body?.pagination,
      };
    } catch {
      return { items: [] };
    }
  },

  /**
   * Teacher hub envelope — items + tiny KPI. Backend already scopes
   * by the active school via the X-School-ID interceptor + the
   * resolved teacher_id (school-aware via Teacher::resolveId after
   * the Phase 5 controller patch).
   */
  async getTeacherSummary(args: {
    teacher_id: string;
    period?: ActivityPeriod;
    class_id?: string;
    subject_id?: string;
    type?: ActivityType;
    search?: string;
    page?: number;
    per_page?: number;
  }): Promise<TeacherActivitySummaryPage> {
    const res = await api.get('/class-activities/teacher-summary', {
      params: {
        teacher_id: args.teacher_id,
        ...(args.period ? { period: args.period } : {}),
        ...(args.class_id ? { class_id: args.class_id } : {}),
        ...(args.subject_id ? { subject_id: args.subject_id } : {}),
        ...(args.type ? { type: args.type } : {}),
        ...(args.search ? { search: args.search } : {}),
        page: args.page ?? 1,
        limit: args.per_page ?? 30,
      },
    });
    return teacherActivitySummaryPageFromJson(
      (res.data ?? {}) as Record<string, unknown>,
    );
  },

  /**
   * Admin hub — paginated school-wide list with KPI block. Drives
   * the AdminClassActivityView dashboard's type tabs + filter chips.
   */
  async getAdminSummary(
    params: AdminSummaryParams = {},
  ): Promise<AdminActivitySummaryPage> {
    const res = await api.get('/class-activities/admin-summary', {
      params: {
        ...(params.period ? { period: params.period } : {}),
        ...(params.class_id ? { class_id: params.class_id } : {}),
        ...(params.subject_id ? { subject_id: params.subject_id } : {}),
        ...(params.teacher_id ? { teacher_id: params.teacher_id } : {}),
        ...(params.type ? { type: params.type } : {}),
        ...(params.search ? { search: params.search } : {}),
        page: params.page ?? 1,
        limit: params.per_page ?? 30,
      },
    });
    return adminActivitySummaryPageFromJson(
      (res.data ?? {}) as Record<string, unknown>,
    );
  },

  /**
   * Full activity detail — pulled on demand when a card is tapped.
   * Includes the `description`, materi reference, attachments, and
   * sometimes a small `submissions_summary` block.
   */
  async getDetail(id: string): Promise<ClassActivity | null> {
    try {
      const res = await api.get(`/class-activity/${id}`);
      const body = res.data;
      const raw = (body?.data ?? body) as Record<string, unknown>;
      if (!raw || !raw.id) return null;
      return classActivityFromJson(raw);
    } catch {
      return null;
    }
  },

  async create(payload: Record<string, unknown>): Promise<ClassActivity> {
    const res = await api.post('/class-activity', payload);
    const body = res.data;
    return classActivityFromJson(
      ((body?.data ?? body) ?? {}) as Record<string, unknown>,
    );
  },

  async update(
    id: string,
    payload: Record<string, unknown>,
  ): Promise<ClassActivity> {
    const res = await api.put(`/class-activity/${id}`, payload);
    const body = res.data;
    return classActivityFromJson(
      ((body?.data ?? body) ?? {}) as Record<string, unknown>,
    );
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/class-activity/${id}`);
  },

  // ── Submission tracking (teacher "Catat Submit") ──

  /**
   * Per-student submission roster for one activity. Used by the
   * Catat Submit modal to seed the per-row picker. Backend ships
   * every student in the activity's audience — even those without
   * a saved row — with status "pending" by default.
   */
  async listSubmissions(activityId: string): Promise<ActivitySubmissionRow[]> {
    try {
      const res = await api.get(`/class-activity/${activityId}/submissions`);
      const body = res.data;
      const arr = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return arr.map((r: Record<string, unknown>) =>
        activitySubmissionRowFromJson(r),
      );
    } catch {
      return [];
    }
  },

  /**
   * Bulk upsert per-student status (+ optional score & note). Backend
   * wraps the rows in a single `INSERT ... ON CONFLICT DO UPDATE` so
   * a class of 40 students = 1 round trip.
   */
  async upsertSubmissions(
    activityId: string,
    rows: ActivitySubmissionRow[],
  ): Promise<{ success: boolean; saved?: number; error?: string }> {
    // Contract (matches the backend UpsertSubmissionsAction + the mobile
    // client): the bulk-upsert expects `{ rows: [{ student_id, status,
    // score?, note? }] }`. This service previously sent `submissions` +
    // `student_class_id` + `notes`, so the controller read an empty `rows`
    // and returned 422 ("rows harus berupa array yang tidak kosong") on
    // every save. Aligned the key and per-row field names.
    const payload = {
      rows: rows.map((r) => ({
        student_id: r.student_id,
        status: r.status,
        ...(r.score !== null && r.score !== undefined ? { score: r.score } : {}),
        ...(r.notes ? { note: r.notes } : {}),
      })),
    };
    const res = await api.post(
      `/class-activity/${activityId}/submissions`,
      payload,
    );
    return res.data;
  },

  // ── Parent read tracking ──

  /**
   * Batch-mark activities as read for the calling parent. Triggered
   * by `IntersectionObserver` once a card has been visible for ≥1s.
   * Empty arrays are no-ops on the backend.
   */
  async markAsRead(activityIds: string[]): Promise<void> {
    if (activityIds.length === 0) return;
    await api.post('/class-activity/mark-read', { ids: activityIds });
  },

  /**
   * Unread badge counter — used on parent role's dashboard pill.
   * Returns 0 on any failure so the badge degrades silently.
   */
  async getUnreadCount(): Promise<number> {
    try {
      const res = await api.get('/class-activity/unread-count');
      const body = res.data;
      const raw = (body?.data ?? body) as { count?: unknown } | number;
      if (typeof raw === 'number') return raw;
      if (typeof raw?.count === 'number') return raw.count;
      const n = Number(raw?.count ?? 0);
      return Number.isFinite(n) ? n : 0;
    } catch {
      return 0;
    }
  },
};

// Re-export the submission helper types so views can `import { ... }
// from '@/services/class-activity.service'` without bouncing through
// the types file separately.
export type { SubmissionStatus };
