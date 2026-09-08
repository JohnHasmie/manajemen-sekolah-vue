/**
 * DiscountCodeFormModal — the "Berlaku sejak / Berlaku sampai" pair.
 *
 * The component shipped with no spec at all. This one is scoped to the
 * date window, because that pair has a rule the markup did not encode:
 *
 *   CreateDiscountCodeRequest / UpdateDiscountCodeRequest
 *     'valid_until' => ['nullable', 'date', 'after:valid_from']
 *
 * `after:` is STRICT. A code whose window starts and ends on the same
 * day is a 422, not a one-day promo. That is the whole reason this file
 * exists rather than a copy of the tutoring-voucher assertions: vouchers
 * use `after_or_equal:valid_from`, so their inclusive `:min="valid_from"`
 * is an exact mirror of their backend and would be an OFF-BY-ONE here —
 * it would leave `valid_from` itself selectable, and selectable is how a
 * user reads "allowed".
 *
 * Hence two layers, both pinned below:
 *   • `min` = valid_from + 1 day — the picker never offers a day the API
 *     will refuse, and omits the attribute entirely while valid_from is
 *     blank.
 *   • a submit guard — `min` constrains the CALENDAR, not the KEYBOARD,
 *     and a typed date sails straight past it into a 422.
 */
// @ts-nocheck — vitest types not installed in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import DiscountCodeFormModal from './DiscountCodeFormModal.vue';
import { DiscountCodeService } from '@/services/discount-code.service';

vi.mock('@/services/discount-code.service', () => ({
  DiscountCodeService: {
    create: vi.fn(),
    update: vi.fn(),
  },
}));

