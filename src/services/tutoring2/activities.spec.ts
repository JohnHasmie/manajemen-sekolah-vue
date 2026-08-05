/**
 * Vitest contract spec for ActivitiesService (WEB-13).
 *
 * Pins:
 *   - the two URL anchors (`/learning-groups/{id}/activities` vs
 *     `/activities/{id}`) so a future refactor can't collapse them
 *     silently.
 *   - the load-bearing greenfield contract: create returns an Activity
 *     with `learning_group_id`, submissions keyed by `enrollment_id`
 *     downstream.
 *   - publish() is idempotent — the server keeps the original
 *     `published_at` on repeat calls; the spec just verifies the
 *     endpoint shape.
 */
// @ts-nocheck — vitest types optional in this workspace (matches
// the trash.service.spec + rbac.service.spec pattern in this repo).
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ActivitiesService } from './activities';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('ActivitiesService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('listByGroup() hits the group-scoped index and unwraps items', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'act-1',
            learning_group_id: 'grp-1',
            kind: 'tugas',
            title: 'Latihan Aljabar',
            submissions_count: 4,
          },
        ],
        meta: { current_page: 1, per_page: 20, total: 1, last_page: 1 },
      },
    });

    const res = await ActivitiesService.listByGroup('grp-1', { kind: 'tugas' });

    expect(api.get).toHaveBeenCalledWith(
      '/tutoring-v2/learning-groups/grp-1/activities',
      { params: { kind: 'tugas' } },
    );
    expect(res.items).toHaveLength(1);
    expect(res.items[0].kind).toBe('tugas');
    expect(res.pagination?.total).toBe(1);
  });

  it('create() POSTs to the group anchor with the create payload', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: {
        data: {
          id: 'act-new',
          learning_group_id: 'grp-1',
          kind: 'kuis',
          title: 'Kuis 1',
          published_at: null,
        },
      },
    });

    const created = await ActivitiesService.create('grp-1', {
      kind: 'kuis',
      title: 'Kuis 1',
      description: null,
      due_at: '2026-08-10',
      max_points: 100,
    });

    expect(api.post).toHaveBeenCalledWith(
      '/tutoring-v2/learning-groups/grp-1/activities',
      {
        kind: 'kuis',
        title: 'Kuis 1',
        description: null,
        due_at: '2026-08-10',
        max_points: 100,
      },
    );
    expect(created.id).toBe('act-new');
    expect(created.published_at).toBeNull();
  });

  it('publish() POSTs to the id-scoped publish action', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 'act-1', published_at: '2026-08-04T02:00:00Z' } },
    });
    const act = await ActivitiesService.publish('act-1');
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/activities/act-1/publish', {});
    expect(act.published_at).toBe('2026-08-04T02:00:00Z');
  });

  it('update() PUTs the id-scoped url', async () => {
    (api.put as any).mockResolvedValueOnce({
      data: { data: { id: 'act-1', title: 'Renamed' } },
    });
    const act = await ActivitiesService.update('act-1', { title: 'Renamed' });
    expect(api.put).toHaveBeenCalledWith('/tutoring-v2/activities/act-1', { title: 'Renamed' });
    expect(act.title).toBe('Renamed');
  });

  it('delete() DELETEs the id-scoped url', async () => {
    (api.delete as any).mockResolvedValueOnce({ status: 204 });
    await ActivitiesService.delete('act-1');
    expect(api.delete).toHaveBeenCalledWith('/tutoring-v2/activities/act-1');
  });
});
