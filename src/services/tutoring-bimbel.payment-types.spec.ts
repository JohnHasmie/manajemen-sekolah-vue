/**
 * `TutoringBimbelService.listPaymentTypes` — the picker feed behind the
 * Tambah Tagihan sheet's Jenis pembayaran field.
 *
 * WHY THE COERCION IS TESTED HERE AND NOT IN THE SHEET SPEC. The sheet
 * spec mocks this service, so it can only ever see fixtures a test
 * author typed — and a test author types `350_000`, not the string the
 * server actually sends. `payment_types.amount` is `decimal(15,2)` and
 * `PaymentTypeOptionResource` passes it through with no `(float)` cast,
 * so postgres hands it over as `"350000.00"`. `<MoneyInput>` takes
 * `number | null` and nothing else, so an uncoerced string reaches the
 * Nominal prefill as a non-number and the prefill silently does
 * nothing — a failure with no error anywhere.
 *
 * The endpoint's other contract point is negative: it does NOT filter
 * to active rows. Issuing a one-off bill against a paused payment type
 * is legitimate, and a list that silently drops rows is the harder
 * failure to diagnose, so the service must pass every row through.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { TutoringBimbelService } from './tutoring-bimbel.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn() },
}));

/** Exactly what postgres + PaymentTypeOptionResource put on the wire. */
const WIRE_ROWS = [
  {
    id: 'pt-1',
    name: 'Tutoring System',
    description: null,
    amount: '350000.00',
    period: 'monthly',
    status: 'active',
    is_default: true,
  },
  {
    id: 'pt-3',
    name: 'Paket Lama',
    description: null,
    amount: '90000.00',
    period: 'once',
    status: 'inactive',
    is_default: false,
  },
];

beforeEach(() => {
  vi.clearAllMocks();
  api.get.mockResolvedValue({ data: { data: WIRE_ROWS } });
});

describe('listPaymentTypes', () => {
  it('reads the bimbel-owned route, not the school-side catalogue', async () => {
    await TutoringBimbelService.listPaymentTypes();

    // `GET /payment-types` sits inside `module:finance` and authorizes
    // `finance.bill_type.manage`, both of which are unreachable from a
    // bimbel tenant — hence a separate route under `module:tutoring`.
    expect(api.get).toHaveBeenCalledWith(
      '/tutoring-v2/payment-types',
      expect.anything(),
    );
  });

  it('coerces the decimal STRING postgres sends into a real number', async () => {
    const rows = await TutoringBimbelService.listPaymentTypes();

    expect(rows[0].amount).toBe(350_000);
    expect(typeof rows[0].amount).toBe('number');
    // Not merely truthy: MoneyInput rejects anything that is not a
    // number, so `'350000.00'` passing through would be a silent no-op.
    expect(rows[0].amount).not.toBe('350000.00');
  });

  it('falls back to 0 rather than NaN when the server sends nothing usable', async () => {
    api.get.mockResolvedValue({
      data: { data: [{ ...WIRE_ROWS[0], amount: null }] },
    });
    const rows = await TutoringBimbelService.listPaymentTypes();

    // NaN would reach MoneyInput and render an empty box the prefill
    // guard then treats as "untouched" forever.
    expect(rows[0].amount).toBe(0);
    expect(Number.isNaN(rows[0].amount)).toBe(false);
  });

  it('keeps INACTIVE rows — the picker shows their status instead of hiding them', async () => {
    const rows = await TutoringBimbelService.listPaymentTypes();

    expect(rows).toHaveLength(2);
    expect(rows.find((r) => r.id === 'pt-3')?.status).toBe('inactive');
  });

  it('preserves the server-computed default marker', async () => {
    const rows = await TutoringBimbelService.listPaymentTypes();

    expect(rows.filter((r) => r.is_default).map((r) => r.id)).toEqual(['pt-1']);
  });

  it('forwards a search term and omits the param when there is none', async () => {
    await TutoringBimbelService.listPaymentTypes({ search: 'daftar' });
    expect(api.get).toHaveBeenLastCalledWith(
      '/tutoring-v2/payment-types',
      { params: { search: 'daftar' } },
    );

    await TutoringBimbelService.listPaymentTypes();
    expect(api.get).toHaveBeenLastCalledWith(
      '/tutoring-v2/payment-types',
      { params: {} },
    );
  });
});
