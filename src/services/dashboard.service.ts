/**
 * DashboardService — wraps `/dashboard/*` endpoints.
 *
 * Mirrors Flutter's `lib/features/dashboard/data/dashboard_service.dart`.
 *
 * The backend returns role-shaped JSON, so payload types are deliberately
 * loose (`Record<string, unknown>`). Each view destructures the bits it
 * needs. See the Flutter dashboard mixins for the canonical shape.
 */
import { api } from '@/lib/http';
import type { ApiSuccess } from '@/types/api';
import type { Role } from '@/types/auth';

type Payload = Record<string, unknown>;

/**
 * Documented shape of the admin `/dashboard/stats` payload. The service
 * still returns the loose `Payload` type (see `getStats` below) because
 * the JSON schema is role-shaped and evolves per-MR — this interface is
 * a REFERENCE consumers can narrow against without breaking existing
 * `Record<string, any>` reads.
 *
 * MR!523 (backend, edu_core) added the three attendance fields:
 *   attendance_per_class      — null when the caller lacks
 *                               `attendance.student.view` (panel hides);
 *                               [] means the ability is granted but no
 *                               class recorded attendance today.
 *   teacher_attendance_today  — null when the caller lacks
 *                               `attendance.staff.report.view`;
 *                               `{total:0}` = granted but no data yet.
 *   staff_attendance_today    — same gating as teacher_attendance_today.
 */
export interface AdminStatsAttendancePerClass {
  class_id: string;
  class_name: string;
  present_pct: number;
  total: number;
  present: number;
}
export interface AdminStatsAttendanceSummaryToday {
  present_pct: number;
  total: number;
  present: number;
}
export interface AdminStats {
  attendance_rate_today?: number | string | null;
  /**
   * Day-over-day attendance delta in percentage points. MR!527 made this
   * NULLABLE — a school with no prior-day baseline (first day, holiday
   * yesterday) returns `null`, which the UI renders as "—" / hides the
   * delta chip rather than showing a bogus "+97%".
   */
  attendance_delta_pct?: number | null;
  attendance_per_class?: AdminStatsAttendancePerClass[] | null;
  teacher_attendance_today?: AdminStatsAttendanceSummaryToday | null;
  staff_attendance_today?: AdminStatsAttendanceSummaryToday | null;
  /**
   * Total non-teaching staff headcount (MR!527). Absent on older
   * backends — the dashboard KPI tile falls back to "—" when undefined.
   */
  total_staff?: number | null;
  [key: string]: unknown;
}

export interface InboxResponse {
  items: Payload[];
  counts: Record<string, number>;
}

/**
 * Capped Perlu Perhatian response shared by admin + parent endpoints —
 * mirrors Flutter's `({items, total})` tuple. `total` is the unfiltered
 * count so the dashboard header can render "Perlu Perhatian · 5/12".
 */
export interface PriorityInboxResponse {
  items: Payload[];
  total: number;
}

const Endpoints = {
  stats: '/dashboard/stats',
  parentInbox: '/dashboard/parent-inbox',
  parentAcademicRecent: '/dashboard/parent-academic-recent',
  teacherPriorityInbox: '/dashboard/teacher-priority-inbox',
  adminPriorityInbox: '/dashboard/admin-priority-inbox',
  adminPriorityInboxAll: '/dashboard/admin-priority-inbox/all',
  parentPriorityInbox: '/dashboard/parent-priority-inbox',
  parentPriorityInboxAll: '/dashboard/parent-priority-inbox/all',
} as const;

export const DashboardService = {
  /**
   * Aggregated stats for the active role. The shape varies by role:
   *   admin   → { students_count, teachers_count, classes_count, … }
   *   teacher    → { today_sessions, pending_lessons, … }
   *   parent    → { children, attendance, recent_grades, … }
   */
  async getStats(role: Role, academicYearId?: string): Promise<Payload> {
    try {
      const res = await api.get<ApiSuccess<Payload>>(Endpoints.stats, {
        params: {
          role,
          ...(academicYearId ? { academic_year_id: academicYearId } : {}),
        },
      });
      return res.data.data ?? {};
    } catch {
      return {};
    }
  },

  async parentInbox(category = 'all', limit = 50): Promise<InboxResponse> {
    try {
      const res = await api.get(Endpoints.parentInbox, {
        params: { category, limit },
      });
      const body = res.data;
      const items = Array.isArray(body?.data) ? (body.data as Payload[]) : [];
      const counts = (body?.counts ?? {}) as Record<string, number>;
      return { items, counts };
    } catch {
      return { items: [], counts: {} };
    }
  },

  async parentAcademicRecent(limit = 10): Promise<Payload[]> {
    try {
      const res = await api.get<ApiSuccess<Payload[]>>(
        Endpoints.parentAcademicRecent,
        { params: { limit } },
      );
      return res.data.data ?? [];
    } catch {
      return [];
    }
  },

  async teacherPriorityInbox(limit = 50): Promise<InboxResponse> {
    try {
      const res = await api.get(Endpoints.teacherPriorityInbox, {
        params: { limit },
      });
      const body = res.data;
      const items = Array.isArray(body?.data) ? (body.data as Payload[]) : [];
      const counts = (body?.counts ?? {}) as Record<string, number>;
      return { items, counts };
    } catch {
      return { items: [], counts: {} };
    }
  },

  /**
   * Capped admin Perlu Perhatian list. Mirrors Flutter's
   * `getAdminPriorityInbox()` — returns `{ items, total }` so the card
   * header can display "N/total" when the list is capped.
   */
  async adminPriorityInbox(): Promise<PriorityInboxResponse> {
    try {
      const res = await api.get(Endpoints.adminPriorityInbox);
      const body = res.data;
      const items = Array.isArray(body?.data) ? (body.data as Payload[]) : [];
      const totalRaw = body?.total;
      const total =
        typeof totalRaw === 'number' ? totalRaw : Number(totalRaw) || items.length;
      return { items, total };
    } catch {
      return { items: [], total: 0 };
    }
  },

  /** Uncapped admin Perlu Perhatian — backs the "Lihat semua" inbox screen. */
  async adminPriorityInboxAll(): Promise<Payload[]> {
    try {
      const res = await api.get(Endpoints.adminPriorityInboxAll);
      const body = res.data;
      return Array.isArray(body?.data) ? (body.data as Payload[]) : [];
    } catch {
      return [];
    }
  },

  /**
   * Capped parent Perlu Perhatian list. Fans out across every child
   * the parent is parent of unless `studentId` narrows the scope.
   */
  async parentPriorityInbox(
    studentId?: string,
  ): Promise<PriorityInboxResponse> {
    try {
      const params: Record<string, unknown> = {};
      if (studentId) params.student_id = studentId;
      const res = await api.get(Endpoints.parentPriorityInbox, { params });
      const body = res.data;
      const items = Array.isArray(body?.data) ? (body.data as Payload[]) : [];
      const totalRaw = body?.total;
      const total =
        typeof totalRaw === 'number' ? totalRaw : Number(totalRaw) || items.length;
      return { items, total };
    } catch {
      return { items: [], total: 0 };
    }
  },

  /** Uncapped parent Perlu Perhatian — backs the parent "Lihat semua" screen. */
  async parentPriorityInboxAll(studentId?: string): Promise<Payload[]> {
    try {
      const params: Record<string, unknown> = {};
      if (studentId) params.student_id = studentId;
      const res = await api.get(Endpoints.parentPriorityInboxAll, { params });
      const body = res.data;
      return Array.isArray(body?.data) ? (body.data as Payload[]) : [];
    } catch {
      return [];
    }
  },
};
