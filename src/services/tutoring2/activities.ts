/**
 * ActivitiesService — greenfield tutoring activities CRUD + publish
 * (WEB-13, mirrors BE-23 `ActivityController`).
 *
 *   GET    /learning-groups/{groupId}/activities   index (draft hidden from siswa)
 *   POST   /learning-groups/{groupId}/activities   create (returns 201)
 *   GET    /activities/{id}                        show
 *   PUT    /activities/{id}                        update
 *   POST   /activities/{id}/publish                idempotent — set published_at
 *   DELETE /activities/{id}                        soft-delete
 *
 * Split into its own service (not folded into TutoringBimbelService)
 * because the activity endpoint family sits under two different URL
 * anchors (`/learning-groups/{id}/activities` for the index/create,
 * `/activities/{id}` for show/update/publish/delete). Keeping the
 * boundary tight makes the URL topology obvious at the call site.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  Activity,
  ActivityCreatePayload,
  ActivityKind,
  ActivityUpdatePayload,
} from '@/types/tutoring2/activity';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

export interface ActivityListParams {
  page?: number;
  per_page?: number;
  kind?: ActivityKind;
}

export const ActivitiesService = {
  async listByGroup(groupId: string, params: ActivityListParams = {}) {
    const r = await api.get<ListEnvelope<Activity>>(
      `/tutoring-v2/learning-groups/${groupId}/activities`,
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  async get(id: string): Promise<Activity> {
    const r = await api.get<OneEnvelope<Activity>>(`/tutoring-v2/activities/${id}`);
    return r.data.data;
  },

  async create(groupId: string, payload: ActivityCreatePayload): Promise<Activity> {
    const r = await api.post<OneEnvelope<Activity>>(
      `/tutoring-v2/learning-groups/${groupId}/activities`,
      payload,
    );
    return r.data.data;
  },

  async update(id: string, payload: ActivityUpdatePayload): Promise<Activity> {
    const r = await api.put<OneEnvelope<Activity>>(`/tutoring-v2/activities/${id}`, payload);
    return r.data.data;
  },

  async publish(id: string): Promise<Activity> {
    const r = await api.post<OneEnvelope<Activity>>(`/tutoring-v2/activities/${id}/publish`, {});
    return r.data.data;
  },

  async delete(id: string): Promise<void> {
    await api.delete(`/tutoring-v2/activities/${id}`);
  },
};
