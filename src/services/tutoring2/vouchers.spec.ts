/**
 * Contract spec for VouchersService (BE-16).
 *
 * Pins the two things the FE relies on:
 *   1. list() flattens the Laravel `{ data, meta }` envelope into
 *      `{ items, pagination }` and passes the right query params (aliasing
 *      the UI-side `search` into the backend's `code` field).
 *   2. redeem() POSTs to the nested `/redeem` route with `enrollment_id`
 *      + `bill_id` in the body (the shape backend RedeemVoucherRequest
 *      validates).
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { VouchersService } from './vouchers';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('VouchersService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('list() flattens { data, meta } envelope + aliases search → code', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'v1',
            school_id: 's1',
            code: 'HEMAT10',
            kind: 'percent',
            value: 10,
            status: 'active',
          },
        ],
        meta: { current_page: 1, last_page: 1, per_page: 20, total: 1 },
      },
    });

    const res = await VouchersService.list({ search: 'hemat', status: 'active' });

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/vouchers', {
      params: { code: 'hemat', status: 'active' },
    });
    expect(res.items).toHaveLength(1);
    expect(res.items[0].code).toBe('HEMAT10');
    expect(res.pagination?.total).toBe(1);
  });

  /**
   * `listMine()` is the WALI list and hits a DIFFERENT path to `list()`.
   *
   * The path is the assertion. `/tutoring-v2/vouchers` authorizes
   * `tutoring.voucher.view` and returns every code in the lembaga;
   * `/tutoring-v2/vouchers/my` authorizes `tutoring.voucher.view_own`
   * and starts from the recipient grant. Pointing this method at the
   * first one would be a leak that no shape assertion would catch — the
   * envelope is identical.
   */
  it('listMine() reads /vouchers/my, not the tenant-wide list', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'v9',
            school_id: 's1',
            code: 'PRIBADI25',
            kind: 'percent',
            value: 25,
            status: 'active',
          },
        ],
        meta: { current_page: 1, last_page: 1, per_page: 100, total: 1 },
      },
    });

    const res = await VouchersService.listMine({ per_page: 100 });

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/vouchers/my', {
      params: { per_page: 100 },
    });
    expect(api.get).not.toHaveBeenCalledWith(
      '/tutoring-v2/vouchers',
      expect.anything(),
    );
    expect(res.items[0].code).toBe('PRIBADI25');
    expect(res.pagination?.total).toBe(1);
  });

  /**
   * `myIndex` reads `per_page` and nothing else — it pins `status` to
   * `active` itself and has no `code` search. Forwarding a filter the
   * server ignores would be a control that lies, so the method sends
   * only what the endpoint reads.
   */
  it('listMine() sends no params when given none', async () => {
    (api.get as any).mockResolvedValueOnce({ data: { data: [] } });

    const res = await VouchersService.listMine();

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/vouchers/my', {
      params: {},
    });
    // An empty list is a real answer — "you have no vouchers" — not a
    // failure to load.
    expect(res.items).toEqual([]);
  });

  it('create() POSTs the payload as-is + returns the unwrapped voucher', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: {
        data: {
          id: 'v-new',
          school_id: 's1',
          code: 'BARU',
          kind: 'fixed',
          value: 25000,
          status: 'active',
        },
      },
    });

    const payload = { code: 'BARU', kind: 'fixed' as const, value: 25000 };
    const v = await VouchersService.create(payload);

    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/vouchers', payload);
    expect(v.id).toBe('v-new');
    expect(v.value).toBe(25000);
  });

  it('archive() POSTs to the nested /archive route', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 'v1', status: 'archived' } },
    });

    await VouchersService.archive('v1');

    expect(api.post).toHaveBeenCalledWith(
      '/tutoring-v2/vouchers/v1/archive',
      {},
    );
  });

  it('redeem() sends enrollment_id + bill_id under /redeem', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: {
        data: {
          id: 'r1',
          school_id: 's1',
          voucher_id: 'v1',
          enrollment_id: 'e1',
          bill_id: 'b1',
          applied_amount: 10000,
        },
      },
    });

    const r = await VouchersService.redeem('v1', {
      enrollment_id: 'e1',
      bill_id: 'b1',
    });

    expect(api.post).toHaveBeenCalledWith(
      '/tutoring-v2/vouchers/v1/redeem',
      { enrollment_id: 'e1', bill_id: 'b1' },
    );
    expect(r.applied_amount).toBe(10000);
  });
});
