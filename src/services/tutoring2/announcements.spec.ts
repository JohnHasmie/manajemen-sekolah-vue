/**
 * Vitest contract spec for TutoringAnnouncementsService (WEB-12 / BE-22).
 *
 * Vitest is not yet wired repo-wide (see rbac.service.spec.ts for the
 * standing note); this file pins the endpoint DTOs so a future
 * `vitest run` — plus the current `vue-tsc --build` gate — catch
 * signature drift against BE-22.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TutoringAnnouncementsService } from './announcements';
import { api } from '@/lib/http';
import type { GroupAnnouncement } from '@/types/tutoring2/announcement';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

const GROUP_ID = 'grp-uuid-1';
const ANN_ID = 'ann-uuid-1';

const SAMPLE: GroupAnnouncement = {
  id: ANN_ID,
  school_id: 'school-1',
  learning_group_id: GROUP_ID,
  author_user_id: 'user-1',
  author_name: 'Bu Rina',
  title: 'Perubahan jadwal',
  body: '<p>Sesi Rabu dipindah ke Kamis.</p>',
  published_at: null,
  is_published: false,
  created_at: '2026-08-04T02:00:00Z',
  updated_at: '2026-08-04T02:00:00Z',
};

describe('TutoringAnnouncementsService', () => {
  beforeEach(() => vi.clearAllMocks());

  it('list hits the nested group endpoint and unwraps the envelope', async () => {
    (api.get as any).mockResolvedValue({
      data: { data: [SAMPLE], meta: { total: 1, per_page: 20, current_page: 1, last_page: 1 } },
    });
    const { items, pagination } = await TutoringAnnouncementsService.list(GROUP_ID, { published: true });
    expect(api.get).toHaveBeenCalledWith(
      `/tutoring-v2/learning-groups/${GROUP_ID}/announcements`,
      { params: { published: true } },
    );
    expect(items).toHaveLength(1);
    expect(items[0].id).toBe(ANN_ID);
    expect(pagination?.total).toBe(1);
  });

  it('create posts to the nested group endpoint with the correct payload shape', async () => {
    (api.post as any).mockResolvedValue({ data: { data: SAMPLE } });
    const created = await TutoringAnnouncementsService.create(GROUP_ID, {
      title: 'Perubahan jadwal',
      body: '<p>x</p>',
      publish: false,
    });
    expect(api.post).toHaveBeenCalledWith(
      `/tutoring-v2/learning-groups/${GROUP_ID}/announcements`,
      { title: 'Perubahan jadwal', body: '<p>x</p>', publish: false },
    );
    expect(created.id).toBe(ANN_ID);
  });

  it('publish posts to the /publish sub-route (no body)', async () => {
    const published = { ...SAMPLE, published_at: '2026-08-04T03:00:00Z', is_published: true };
    (api.post as any).mockResolvedValue({ data: { data: published } });
    const out = await TutoringAnnouncementsService.publish(GROUP_ID, ANN_ID);
    expect(api.post).toHaveBeenCalledWith(
      `/tutoring-v2/learning-groups/${GROUP_ID}/announcements/${ANN_ID}/publish`,
      {},
    );
    expect(out.is_published).toBe(true);
    expect(out.published_at).not.toBeNull();
  });

  it('destroy hits DELETE and resolves void', async () => {
    (api.delete as any).mockResolvedValue({ data: { success: true } });
    await expect(
      TutoringAnnouncementsService.destroy(GROUP_ID, ANN_ID),
    ).resolves.toBeUndefined();
    expect(api.delete).toHaveBeenCalledWith(
      `/tutoring-v2/learning-groups/${GROUP_ID}/announcements/${ANN_ID}`,
    );
  });
});
