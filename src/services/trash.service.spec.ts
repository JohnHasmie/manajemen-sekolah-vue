/**
 * Vitest spec for TrashService (Data Terhapus).
 *
 * Locks list()'s defaulting of the { data, total, retention_days } envelope,
 * and that restore/purge/impact hit the right type-scoped URLs.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TrashService } from './trash.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('TrashService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('list() returns groups, total and retention_days', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          { type: 'student', label: 'Siswa', quota: true, count: 2, items: [] },
        ],
        total: 2,
        retention_days: 30,
      },
    });

    const res = await TrashService.list();

    expect(api.get).toHaveBeenCalledWith('/trash');
    expect(res.data).toHaveLength(1);
    expect(res.total).toBe(2);
    expect(res.retention_days).toBe(30);
  });

  it('list() falls back to safe defaults on an empty body', async () => {
    (api.get as any).mockResolvedValueOnce({ data: {} });
    const res = await TrashService.list();
    expect(res.data).toEqual([]);
    expect(res.total).toBe(0);
    expect(res.retention_days).toBe(30);
  });

  it('impact() hits the type-scoped impact URL', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: { type: 'teacher', label: 'Guru', name: 'Budi', related: [] },
    });
    const res = await TrashService.impact('teacher', 'abc');
    expect(api.get).toHaveBeenCalledWith('/trash/teacher/abc/impact');
    expect(res.name).toBe('Budi');
  });

  it('restore() POSTs to the restore URL', async () => {
    (api.post as any).mockResolvedValueOnce({ data: { restored: true } });
    await TrashService.restore('student', 'xyz');
    expect(api.post).toHaveBeenCalledWith('/trash/student/xyz/restore');
  });

  it('purge() DELETEs the type-scoped URL', async () => {
    (api.delete as any).mockResolvedValueOnce({ status: 204 });
    await TrashService.purge('subject', 's5');
    expect(api.delete).toHaveBeenCalledWith('/trash/subject/s5');
  });
});
