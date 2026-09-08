/**
 * MonthPickerModal — the picker that replaced `<input type="month">`.
 *
 * ── Why the component exists ──
 *
 * "role guru/tutor pada halaman honor, di input periode jadikan ketika
 * input di klik maka menampilkan kalender yang dapat dipilih, bukan
 * input yang hanya dapat diketik."
 *
 * The field was ALREADY `type="month"`, which is the correct input type
 * for a `YYYY-MM` value — so the obvious "set the input type" fix was a
 * no-op. The actual cause is browser support: desktop Safari ships no
 * picker UI for `type="month"` and degrades it to a plain text box
 * (MDN: only Chrome/Opera and Edge on desktop have usable
 * implementations). The reporter was on macOS Safari.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. Tests DRIVE THE DOM — query a cell, `trigger('click')`, then assert
 *    on the emitted payload. Nothing reaches into `w.vm` to call a
 *    handler, so a component whose buttons were not wired would fail.
 * 2. Only `<Teleport>` is stubbed. The real `<Modal>` renders, so these
 *    assertions run against the actual shipped surface rather than a
 *    second implementation of it.
 * 3. The bounds tests assert BOTH that an out-of-range cell is disabled
 *    AND that an in-range one is not. A component that disabled every
 *    cell would otherwise pass them.
 * 4. Every emitted value is asserted to match `YM_PATTERN`, not merely
 *    to be truthy — the whole contract is the wire format.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import MonthPickerModal from './MonthPickerModal.vue';
import idMessages from '@/locales/id.json';
import { YM_PATTERN } from '@/lib/local-date';

const CELL = '[data-testid="month-picker-cell"]';
const YEAR = '[data-testid="month-picker-year"]';
const PREV = '[data-testid="month-picker-prev-year"]';
const NEXT = '[data-testid="month-picker-next-year"]';
const THIS_MONTH = '[data-testid="month-picker-this-month"]';

/** The real shipped copy — `missingWarn: false` would hide a typo'd key. */
function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

