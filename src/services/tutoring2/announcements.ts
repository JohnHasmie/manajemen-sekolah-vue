/**
 * Bimbel announcements service — wraps BOTH greenfield surfaces:
 *
 *   · nested `/api/tutoring-v2/learning-groups/{groupId}/announcements*`
 *     (BE-22), the per-group family;
 *   · flat `/api/tutoring-v2/announcements*` (BE !856), the tenant-wide
 *     superset that also carries the group-less `audience: 'tutor'` rows.
 *
 * The flat list is what collapses the N+1 the admin/tutor screens used to
 * do (load every group, then one nested GET per group). It is also the
 * ONLY list that can return a tutor-addressed broadcast: the nested route
 * filters `where('learning_group_id', {groupId})`, which excludes a NULL
 * group whatever id you put in the URL.
 *
 * Creating a GROUP announcement deliberately stays on the nested route.
 * The flat POST refuses `audience: 'learning_group'` with a 422 — one act,
 * one door — so {@link TutoringAnnouncementsService.createForTutors} is
 * the tutor-audience composer and nothing else.
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
import type {
  AnnouncementAudience,
  GroupAnnouncement,
} from '@/types/tutoring2/announcement';

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

/**
 * Query for the flat tenant-wide list. Every field is a HINT applied on
 * top of the caller's server-side read scope, never instead of it — a
 * tutor passing another tutor's `learning_group_id` still gets nothing.
 */
export interface ListAllAnnouncementsParams {
  page?: number;
  /** Backend caps this at 100 and defaults to 20. */
  per_page?: number;
  audience?: AnnouncementAudience;
  /**
   * Narrow to one group. Note this necessarily EXCLUDES tutor-addressed
   * rows, which have no group — that is correct for a "show me this
   * group" filter, but it means a caller must not set this when it wants
   * the full mixed list.
   */
  learning_group_id?: string;
  /**
   * Draft/published split. Honoured only for callers who hold
   * `tutoring.announcement.create`; everyone else is pinned to published
   * rows server-side regardless of what is sent.
   */
  published?: boolean;
}

export interface CreateTutorAnnouncementPayload {
  title: string;
  /** Rich-text HTML body. Backend caps at 4000 chars. */
  body: string;
  /** If true, the BE publishes on create AND fires the notification. */
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

  // ── Flat / tenant-wide surface (BE !856) ────────────────────────

  /**
   * Every announcement the caller may see on the tenant, in ONE call —
   * both audiences, group-addressed and tutor-addressed alike.
   *
   * Replaces the "load all groups, then fan out one list() per group"
   * loader the admin and tutor screens used to run. That fan-out was not
   * merely slow: it could not represent a tutor-addressed row at all, so
   * those rows were invisible to it by construction.
   *
   * Reader must hold `tutoring.announcement.view`. Row-level scope is
   * applied server-side, so wali/siswa never receive tutor broadcasts.
   */
  async listAll(params: ListAllAnnouncementsParams = {}) {
    const r = await api.get<ListEnvelope<GroupAnnouncement>>(
      '/tutoring-v2/announcements',
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  /**
   * Compose a broadcast addressed to EVERY tutor on the tenant.
   *
   * `audience` is sent explicitly even though `tutor` is currently the
   * only value the endpoint accepts: the backend validates it as a
   * required field rather than inferring it from the route, so that a
   * future group-less audience becomes a new value here instead of a new
   * method.
   *
   * Author must hold `tutoring.announcement.create` AND the admin-only
   * `tutoring.tutor.view` — the create key alone is held by tutors too,
   * and without the second gate any tutor could broadcast tenant-wide.
   * Callers must gate the affordance on both; see
   * `canComposeTutorAudience` in the admin view.
   */
  async createForTutors(payload: CreateTutorAnnouncementPayload) {
    const r = await api.post<OneEnvelope<GroupAnnouncement>>(
      '/tutoring-v2/announcements',
      { ...payload, audience: 'tutor' satisfies AnnouncementAudience },
    );
    return r.data.data;
  },

  /**
   * Publish a draft by id, whatever its audience.
   *
   * Preferred over {@link TutoringAnnouncementsService.publish} at every
   * call site that renders the FLAT list, because a tutor-addressed row
   * has no `learning_group_id` to put in the nested URL — passing its
   * null would request `/learning-groups/null/announcements/...`.
   *
   * Scope is enforced server-side and fails CLOSED as a 404, not a 403,
   * so an out-of-scope id is indistinguishable from a nonexistent one.
   */
  async publishById(id: string) {
    const r = await api.post<OneEnvelope<GroupAnnouncement>>(
      `/tutoring-v2/announcements/${id}/publish`,
      {},
    );
    return r.data.data;
  },

  /**
   * Delete by id, whatever the audience. Soft delete server-side.
   * Same null-group reasoning as {@link publishById}, and the same
   * 404-not-403 scope behaviour.
   */
  async destroyById(id: string): Promise<void> {
    await api.delete(`/tutoring-v2/announcements/${id}`);
  },
};
