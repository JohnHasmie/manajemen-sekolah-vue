/**
 * AnnouncementService — /announcement/* wrapper.
 *
 * Used by every role:
 *   - admin   → broadcast (full CRUD + lifecycle filter)
 *   - teacher → own-class compose + own KPI strip
 *   - parent  → read inbox with unread tracking
 *
 * Mirrors Flutter's `ApiAnnouncementService` shape — paginated list,
 * filter-options bundle, mark-as-read, plus the admin-only
 * audience-reach preview.
 */
import { api } from '@/lib/http';
import {
  announcementFromJson,
  type Announcement,
  type AnnouncementAudience,
  type AnnouncementCategory,
  type AnnouncementFilterOptions,
  type AnnouncementPriority,
  type AnnouncementStatus,
} from '@/types/announcements';
import type { Pagination } from '@/types/api';

interface ListParams {
  page?: number;
  per_page?: number;
  priority?: AnnouncementPriority | null;
  status?: AnnouncementStatus | null;
  audience?: AnnouncementAudience | null;
  search?: string;
}

interface ListResult {
  items: Announcement[];
  pagination?: Pagination;
}

function unwrapItems(body: unknown): unknown[] {
  if (Array.isArray(body)) return body;
  if (body && typeof body === 'object') {
    const b = body as { data?: unknown };
    if (Array.isArray(b.data)) return b.data;
  }
  return [];
}

