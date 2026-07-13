/**
 * Vitest spec for StaffService (Data Staf).
 *
 * Locks the two subtle bits: list() flattening the { data, meta } envelope
 * into { items, pagination }, and create() returning the raw
 * { data, user_created, initial_password } body (the password reveal
 * depends on it).
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { StaffService } from './staff.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('StaffService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('list() flattens meta into a Pagination shape', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [{ id: 's1', name: 'Wahyu', position: 'Musyrifah', roles: [] }],
        meta: { current_page: 1, last_page: 3, per_page: 20, total: 42 },
      },
    });

    const res = await StaffService.list({ page: 1 });

    expect(res.items).toHaveLength(1);
    expect(res.pagination).toEqual({
      total_items: 42,
      total_pages: 3,
      current_page: 1,
      per_page: 20,
      has_next_page: true,
    });
  });

  it('list() forwards a search term only when present', async () => {
    (api.get as any).mockResolvedValueOnce({ data: { data: [], meta: {} } });
    await StaffService.list({ search: 'bendahara' });
    expect((api.get as any).mock.calls[0][1].params).toMatchObject({
      search: 'bendahara',
    });

    (api.get as any).mockResolvedValueOnce({ data: { data: [], meta: {} } });
    await StaffService.list({});
    expect((api.get as any).mock.calls[1][1].params).not.toHaveProperty('search');
  });

  it('create() returns the raw result incl. initial_password', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: {
        data: { id: 's9', name: 'Sri', position: 'TU', roles: [] },
        user_created: true,
        initial_password: 'K@mil-abc123',
      },
    });

    const res = await StaffService.create({
      name: 'Sri',
      email: 'sri@x.test',
      position: 'TU',
    });

    expect(res.user_created).toBe(true);
    expect(res.initial_password).toBe('K@mil-abc123');
    expect(res.data.id).toBe('s9');
  });

  it('update() unwraps the { data } envelope', async () => {
    (api.put as any).mockResolvedValueOnce({
      data: { data: { id: 's1', name: 'Wahyu B', position: 'Musyrifah', roles: [] } },
    });
    const res = await StaffService.update('s1', { name: 'Wahyu B' });
    expect(res.name).toBe('Wahyu B');
  });
});
