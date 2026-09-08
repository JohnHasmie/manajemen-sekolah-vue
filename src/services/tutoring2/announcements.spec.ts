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

/**
 * A tenant-wide broadcast. `learning_group_id` is NULL — the shape the
 * nested endpoints can never return and the flat one routinely does.
 */
const TUTOR_BROADCAST: GroupAnnouncement = {
  id: 'ann-uuid-2',
  school_id: 'school-1',
  learning_group_id: null,
  audience: 'tutor',
  audience_label: 'Semua tutor',
  author_user_id: 'user-1',
  author_name: 'Admin Satu',
  title: 'Rapat koordinasi tutor',
  body: '<p>Senin 08.00.</p>',
  published_at: '2026-09-08T02:00:00Z',
  is_published: true,
  created_at: '2026-09-08T01:00:00Z',
  updated_at: '2026-09-08T02:00:00Z',
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

/**
 * The FLAT surface (BE !856) — `/tutoring-v2/announcements`.
 *
 * Two jobs: it is the only list that can carry a group-less
 * tutor-addressed row, and it is the one call that replaces the
 * "load every group, then one nested GET per group" fan-out.
 */
describe('TutoringAnnouncementsService — flat tenant-wide surface', () => {
  beforeEach(() => vi.clearAllMocks());

  it('listAll hits the FLAT endpoint and returns both audiences', async () => {
    (api.get as any).mockResolvedValue({
      data: {
        data: [SAMPLE, TUTOR_BROADCAST],
        meta: { total: 2, per_page: 20, current_page: 1, last_page: 1 },
      },
    });

    const { items, pagination } = await TutoringAnnouncementsService.listAll({
      per_page: 100,
    });

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/announcements', {
      params: { per_page: 100 },
    });
    expect(items).toHaveLength(2);
    // The null group is the whole point of this endpoint existing.
    expect(items[1].learning_group_id).toBeNull();
    expect(items[1].audience).toBe('tutor');
    expect(items[1].audience_label).toBe('Semua tutor');
    expect(pagination?.total).toBe(2);
  });

  it('listAll forwards the filter hints as query params', async () => {
    (api.get as any).mockResolvedValue({ data: { data: [], meta: undefined } });

    await TutoringAnnouncementsService.listAll({
      audience: 'tutor',
      published: true,
      page: 2,
    });

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/announcements', {
      params: { audience: 'tutor', published: true, page: 2 },
    });
  });

  it('createForTutors POSTs audience:"tutor" to the flat endpoint', async () => {
    (api.post as any).mockResolvedValue({ data: { data: TUTOR_BROADCAST } });

    const created = await TutoringAnnouncementsService.createForTutors({
      title: 'Rapat koordinasi tutor',
      body: '<p>Senin 08.00.</p>',
      publish: true,
    });

    // `audience` is REQUIRED server-side and `tutor` is the only value
    // accepted — `learning_group` is refused with a 422, because a group
    // announcement is created through the nested route instead.
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/announcements', {
      title: 'Rapat koordinasi tutor',
      body: '<p>Senin 08.00.</p>',
      publish: true,
      audience: 'tutor',
    });
    expect(created.id).toBe('ann-uuid-2');
  });

  it('publishById uses an id-only URL with no group segment', async () => {
    (api.post as any).mockResolvedValue({ data: { data: TUTOR_BROADCAST } });

    const out = await TutoringAnnouncementsService.publishById('ann-uuid-2');

    // A tutor row has no learning_group_id, so the nested twin would
    // build `/learning-groups/null/announcements/ann-uuid-2/publish`.
    expect(api.post).toHaveBeenCalledWith(
      '/tutoring-v2/announcements/ann-uuid-2/publish',
      {},
    );
    expect(out.is_published).toBe(true);
  });

  it('destroyById uses an id-only URL and resolves void', async () => {
    (api.delete as any).mockResolvedValue({ data: { success: true } });

    await expect(
      TutoringAnnouncementsService.destroyById('ann-uuid-2'),
    ).resolves.toBeUndefined();

    expect(api.delete).toHaveBeenCalledWith('/tutoring-v2/announcements/ann-uuid-2');
  });
});