export const AnnouncementService = {
  /**
   * Paginated `/announcement` listing.
   *
   * Backend filter keys (canonical English post-rename):
   *   priority    → 'low' | 'normal' | 'high' | 'urgent'
   *   status      → 'draft' | 'scheduled' | 'published' | 'expired' | 'archived'
   *   role_target → 'all' | 'teacher' | 'student' | 'parent' | 'admin'
   *   search      → free-text
   */
  async list(params: ListParams = {}): Promise<ListResult> {
    try {
      const res = await api.get('/announcement', {
        params: {
          page: params.page ?? 1,
          per_page: params.per_page ?? 50,
          ...(params.priority ? { priority: params.priority } : {}),
          ...(params.status ? { status: params.status } : {}),
          ...(params.audience ? { role_target: params.audience } : {}),
          ...(params.search ? { search: params.search } : {}),
        },
      });
      const body = res.data;
      const rows = unwrapItems(body);
      const pagination =
        body && typeof body === 'object' && 'pagination' in body
          ? ((body as { pagination?: Pagination }).pagination ?? undefined)
          : undefined;
      return {
        items: rows.map((r) =>
          announcementFromJson(r as Record<string, unknown>),
        ),
        pagination,
      };
    } catch {
      return { items: [] };
    }
  },

  /**
   * `/announcement/filter-options` — drop-in for the admin filter
   * sheet. Backend ships `{priority_options, target_options,
   * status_options}` each with `{value, label}` rows.
   *
   * Falls back to a safe default list so the UI keeps rendering.
   */
  async filterOptions(): Promise<AnnouncementFilterOptions> {
    try {
      const res = await api.get('/announcement/filter-options');
      const body = res.data?.data ?? res.data ?? {};
      const map = (rows: unknown): { value: string; label: string }[] =>
        Array.isArray(rows)
          ? (rows as Array<Record<string, unknown>>).map((r) => ({
              value: String(r.value ?? r.id ?? ''),
              label: String(r.label ?? r.name ?? r.value ?? ''),
            }))
          : [];
      return {
        priority_options: map(body.priority_options),
        target_options: map(body.target_options),
        status_options: map(body.status_options),
      };
    } catch {
      // Canonical English values match the backend post-rename;
      // labels stay Indonesian.
      return {
        priority_options: [
          { value: 'urgent', label: 'Mendesak' },
          { value: 'high', label: 'Penting' },
          { value: 'normal', label: 'Biasa' },
          { value: 'low', label: 'Rendah' },
        ],
        target_options: [
          { value: 'all', label: 'Semua' },
          { value: 'teacher', label: 'Guru' },
          { value: 'student', label: 'Siswa' },
          { value: 'parent', label: 'Wali' },
        ],
        status_options: [
          { value: 'draft', label: 'Draft' },
          { value: 'scheduled', label: 'Terjadwal' },
          { value: 'published', label: 'Terkirim' },
          { value: 'expired', label: 'Kedaluwarsa' },
          { value: 'archived', label: 'Arsip' },
        ],
      };
    }
  },

  async create(payload: {
    title: string;
    body: string;
    /** Backend column is `announcements.type` (was `category`). */
    type?: AnnouncementCategory;
    /** Legacy alias — services map either onto `type` for the backend. */
    category?: AnnouncementCategory;
    priority?: AnnouncementPriority;
    /** Lifecycle status — draft/scheduled/published. */
    status?: AnnouncementStatus;
    audience: AnnouncementAudience;
    role_target?: string;
    target_ids?: string[];
    is_pinned?: boolean;
    scheduled_at?: string | null;
    event_at?: string | null;
    event_location?: string | null;
    expires_at?: string | null;
  }): Promise<Announcement> {
    // The backend stores `type` (category-only) and `status` (lifecycle)
    // as two separate columns post-rename. Map legacy `category` →
    // `type` so older callers keep working.
    const body: Record<string, unknown> = { ...payload };
    if (payload.category && body.type === undefined) body.type = payload.category;
    delete body.category;
    const res = await api.post('/announcement', body);
    const respBody = res.data?.data ?? res.data ?? {};
    return announcementFromJson(respBody as Record<string, unknown>);
  },

  async update(
    id: string,
    payload: Partial<Announcement>,
  ): Promise<Announcement> {
    // Same mapping as `create`: backend column is `type`, but legacy
    // callers still set `category`. Forward whichever is present.
    const body: Record<string, unknown> = { ...payload };
    if (payload.category && body.type === undefined) body.type = payload.category;
    delete body.category;
    const res = await api.put(`/announcement/${id}`, body);
    const respBody = res.data?.data ?? res.data ?? {};
    return announcementFromJson(respBody as Record<string, unknown>);
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/announcement/${id}`);
  },

  /**
   * Auto-tracked mark-as-read. Best-effort: failures are swallowed
   * so the detail view can still render the body even if the
   * tracking endpoint is unreachable. Mirrors Flutter's behaviour.
   */
  async markAsRead(id: string): Promise<void> {
    try {
      await api.post(`/announcement/${id}/mark-as-read`);
    } catch {
      // non-fatal
    }
  },

  /**
   * Admin-only preview of estimated reach for the AudienceMatrix.
   * Returns `{ reach, breakdown? }` — `breakdown` keys vary
   * (teacher/student/parent counts). Falls back to `{ reach: 0 }`
   * on error so the chip just renders "—".
   */
  async previewReach(payload: {
    audience: AnnouncementAudience;
    target_ids?: string[];
  }): Promise<{ reach: number; breakdown?: Record<string, number> }> {
    try {
      const res = await api.post('/announcement/preview-reach', payload);
      const body = res.data?.data ?? res.data ?? {};
      return {
        reach: Number(body.reach ?? body.total ?? 0),
        breakdown: body.breakdown ?? undefined,
      };
    } catch {
      return { reach: 0 };
    }
  },

  /**
   * Fetch upcoming and live events (Acara) scoped to the viewer.
   */
  async fetchUpcomingEvents(params: { limit?: number } = {}): Promise<any[]> {
    try {
      const res = await api.get('/announcements/upcoming-events', {
        params: { limit: params.limit ?? 3 },
      });
      const body = res.data?.data ?? res.data ?? [];
      return Array.isArray(body) ? body : [];
    } catch {
      return [];
    }
  },

  /**
   * Month-scoped event fetch for the admin Kalender Acara view.
   * Mirrors Flutter's `fetchEventsForCalendar` — hits the same
   * `/announcements` endpoint with `has_event=1` + an inclusive
   * date range and returns every announcement that has an
   * `event_at` between `from` and `to`.
   */
  async fetchEventsForCalendar(args: {
    from: Date;
    to: Date;
    limit?: number;
  }): Promise<Array<Record<string, unknown>>> {
    try {
      const res = await api.get('/announcements', {
        params: {
          has_event: 1,
          event_from: args.from.toISOString(),
          event_to: args.to.toISOString(),
          limit: args.limit ?? 100,
        },
      });
      const body = res.data;
      const rows = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return rows.filter(
        (r: unknown): r is Record<string, unknown> =>
          typeof r === 'object' && r !== null,
      );
    } catch {
      return [];
    }
  },
};

