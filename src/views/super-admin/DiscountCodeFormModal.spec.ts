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
 *
 * ── Second concern: the client-side messages are translated ──
 *
 * submit() gates five things before it will hit the API. Four of them
 * carried a hardcoded Indonesian string literal; only the date one went
 * through `t()`. They are all keys now, and the last block below pins
 * each in BOTH locales.
 *
 * The value-cap message is the one worth the extra care. It interpolates
 * a number, and that number used to be formatted with a hardcoded
 * `toLocaleString('id-ID')`. Moving only the SENTENCE into i18n would
 * have produced an English message carrying Indonesian digit grouping —
 * "between 1 and 100.000.000", which an English reader parses as a
 * decimal point. So the en cases assert the grouping too, and one of
 * them asserts the id-grouped form is ABSENT: a regression that reverts
 * the formatter while keeping the key would still render the right
 * words, and only that negative catches it.
 */
// @ts-nocheck — vitest types not installed in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import DiscountCodeFormModal from './DiscountCodeFormModal.vue';
import { i18n } from '@/lib/i18n';
import { DiscountCodeService } from '@/services/discount-code.service';

vi.mock('@/services/discount-code.service', () => ({
  DiscountCodeService: {
    create: vi.fn(),
    update: vi.fn(),
  },
}));

const ERR_UNTIL =
  'Tanggal "Berlaku sampai" harus setelah "Berlaku sejak" — minimal satu hari sesudahnya.';

/**
 * Mounts get the APP's i18n instance, not a hand-written stub, and that
 * is deliberate on two counts.
 *
 * 1. A stub tree makes `t()` echo whatever the stub happens to contain.
 *    An assertion against it proves the component calls SOME key, not
 *    that the key exists in `id.json` and `en.json` — the exact gap
 *    `locale-messages-render.spec.ts` was written about. Here the
 *    messages come from the shipped files, so a key that is missing
 *    from either locale renders as its own path and fails loudly.
 *
 * 2. `formatNumber` (`@/lib/format`) resolves its BCP-47 tag from this
 *    singleton, not from whatever instance happens to be installed on
 *    the app. In the browser those are the same object; under a stub
 *    instance they are not, and the locale switch below would move the
 *    words while leaving the digits on id-ID — i.e. the spec would go
 *    green on precisely the bug it exists to catch. One instance, one
 *    locale to set.
 *
 * The singleton is module-level state, so the locale is restored after
 * every case.
 */
function setLocale(locale) {
  i18n.global.locale.value = locale;
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
    global: { plugins: [i18n], stubs: STUBS },
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

afterEach(() => {
  setLocale('id');
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

describe('DiscountCodeFormModal — client validation messages are translated', () => {
  /**
   * Drive submit() into one specific guard and read back what the user
   * is shown. Each helper stops at the FIRST failing check, which is why
   * the earlier fields are filled in ascending order.
   */
  async function submitWithShortCode(wrapper) {
    // `code` starts empty — 0 characters is already under the minimum.
    await wrapper.find('#dc-desc').setValue('Diskon onboarding sekolah baru.');
    await submitForm(wrapper);
  }

  async function submitWithShortDescription(wrapper) {
    await wrapper.find('#dc-code').setValue('WELCOME20');
    await wrapper.find('#dc-desc').setValue('abc');
    await submitForm(wrapper);
  }

  async function submitWithOutOfRangePercent(wrapper) {
    await fillRequired(wrapper);
    // Type is 'percent' by default; clearing the amount lands on 0,
    // which the 1-90 guard rejects.
    await wrapper.find('#dc-value').setValue('');
    await submitForm(wrapper);
  }

  async function submitWithOutOfRangeValue(wrapper) {
    await fillRequired(wrapper);
    // 'fixed' skips the percent guard and raises the cap to 100,000,000
    // — the branch whose message interpolates a formatted number.
    await wrapper.find('#dc-type').setValue('fixed');
    await wrapper.find('#dc-value').setValue('');
    await submitForm(wrapper);
  }

  it('shows the code-length error in Indonesian', async () => {
    const wrapper = mountModal();
    await submitWithShortCode(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Kode minimal 4 karakter.');
  });

  it('shows the code-length error in English under the en locale', async () => {
    setLocale('en');
    const wrapper = mountModal();
    await submitWithShortCode(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('The code must be at least 4 characters.');
    expect(wrapper.text()).not.toContain('Kode minimal 4 karakter.');
  });

  it('shows the description-length error in Indonesian', async () => {
    const wrapper = mountModal();
    await submitWithShortDescription(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Deskripsi minimal 5 karakter.');
  });

  it('shows the description-length error in English under the en locale', async () => {
    setLocale('en');
    const wrapper = mountModal();
    await submitWithShortDescription(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('The description must be at least 5 characters.');
    expect(wrapper.text()).not.toContain('Deskripsi minimal 5 karakter.');
  });

  it('shows the percent-range error in Indonesian', async () => {
    const wrapper = mountModal();
    await submitWithOutOfRangePercent(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Diskon persen harus antara 1-90%.');
  });

  it('shows the percent-range error in English under the en locale', async () => {
    setLocale('en');
    const wrapper = mountModal();
    await submitWithOutOfRangePercent(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('A percentage discount must be between 1% and 90%.');
    expect(wrapper.text()).not.toContain('Diskon persen harus antara 1-90%.');
  });

  it('interpolates the cap with Indonesian grouping under the id locale', async () => {
    const wrapper = mountModal();
    await submitWithOutOfRangeValue(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    // Verbatim the sentence this branch shipped with, dots and all.
    expect(wrapper.text()).toContain('Nilai harus antara 1 dan 100.000.000.');
  });

  it('interpolates the cap with ENGLISH grouping under the en locale', async () => {
    setLocale('en');
    const wrapper = mountModal();
    await submitWithOutOfRangeValue(wrapper);

    expect(DiscountCodeService.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('The value must be between 1 and 100,000,000.');

    // The load-bearing half. Translating the sentence while leaving the
    // old `toLocaleString('id-ID')` in place still renders every English
    // word above — only the absence of the id-grouped number separates a
    // real fix from that half-migration.
    expect(wrapper.text()).not.toContain('100.000.000');
  });

  it('keeps the percent cap out of the fixed-amount message and vice versa', async () => {
    // Same key, two caps: the message must follow `valueMax`, not a
    // constant someone inlined. A percent code that is out of range is
    // caught by the earlier guard, so the only way to see '90' here is
    // through the shared branch — assert the fixed case says 100.000.000
    // and not 90.
    const wrapper = mountModal();
    await submitWithOutOfRangeValue(wrapper);

    expect(wrapper.text()).toContain('100.000.000');
    expect(wrapper.text()).not.toContain('antara 1 dan 90.');
  });
});
