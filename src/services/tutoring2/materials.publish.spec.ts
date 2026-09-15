/**
 * "Kirim ke wali" — the endpoint contract.
 *
 * Until MR !867 there was no writer for `published_at` on ANY endpoint,
 * and `CreateMaterialAction` never sets it, so every material ever
 * created sat as a draft forever. `MaterialController@index` filters
 * `->when(! $canManage, fn ($b) => $b->whereNotNull('published_at'))`,
 * so "forever a draft" meant literally no wali and no siswa could see a
 * single teaching material in production.
 *
 * The two routes that open that gate are:
 *
 *   POST /api/tutoring-v2/materials/{id}/publish
 *   POST /api/tutoring-v2/materials/{id}/unpublish
 *
 * both authorizing `tutoring.material.manage`. This spec pins the URLs
 * and the response unwrapping, because a typo in either path fails as a
 * 404 at runtime and nowhere else — the send button would simply never
 * work, which is indistinguishable from the bug it was written to fix.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { MaterialsService } from './materials';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn() },
}));

const SENT = {
  id: 'mat-7',
  learning_group_id: 'grp-3',
  learning_group_name: 'UTBK Pagi A',
  program_id: 'pr-1',
  program_name: 'Intensif UTBK',
  title: 'Ringkasan Vektor',
  description: null,
  file_url: 'https://bucket.example/signed/vektor.pdf?sig=abc',
  file_name: 'vektor.pdf',
  file_size: 1024,
  file_mime: 'application/pdf',
  kind: 'PDF',
  uploaded_by_user_id: 'u-9',
  uploaded_by_name: 'Bu Sinta',
  published_at: '2026-09-15T02:00:00Z',
  is_published: true,
  created_at: '2026-09-01T02:00:00Z',
  updated_at: '2026-09-15T02:00:00Z',
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe('MaterialsService — kirim / tarik ke wali', () => {
  it('publish() POSTs to /materials/{id}/publish with the material id in the path', async () => {
    api.post.mockResolvedValueOnce({ data: { data: SENT } });

    const result = await MaterialsService.publish('mat-7');

    expect(api.post).toHaveBeenCalledTimes(1);
    const [url] = api.post.mock.calls[0];
    expect(url).toBe('/tutoring-v2/materials/mat-7/publish');
    // Unwrapped from the `data` envelope, not handed back raw.
    expect(result.id).toBe('mat-7');
    expect(result.is_published).toBe(true);
  });

  it('unpublish() POSTs to /materials/{id}/unpublish', async () => {
    api.post.mockResolvedValueOnce({
      data: { data: { ...SENT, published_at: null, is_published: false } },
    });

    const result = await MaterialsService.unpublish('mat-7');

    expect(api.post).toHaveBeenCalledTimes(1);
    const [url] = api.post.mock.calls[0];
    expect(url).toBe('/tutoring-v2/materials/mat-7/unpublish');
    expect(result.is_published).toBe(false);
  });

  /**
   * The id is interpolated, never assumed. A service that ignored its
   * argument would pass the two assertions above by luck if the fixture
   * id ever matched the hardcoded one.
   */
  it('carries whichever id it is given, not a fixed one', async () => {
    api.post.mockResolvedValue({ data: { data: SENT } });

    await MaterialsService.publish('019f8090-4d6a-71ab-bf01-c98a6ac73293');
    expect(api.post.mock.calls[0][0]).toBe(
      '/tutoring-v2/materials/019f8090-4d6a-71ab-bf01-c98a6ac73293/publish',
    );

    await MaterialsService.unpublish('mat-other');
    expect(api.post.mock.calls[1][0]).toBe(
      '/tutoring-v2/materials/mat-other/unpublish',
    );
  });
});
