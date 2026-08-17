import { beforeEach, describe, expect, it, vi } from 'vitest';

import { TeacherService } from './teachers.service';
import { api } from '@/lib/http';

/**
 * `TeacherService.stats()` feeds the admin Manajemen Guru KPI tiles.
 *
 * Two things have to hold, and neither is obvious from the happy path:
 *
 *  - Missing keys must become 0, not `undefined`. The endpoint predates
 *    `homeroom`/`has_subject`, so during the rollout window a browser can
 *    hit an older backend. `undefined` renders as a blank tile — which is
 *    the exact failure this whole change replaces ("halaman di ganti
 *    hitung total data", 2026-08-14).
 *  - The filters must go out with the request. A KPI above a filtered
 *    table that counts the unfiltered set is a number that lies while
 *    looking authoritative.
 */

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

const mockedGet = vi.mocked(api.get);

describe('TeacherService.stats', () => {
  beforeEach(() => {
    mockedGet.mockReset();
  });

  it('reads the aggregate payload', async () => {
    mockedGet.mockResolvedValue({
      data: { data: { total: 25, female: 9, homeroom: 3, has_subject: 4 } },
    } as never);

    await expect(TeacherService.stats()).resolves.toEqual({
      total: 25,
      female: 9,
      homeroom: 3,
      has_subject: 4,
    });
  });

  it('defaults absent keys to 0 so no tile renders blank', async () => {
    // An older backend returns only the gender aggregates.
    mockedGet.mockResolvedValue({
      data: { data: { total: 15, female: 6 } },
    } as never);

    const stats = await TeacherService.stats();

    expect(stats.homeroom).toBe(0);
    expect(stats.has_subject).toBe(0);
    expect(stats.total).toBe(15);
  });

  it('tolerates an unwrapped payload', async () => {
    mockedGet.mockResolvedValue({ data: { total: 4 } } as never);

    await expect(TeacherService.stats()).resolves.toMatchObject({ total: 4 });
  });

  it('forwards the active filters so the tiles match the table', async () => {
    mockedGet.mockResolvedValue({ data: { data: {} } } as never);

    await TeacherService.stats({
      search: 'budi',
      class_id: 'class-1',
      gender: 'female',
      academic_year_id: 'ay-1',
    });

    expect(mockedGet).toHaveBeenCalledWith('/teacher/stats', {
      params: {
        search: 'budi',
        homeroom_class_id: 'class-1',
        gender: 'female',
        academic_year_id: 'ay-1',
      },
    });
  });

  it('omits empty filters rather than sending blanks', async () => {
    mockedGet.mockResolvedValue({ data: { data: {} } } as never);

    await TeacherService.stats({ search: '' });

    expect(mockedGet).toHaveBeenCalledWith('/teacher/stats', { params: {} });
  });
});
