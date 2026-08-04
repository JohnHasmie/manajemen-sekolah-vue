/**
 * Vitest spec for TutoringTutorsService.
 *
 * Locks:
 *  - list() only forwards `search` / `active` when the caller sets them
 *    (BE reads a missing `active` as "return both" — don't leak `false`).
 *  - list() flattens the Laravel Resource envelope { data, meta } into
 *    { items, pagination } and computes has_next_page correctly.
 *  - get() unwraps { data }.
 *  - invite() strips empty-string names so BE's `nullable` branch fires.
 *  - invite() forwards `phone` / `initial_rate` even though BE-17 ignores
 *    them today (forward compat).
 *  - deactivate() posts an empty body.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TutoringTutorsService } from './tutors';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

describe('TutoringTutorsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('list() flattens meta + fills has_next_page / has_prev_page', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          { id: 't1', user_id: 'u1', name: 'Ust. Ali', is_active: true, active_group_count: 2 },
        ],
        meta: { current_page: 2, last_page: 3, per_page: 20, total: 47 },
      },
    });

    const res = await TutoringTutorsService.list({ page: 2 });

    expect(res.items).toHaveLength(1);
    expect(res.pagination).toEqual({
      total_items: 47,
      total_pages: 3,
      current_page: 2,
      per_page: 20,
      has_next_page: true,
      has_prev_page: true,
    });
  });

  it('list() only forwards search / active when explicitly set', async () => {
    (api.get as any).mockResolvedValueOnce({ data: { data: [], meta: {} } });
    await TutoringTutorsService.list({});
    const params1 = (api.get as any).mock.calls[0][1].params;
    expect(params1).not.toHaveProperty('search');
    expect(params1).not.toHaveProperty('active');

    (api.get as any).mockResolvedValueOnce({ data: { data: [], meta: {} } });
    await TutoringTutorsService.list({ search: 'ali', active: false });
    const params2 = (api.get as any).mock.calls[1][1].params;
    expect(params2).toMatchObject({ search: 'ali', active: false });
  });

  it('get() unwraps the { data } envelope', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: { data: { id: 't9', user_id: 'u9', name: 'Ust. Zaki', is_active: true, active_group_count: 0 } },
    });
    const t = await TutoringTutorsService.get('t9');
    expect(t.name).toBe('Ust. Zaki');
    expect(t.active_group_count).toBe(0);
  });

  it('invite() strips empty name so BE nullable branch fires', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 't2', user_id: 'u2', name: 'Foo', is_active: true, active_group_count: 0 } },
    });
    await TutoringTutorsService.invite({ email: 'x@y.z', name: '   ' });
    const body = (api.post as any).mock.calls[0][1];
    expect(body).toEqual({ email: 'x@y.z' });
  });

  it('invite() forwards phone + initial_rate for forward compat', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 't3', user_id: 'u3', name: 'Bar', is_active: true, active_group_count: 0 } },
    });
    await TutoringTutorsService.invite({
      email: 'bar@school.id',
      name: 'Bar',
      phone: '+62811',
      initial_rate: 75000,
    });
    const body = (api.post as any).mock.calls[0][1];
    expect(body).toEqual({
      email: 'bar@school.id',
      name: 'Bar',
      phone: '+62811',
      initial_rate: 75000,
    });
  });

  it('deactivate() posts an empty body', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 't1', user_id: 'u1', name: 'X', is_active: false, active_group_count: 0 } },
    });
    const t = await TutoringTutorsService.deactivate('t1');
    expect(t.is_active).toBe(false);
    expect((api.post as any).mock.calls[0][0]).toBe('/tutoring-v2/tutors/t1/deactivate');
    expect((api.post as any).mock.calls[0][1]).toEqual({});
  });
});
