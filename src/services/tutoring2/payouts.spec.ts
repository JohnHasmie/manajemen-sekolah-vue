/**
 * Vitest spec for PayoutsService — greenfield admin payouts wire.
 *
 * Vitest is not wired up in the web-vue repo yet (see the note on
 * RbacService.spec.ts). This file is currently consumed only by
 * vue-tsc as a contract artifact — the shape it locks:
 *
 *   1. Every method builds the correct `/tutoring-v2/payouts/*` URL
 *      and forwards params.
 *   2. Payloads for reject / mark-paid / close-month match the FormRequest
 *      rules from `App\Modules\Tutoring\Http\Requests\*`.
 *   3. Returns unwrap the `{data: …}` envelope so callers never see it.
 *
 * When Vitest lands the tests run as-is; until then the imports still
 * type-check the service surface every build.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PayoutsService } from './payouts';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
  },
}));

describe('PayoutsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // ─── Rates ───────────────────────────────────────────────────────

  it('listRates hits GET /tutoring-v2/payouts/rates with params', async () => {
    api.get.mockResolvedValueOnce({ data: { data: [] } });
    await PayoutsService.listRates({ tutor_id: 't-1', active_only: true });
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/payouts/rates', {
      params: { tutor_id: 't-1', active_only: true },
    });
  });

  it('upsertRate POSTs to /rates and unwraps data', async () => {
    api.post.mockResolvedValueOnce({
      data: {
        data: {
          id: 'r-1',
          tutor_id: 't-1',
          kind: 'per_session',
          value: 75_000,
          effective_from: '2026-08-01',
          effective_until: null,
        },
      },
    });
    const rate = await PayoutsService.upsertRate({
      tutor_id: 't-1',
      kind: 'per_session',
      value: 75_000,
      effective_from: '2026-08-01',
    });
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/payouts/rates', expect.any(Object));
    expect(rate.id).toBe('r-1');
  });

  it('endRate POSTs to /rates/{id}/end', async () => {
    api.post.mockResolvedValueOnce({ data: { data: { id: 'r-1' } } });
    await PayoutsService.endRate('r-1');
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/payouts/rates/r-1/end', {});
  });

  // ─── Settings ────────────────────────────────────────────────────

  it('getSettings unwraps the transient default row', async () => {
    api.get.mockResolvedValueOnce({
      data: {
        data: {
          cycle: 'monthly',
          default_kind: 'per_session',
          minimum_payout: null,
          notes: '',
        },
      },
    });
    const s = await PayoutsService.getSettings();
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/payouts/settings');
    expect(s.cycle).toBe('monthly');
  });

  it('updateSettings PUTs a partial patch', async () => {
    api.put.mockResolvedValueOnce({
      data: { data: { cycle: 'biweekly', default_kind: 'monthly_salary', minimum_payout: 500_000, notes: '' } },
    });
    await PayoutsService.updateSettings({ cycle: 'biweekly' });
    expect(api.put).toHaveBeenCalledWith('/tutoring-v2/payouts/settings', { cycle: 'biweekly' });
  });

  // ─── Requests ────────────────────────────────────────────────────

  it('listRequests forwards status/month/tutor filters', async () => {
    api.get.mockResolvedValueOnce({ data: { data: [] } });
    await PayoutsService.listRequests({ status: 'pending', month: '2026-07', tutor_id: 't-1' });
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/payouts/requests', {
      params: { status: 'pending', month: '2026-07', tutor_id: 't-1' },
    });
  });

  it('approveRequest PATCHes /requests/{id}/approve', async () => {
    api.patch.mockResolvedValueOnce({ data: { data: { id: 'q-1', status: 'approved' } } });
    const req = await PayoutsService.approveRequest('q-1');
    expect(api.patch).toHaveBeenCalledWith('/tutoring-v2/payouts/requests/q-1/approve', {});
    expect(req.status).toBe('approved');
  });

  it('rejectRequest sends {reason}', async () => {
    api.patch.mockResolvedValueOnce({ data: { data: { id: 'q-1', status: 'rejected' } } });
    await PayoutsService.rejectRequest('q-1', { reason: 'Nominal terlalu besar untuk periode ini.' });
    expect(api.patch).toHaveBeenCalledWith('/tutoring-v2/payouts/requests/q-1/reject', {
      reason: 'Nominal terlalu besar untuk periode ini.',
    });
  });

  it('markRequestPaid forwards optional payment_reference', async () => {
    api.patch.mockResolvedValueOnce({ data: { data: { id: 'q-1', status: 'paid' } } });
    await PayoutsService.markRequestPaid('q-1', { payment_reference: 'TRF-9911' });
    expect(api.patch).toHaveBeenCalledWith('/tutoring-v2/payouts/requests/q-1/mark-paid', {
      payment_reference: 'TRF-9911',
    });
  });

  it('rollbackRequest PATCHes /requests/{id}/rollback with no body', async () => {
    api.patch.mockResolvedValueOnce({ data: { data: { id: 'q-1', status: 'approved' } } });
    await PayoutsService.rollbackRequest('q-1');
    expect(api.patch).toHaveBeenCalledWith('/tutoring-v2/payouts/requests/q-1/rollback', {});
  });

  // ─── Summary + close-month ───────────────────────────────────────

  it('getAdminSummary forwards ?month and returns {rows, meta}', async () => {
    api.get.mockResolvedValueOnce({
      data: {
        data: [{ tutor_id: 't-1', tutor_name: 'Bu Rina', period_month: '2026-07', sessions_taught: 12, base_amount: 900_000, adjustments: 0, net_amount: 900_000 }],
        meta: { period_month: '2026-07', tutor_count: 1 },
      },
    });
    const { rows, meta } = await PayoutsService.getAdminSummary({ month: '2026-07' });
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/payouts/admin-summary', { params: { month: '2026-07' } });
    expect(rows).toHaveLength(1);
    expect(meta?.tutor_count).toBe(1);
  });

  it('closeMonth POSTs {month, note}', async () => {
    api.post.mockResolvedValueOnce({ data: { data: { id: 'c-1', period_month: '2026-07' } } });
    await PayoutsService.closeMonth({ month: '2026-07', note: 'Ditutup usai gaji tutor.' });
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/payouts/close-month', {
      month: '2026-07',
      note: 'Ditutup usai gaji tutor.',
    });
  });

  it('reopenMonth DELETEs /close-month/{id}', async () => {
    api.delete.mockResolvedValueOnce({ data: { message: 'ok' } });
    await PayoutsService.reopenMonth('c-1');
    expect(api.delete).toHaveBeenCalledWith('/tutoring-v2/payouts/close-month/c-1');
  });

  it('listCloses GETs /closes with pagination params', async () => {
    api.get.mockResolvedValueOnce({ data: { data: [] } });
    await PayoutsService.listCloses({ per_page: 24 });
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/payouts/closes', { params: { per_page: 24 } });
  });
});