const ERR_UNTIL =
  'Tanggal "Berlaku sampai" harus setelah "Berlaku sejak" — minimal satu hari sesudahnya.';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        superAdmin: {
          discountCodes: { errUntilNotAfterFrom: ERR_UNTIL },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

/**
 * Modal teleports to document.body, which puts the form outside the
 * wrapper's subtree and out of reach of `wrapper.find`. Swap the shell
 * for an in-place passthrough; nothing under test lives in it.
 */
const STUBS = {
  Modal: { template: '<div><slot /></div>' },
};

function mountModal(code = null) {
  return mount(DiscountCodeFormModal, {
    props: { code },
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
}

/** Fill the non-date fields so submit() reaches the date guard. */
async function fillRequired(wrapper) {
  await wrapper.find('#dc-code').setValue('WELCOME20');
  await wrapper.find('#dc-desc').setValue('Diskon onboarding sekolah baru.');
}

async function submitForm(wrapper) {
  await wrapper.find('form').trigger('submit');
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe('DiscountCodeFormModal — valid_until lower bound', () => {
  it('omits `min` entirely while "Berlaku sejak" is empty', () => {
    const wrapper = mountModal();
    const until = wrapper.find('#dc-until');

    // Not `min=""`. An empty attribute is a value the browser has to
    // interpret; an absent one is unambiguous.
    expect(until.attributes('min')).toBeUndefined();
  });

  it('sets `min` to the day AFTER valid_from, not valid_from itself', async () => {
    const wrapper = mountModal();
    await wrapper.find('#dc-from').setValue('2026-09-01');

    // The voucher idiom would put '2026-09-01' here. That day is exactly
    // the one `after:valid_from` rejects.
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2026-09-02');
  });

  it('carries the +1 day across a month boundary', async () => {
    const wrapper = mountModal();
    await wrapper.find('#dc-from').setValue('2026-09-30');
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2026-10-01');
  });

  it('carries the +1 day across a year boundary', async () => {
    const wrapper = mountModal();
    await wrapper.find('#dc-from').setValue('2026-12-31');
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2027-01-01');
  });

  it('drops `min` again when valid_from is cleared', async () => {
    const wrapper = mountModal();
    await wrapper.find('#dc-from').setValue('2026-09-01');
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2026-09-02');

    await wrapper.find('#dc-from').setValue('');
    expect(wrapper.find('#dc-until').attributes('min')).toBeUndefined();
  });

  it('bounds the picker in EDIT mode too, seeded from the hydrated row', () => {
    // The backend serialises timestamps; the form slices them to a day.
    const wrapper = mountModal({
      id: 'dc-1',
      code: 'WELCOME20',
      description: 'Diskon onboarding sekolah baru.',
      type: 'percent',
      value: 20,
      duration_months: 3,
      max_uses: null,
      min_amount_monthly: 0,
      valid_from: '2026-09-01T00:00:00.000000Z',
      valid_until: '2026-12-31T00:00:00.000000Z',
      first_time_only: false,
      status: 'active',
      target_scope: 'all',
      target_keys: null,
      tenant_scope_ids: null,
      used_count: 0,
    });

    expect(wrapper.find('#dc-from').element.value).toBe('2026-09-01');
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2026-09-02');
  });
});

describe('DiscountCodeFormModal — submit-time date guard', () => {
  it('refuses a SAME-DAY window, mirroring `after:` rather than `after_or_equal:`', async () => {
    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-from').setValue('2026-09-01');
    await wrapper.find('#dc-until').setValue('2026-09-01');

    await submitForm(wrapper);

    // The load-bearing half: no request left the browser, so the user
    // never sees the backend's 422 for this.
    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(ERR_UNTIL);
  });

  it('refuses a REVERSED window', async () => {
    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-from').setValue('2026-09-10');
    await wrapper.find('#dc-until').setValue('2026-09-01');

    await submitForm(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(ERR_UNTIL);
  });

  it('catches a TYPED out-of-range date, which `min` cannot', async () => {
    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-from').setValue('2026-09-01');

    // `min` is '2026-09-02', but a date input still accepts any
    // well-formed day the keyboard produces — this is precisely the case
    // the attribute does NOT cover.
    expect(wrapper.find('#dc-until').attributes('min')).toBe('2026-09-02');
    await wrapper.find('#dc-until').setValue('2026-08-15');

    await submitForm(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(ERR_UNTIL);
  });

  it('accepts the next day — the tightest window the API allows', async () => {
    DiscountCodeService.create.mockResolvedValue({ id: 'dc-1', code: 'WELCOME20' });

    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-from').setValue('2026-09-01');
    await wrapper.find('#dc-until').setValue('2026-09-02');

    await submitForm(wrapper);

    expect(DiscountCodeService.create).toHaveBeenCalledTimes(1);
    const payload = DiscountCodeService.create.mock.calls[0][0];
    expect(payload.valid_from).toBe('2026-09-01');
    expect(payload.valid_until).toBe('2026-09-02');
  });

  it('lets an OPEN-ENDED window through and sends null, not ""', async () => {
    DiscountCodeService.create.mockResolvedValue({ id: 'dc-1', code: 'WELCOME20' });

    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-from').setValue('2026-09-01');
    // valid_until left blank — a code with no end date is legitimate.

    await submitForm(wrapper);

    expect(DiscountCodeService.create).toHaveBeenCalledTimes(1);
    expect(DiscountCodeService.create.mock.calls[0][0].valid_until).toBeNull();
  });

  it('does not invent a rule when valid_from is blank', async () => {
    DiscountCodeService.create.mockResolvedValue({ id: 'dc-1', code: 'WELCOME20' });

    const wrapper = mountModal();
    await fillRequired(wrapper);
    await wrapper.find('#dc-until').setValue('2026-09-01');

    // With no start date there is no client-side ordering to enforce —
    // whatever `after:valid_from` means against a null is the backend's
    // call, and guessing at it here would block a save the API accepts.
    await submitForm(wrapper);

    expect(DiscountCodeService.create).toHaveBeenCalledTimes(1);
    expect(DiscountCodeService.create.mock.calls[0][0].valid_from).toBeNull();
  });
});
