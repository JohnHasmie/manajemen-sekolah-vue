/**
 * Contract spec for the VouchersService RECIPIENT methods.
 *
 * These three calls are the only client of a capability that shipped
 * server-side with no client at all, so nothing else in the repo holds
 * their shape. What is pinned here, and why each is worth a test:
 *
 *   • THE URL CARRIES THE VOUCHER ID. All three routes are nested under
 *     `/vouchers/{id}`; a voucher id that fails to reach the path would
 *     read or edit a DIFFERENT voucher's recipient list, and every
 *     response would still look plausible.
 *
 *   • THE ATTACH PAYLOAD IS `{ student_ids: [...] }`. Read off
 *     `AttachVoucherRecipientsRequest`, whose rules are
 *     `student_ids => required|array|min:1|max:500` and
 *     `student_ids.* => required|uuid|distinct`. A wrong key is a 422
 *     the admin reads as "gagal menyimpan", so the key itself is the
 *     assertion — not the fact that a POST happened.
 *
 *   • DETACH NAMES THE STUDENT IN THE PATH, NOT A BODY. The route is
 *     `DELETE …/recipients/{studentId}`, and the student id is the
 *     STUDENT's, never the recipient row's. Sending the row id would
 *     delete nothing and return a cheerful `detached_count: 0`.
 *
 *   • `meta` IS WHERE THE COUNT LIVES. Both writes answer with a
 *     voucher under `data` and the number of rows they changed under
 *     `meta.attached_count` / `meta.detached_count`. Reading it off
 *     `data` would silently report 0 for every successful write.
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

const VOUCHER_ID = '0192d3f4-1111-7000-8000-000000000001';
const STUDENT_A = '0192d3f4-2222-7000-8000-00000000000a';
const STUDENT_B = '0192d3f4-2222-7000-8000-00000000000b';

/** A refreshed voucher row, the shape both writes hand back. */
function voucherRow(overrides = {}) {
  return {
    id: VOUCHER_ID,
    school_id: 'sc-1',
    code: 'HEMAT10',
    kind: 'percent',
    value: 10,
    status: 'active',
    redemption_count: 0,
    recipient_count: 1,
    is_targeted: true,
    ...overrides,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe('VouchersService.listRecipients', () => {
  it('GETs the recipients route for THAT voucher id', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'vr-1',
            voucher_id: VOUCHER_ID,
            student_id: STUDENT_A,
            student_name: 'Andi Wijaya',
            student_number: '2401',
          },
        ],
      },
    });

    const rows = await VouchersService.listRecipients(VOUCHER_ID);

    expect(api.get).toHaveBeenCalledWith(
      `/tutoring-v2/vouchers/${VOUCHER_ID}/recipients`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].student_id).toBe(STUDENT_A);
    expect(rows[0].student_name).toBe('Andi Wijaya');
  });

  it('an EMPTY list is an answer, not a failure — it means general promo', async () => {
    (api.get as any).mockResolvedValueOnce({ data: { data: [] } });

    await expect(VouchersService.listRecipients(VOUCHER_ID)).resolves.toEqual([]);
  });
});

describe('VouchersService.attachRecipients', () => {
  it('POSTs { student_ids: [...] } — the exact key the FormRequest validates', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: voucherRow({ recipient_count: 2 }), meta: { attached_count: 2 } },
    });

    await VouchersService.attachRecipients(VOUCHER_ID, [STUDENT_A, STUDENT_B]);

    expect(api.post).toHaveBeenCalledWith(
      `/tutoring-v2/vouchers/${VOUCHER_ID}/recipients`,
      { student_ids: [STUDENT_A, STUDENT_B] },
    );
    // Said twice on purpose: the object comparison above would still
    // pass if the service invented a `students` alias ALONGSIDE the
    // right key on some future refactor of the assertion, and the wire
    // key is the whole contract.
    const body = (api.post as any).mock.calls[0][1];
    expect(Object.keys(body)).toEqual(['student_ids']);
    expect(Array.isArray(body.student_ids)).toBe(true);
  });

  it('returns the refreshed voucher plus meta.attached_count', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: voucherRow({ recipient_count: 3 }), meta: { attached_count: 2 } },
    });

    const result = await VouchersService.attachRecipients(VOUCHER_ID, [
      STUDENT_A,
      STUDENT_B,
    ]);

    expect(result.voucher.recipient_count).toBe(3);
    expect(result.voucher.is_targeted).toBe(true);
    expect(result.changedCount).toBe(2);
  });

  it('a re-attach answers 0 changed — idempotent, not failed', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: voucherRow(), meta: { attached_count: 0 } },
    });

    const result = await VouchersService.attachRecipients(VOUCHER_ID, [STUDENT_A]);

    expect(result.changedCount).toBe(0);
  });

  it('degrades to 0 rather than throwing when meta is absent', async () => {
    (api.post as any).mockResolvedValueOnce({ data: { data: voucherRow() } });

    const result = await VouchersService.attachRecipients(VOUCHER_ID, [STUDENT_A]);

    expect(result.changedCount).toBe(0);
    expect(result.voucher.id).toBe(VOUCHER_ID);
  });
});

describe('VouchersService.detachRecipient', () => {
  it('DELETEs …/recipients/{studentId} with the STUDENT id in the path', async () => {
    (api.delete as any).mockResolvedValueOnce({
      data: {
        data: voucherRow({ recipient_count: 0, is_targeted: false }),
        meta: { detached_count: 1 },
      },
    });

    const result = await VouchersService.detachRecipient(VOUCHER_ID, STUDENT_A);

    expect(api.delete).toHaveBeenCalledWith(
      `/tutoring-v2/vouchers/${VOUCHER_ID}/recipients/${STUDENT_A}`,
    );
    // No body: the route takes the student in the path.
    expect((api.delete as any).mock.calls[0]).toHaveLength(1);
    expect(result.changedCount).toBe(1);
    // Removing the last recipient WIDENS the voucher back to general.
    expect(result.voucher.is_targeted).toBe(false);
    expect(result.voucher.recipient_count).toBe(0);
  });

  it('detaching a non-recipient answers 0 changed — idempotent', async () => {
    (api.delete as any).mockResolvedValueOnce({
      data: { data: voucherRow(), meta: { detached_count: 0 } },
    });

    const result = await VouchersService.detachRecipient(VOUCHER_ID, STUDENT_B);

    expect(result.changedCount).toBe(0);
  });
});
