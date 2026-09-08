/**
 * discount-code.service — the `normalize()` step on the write path.
 *
 * Checked here because the date-window fix in DiscountCodeFormModal sits
 * directly on top of it, and the obvious "while I'm here" change would
 * have been to make the modal coerce empty dates itself. It must not:
 * that job is already done, once, at the single point every write goes
 * through, and duplicating it is how two half-rules drift apart.
 *
 * The contract, from the service's own docblock — "Empty-string
 * date/number fields → null so the backend's nullable validation
 * succeeds" — has three distinct cases, and the difference between the
 * last two is load-bearing:
 *
 *   ''         → key DELETED   (field untouched; `nullable` never sees it)
 *   undefined  → key DELETED   (same)
 *   null       → key SENT      (explicitly CLEARS the field server-side)
 *
 * Asserted through `create`/`update` rather than by calling `normalize`
 * directly, so the test also pins that the write paths actually route
 * through it — a normaliser nothing calls is the failure mode that
 * matters.
 */
// @ts-nocheck — vitest types not installed in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DiscountCodeService } from './discount-code.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
  },
}));

/** A create payload with every field the form can send. */
function makePayload(overrides = {}) {
  return {
    code: 'welcome20',
    description: 'Diskon onboarding sekolah baru.',
    type: 'percent',
    value: 20,
    duration_months: 3,
    max_uses: null,
    min_amount_monthly: 0,
    valid_from: '2026-09-01',
    valid_until: '2026-12-31',
    first_time_only: false,
    status: 'draft',
    target_scope: 'all',
    target_keys: null,
    tenant_scope_ids: null,
    ...overrides,
  };
}

/** The body `create` actually put on the wire. */
function postedBody() {
  expect(api.post).toHaveBeenCalledTimes(1);
  return api.post.mock.calls[0][1];
}

beforeEach(() => {
  vi.clearAllMocks();
  api.post.mockResolvedValue({ data: { id: 'dc-1' } });
  api.patch.mockResolvedValue({ data: { id: 'dc-1' } });
});

describe('DiscountCodeService.normalize — empty date handling', () => {
  it('DELETES empty-string dates rather than sending ""', async () => {
    await DiscountCodeService.create(
      makePayload({ valid_from: '', valid_until: '' }),
    );

    const body = postedBody();
    // `'valid_from' => ['nullable', 'date']` fails on '' — the key has to
    // be gone, not blank.
    expect(body).not.toHaveProperty('valid_from');
    expect(body).not.toHaveProperty('valid_until');
  });

  it('DELETES undefined dates', async () => {
    await DiscountCodeService.create(
      makePayload({ valid_from: undefined, valid_until: undefined }),
    );

    const body = postedBody();
    expect(body).not.toHaveProperty('valid_from');
    expect(body).not.toHaveProperty('valid_until');
  });

  it('SENDS an explicit null through — that is how a date gets cleared', async () => {
    // This is the case the modal relies on: it maps '' → null before
    // calling, so a super-admin who empties "Berlaku sampai" on an
    // existing code actually removes the end date instead of silently
    // leaving the old one in place.
    await DiscountCodeService.create(
      makePayload({ valid_from: null, valid_until: null }),
    );

    const body = postedBody();
    expect(body).toHaveProperty('valid_from', null);
    expect(body).toHaveProperty('valid_until', null);
  });

  it('leaves real dates untouched', async () => {
    await DiscountCodeService.create(makePayload());

    const body = postedBody();
    expect(body.valid_from).toBe('2026-09-01');
    expect(body.valid_until).toBe('2026-12-31');
  });

  it('applies the same rule to the three non-date nullable fields', async () => {
    await DiscountCodeService.create(
      makePayload({ duration_months: '', max_uses: undefined, min_amount_monthly: '' }),
    );

    const body = postedBody();
    expect(body).not.toHaveProperty('duration_months');
    expect(body).not.toHaveProperty('max_uses');
    expect(body).not.toHaveProperty('min_amount_monthly');
  });

  it('uppercases + trims the code on the wire', async () => {
    await DiscountCodeService.create(makePayload({ code: '  welcome20  ' }));
    expect(postedBody().code).toBe('WELCOME20');
  });

  it('routes the PATCH path through the same normaliser', async () => {
    // A partial update is exactly where an empty string would do the most
    // damage — `sometimes|nullable|date` on a '' is a 422, and the
    // super-admin would have no idea which field caused it.
    await DiscountCodeService.update('dc-1', {
      code: '  welcome20  ',
      valid_until: '',
    });

    expect(api.patch).toHaveBeenCalledTimes(1);
    const body = api.patch.mock.calls[0][1];
    expect(body.code).toBe('WELCOME20');
    expect(body).not.toHaveProperty('valid_until');
  });

  it('does not mutate the caller\'s payload object', async () => {
    // The modal keeps its `form` ref alive after a failed save; a
    // normaliser that deleted keys in place would leave the reopened
    // sheet missing fields.
    const payload = makePayload({ valid_until: '' });
    await DiscountCodeService.create(payload);

    expect(payload).toHaveProperty('valid_until', '');
    expect(payload.code).toBe('welcome20');
  });
});