function mountPicker(props = {}) {
  return mount(MonthPickerModal, {
    props: {
      modelValue: '2026-05',
      // Pinned so the grid does not drift with the wall clock. Without
      // explicit bounds the component applies its own [now-36m, now].
      min: '2024-01',
      max: '2026-09',
      ...props,
    },
    global: {
      plugins: [makeI18n()],
      // Modal teleports to <body>; keep its output inside the wrapper.
      stubs: { teleport: true },
    },
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  // A fixed "now" so `thisMonth` (and therefore the "Bulan ini" button
  // and the aria-current cell) is deterministic.
  vi.setSystemTime(new Date(2026, 8, 15, 12, 0, 0)); // 15 Sep 2026, LOCAL
});

afterEach(() => {
  vi.useRealTimers();
});

describe('MonthPickerModal', () => {
  it('renders a 12-month grid for the selected value\'s year', () => {
    const w = mountPicker();
    expect(w.findAll(CELL)).toHaveLength(12);
    expect(w.get(YEAR).text()).toBe('2026');
  });

  it('opens on the year of the CURRENT value, not the current year', () => {
    const w = mountPicker({ modelValue: '2025-03', min: '2024-01', max: '2026-09' });
    expect(w.get(YEAR).text()).toBe('2025');
  });

  it('emits the picked month as YYYY-MM and closes', async () => {
    const w = mountPicker();
    // Index 2 === March; the grid is January-first.
    await w.findAll(CELL)[2].trigger('click');

    const applied = w.emitted('apply');
    expect(applied).toHaveLength(1);
    expect(applied[0][0]).toBe('2026-03');
    expect(applied[0][0]).toMatch(YM_PATTERN);
    expect(w.emitted('close')).toHaveLength(1);
  });

  it('emits a zero-padded month for single-digit months', async () => {
    const w = mountPicker();
    await w.findAll(CELL)[0].trigger('click'); // January
    expect(w.emitted('apply')[0][0]).toBe('2026-01');
  });

  it('disables months after `max` but leaves earlier ones selectable', () => {
    const w = mountPicker({ max: '2026-09' });
    const cells = w.findAll(CELL);
    // Sep (index 8) is the ceiling: selectable. Oct (9) is past it.
    expect(cells[8].attributes('disabled')).toBeUndefined();
    expect(cells[9].attributes('disabled')).toBeDefined();
    expect(cells[11].attributes('disabled')).toBeDefined();
  });

  it('disables months before `min` but leaves later ones selectable', () => {
    const w = mountPicker({ modelValue: '2024-06', min: '2024-04', max: '2026-09' });
    const cells = w.findAll(CELL);
    expect(cells[2].attributes('disabled')).toBeDefined(); // Mar 2024
    expect(cells[3].attributes('disabled')).toBeUndefined(); // Apr 2024 == min
  });

  it('does not emit when a disabled month is clicked', async () => {
    const w = mountPicker({ max: '2026-09' });
    await w.findAll(CELL)[11].trigger('click'); // Dec 2026, past max
    expect(w.emitted('apply')).toBeUndefined();
  });

  it('steps the visible year within the allowed range', async () => {
    const w = mountPicker({ modelValue: '2025-05', min: '2024-01', max: '2026-09' });
    expect(w.get(YEAR).text()).toBe('2025');
    await w.get(NEXT).trigger('click');
    expect(w.get(YEAR).text()).toBe('2026');
    await w.get(PREV).trigger('click');
    await w.get(PREV).trigger('click');
    expect(w.get(YEAR).text()).toBe('2024');
  });

  it('disables year navigation at the range edges', async () => {
    const w = mountPicker({ modelValue: '2024-05', min: '2024-01', max: '2026-09' });
    expect(w.get(PREV).attributes('disabled')).toBeDefined();
    expect(w.get(NEXT).attributes('disabled')).toBeUndefined();

    const top = mountPicker({ modelValue: '2026-05', min: '2024-01', max: '2026-09' });
    expect(top.get(NEXT).attributes('disabled')).toBeDefined();
    expect(top.get(PREV).attributes('disabled')).toBeUndefined();
  });

  it('keeps a boundary year reachable when the bound falls mid-year', async () => {
    // min = 2024-11: 2024 still holds two selectable months, so stepping
    // back into it must be allowed. Checking only January would have
    // wrongly disabled the arrow.
    const w = mountPicker({ modelValue: '2025-03', min: '2024-11', max: '2026-09' });
    expect(w.get(PREV).attributes('disabled')).toBeUndefined();
    await w.get(PREV).trigger('click');
    expect(w.get(YEAR).text()).toBe('2024');
    const cells = w.findAll(CELL);
    expect(cells[9].attributes('disabled')).toBeDefined(); // Oct 2024
    expect(cells[10].attributes('disabled')).toBeUndefined(); // Nov 2024 == min
  });

  it('"Bulan ini" jumps to the CURRENT LOCAL month', async () => {
    const w = mountPicker({ modelValue: '2025-02', min: '2024-01', max: '2026-09' });
    await w.get(THIS_MONTH).trigger('click');
    // System time is 15 Sep 2026 local (see beforeEach).
    expect(w.emitted('apply')[0][0]).toBe('2026-09');
  });

  it('hides "Bulan ini" when the current month is outside the allowed range', () => {
    const w = mountPicker({ modelValue: '2024-05', min: '2024-01', max: '2024-12' });
    expect(w.find(THIS_MONTH).exists()).toBe(false);
  });

  it('marks the selected cell pressed and the current month as aria-current', () => {
    const w = mountPicker({ modelValue: '2026-03', min: '2024-01', max: '2026-09' });
    const cells = w.findAll(CELL);
    expect(cells[2].attributes('aria-pressed')).toBe('true');
    expect(cells[8].attributes('aria-current')).toBe('date'); // Sep 2026 = now
    expect(cells[0].attributes('aria-pressed')).toBe('false');
  });

  it('gives every cell a full-month accessible name, not just "Mei"', () => {
    const w = mountPicker();
    expect(w.findAll(CELL)[4].attributes('aria-label')).toBe('Mei 2026');
  });

  it('falls back to the current LOCAL year when handed a malformed value', () => {
    // Never a UTC-derived year: system time is 15 Sep 2026 local.
    const w = mountPicker({ modelValue: 'not-a-month', min: '2024-01', max: '2026-09' });
    expect(w.get(YEAR).text()).toBe('2026');
  });
});
