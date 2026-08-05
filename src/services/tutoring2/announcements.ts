/**
 * Group announcements service (BE-22) — wraps the greenfield
 * `/api/tutoring-v2/learning-groups/{groupId}/announcements*` endpoints.
 *
 * Kept in its own file (rather than tacked onto TutoringBimbelService)
 * because the WEB-12 stack is small and self-contained: 4 endpoints,
 * 3 role views, one type. When BE-22.1 (archive) + BE-14 (notification
 * wire) ripple back through, the delta lands here without churning the
 * catch-all bimbel service.
 *
 * Tenant scoping is enforced backend-side via BelongsToSchool + the
 * controller's `learning_group_id` route-segment stamp, so callers
 * never juggle school_id here.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type { GroupAnnouncement } from '@/types/tutoring2/announcement';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

export interface ListAnnouncementsParams {
  page?: number;
  per_page?: number;
  /** When `true`, the BE hides drafts — the mode wali/siswa always see. */
  published?: boolean;
}

export interface CreateAnnouncementPayload {
  title: string;
  /**
   * Rich-text HTML body. Backend caps at 4000 chars (StoreGroupAnnouncementRequest).
   * Note the wire field is `body`, not `body_html`.
   */
  body: string;
  /** If true, the BE publishes on create (skips the draft step). */
  publish?: boolean;
}

export const TutoringAnnouncementsService = {
  /**
   * List announcements for a learning group. Reader must hold
   * `tutoring.announcement.view`. Admins + tutors see drafts; wali +
   * siswa are constrained by the caller passing `published: true`.
   */
  async list(groupId: string, params: ListAnnouncementsParams = {}) {
    const r = await api.get<ListEnvelope<GroupAnnouncement>>(
      `/tutoring-v2/learning-groups/${groupId}/announcements`,
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  /**
   * Create a draft (or publish immediately when `publish: true`).
   * Author must hold `tutoring.announcement.create`. The BE stamps
   * `learning_group_id` from the route segment — callers do not.
   */
  async create(groupId: string, payload: CreateAnnouncementPayload) {
    const r = await api.post<OneEnvelope<GroupAnnouncement>>(
      `/tutoring-v2/learning-groups/${groupId}/announcements`,
      payload,
    );
    return r.data.data;
  },

  /**
   * Flip a draft to published and fire the BE-14 notification event.
   * Idempotent — republishing an already-published row is a no-op and
   * does NOT re-fire the notification. Author must hold
   * `tutoring.announcement.create`.
   */
  async publish(groupId: string, id: string) {
    const r = await api.post<OneEnvelope<GroupAnnouncement>>(
      `/tutoring-v2/learning-groups/${groupId}/announcements/${id}/publish`,
      {},
    );
    return r.data.data;
  },

  /**
   * Delete the announcement outright. Wali/siswa lose the row from
   * their feed immediately (no soft-delete). Author must hold
   * `tutoring.announcement.create`.
   */
  async destroy(groupId: string, id: string): Promise<void> {
    await api.delete(`/tutoring-v2/learning-groups/${groupId}/announcements/${id}`);
  },
};
