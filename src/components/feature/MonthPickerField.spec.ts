/**
 * MonthPickerField — the labeled "Periode" control that replaced the
 * `<input type="month">` (tutor Honor page, admin attendance recap) and
 * the `<input type="text" placeholder="YYYY-MM">` fields (admin payout
 * summary + month-close), which had no picker in ANY browser.
 *
 * ── The invariant that matters most ──
 *
 * The visible text is DERIVED from `modelValue`, never separately
 * editable. That is what makes "the displayed text and the model
 * silently disagree" structurally impossible, and it is why free typing
 * was dropped rather than kept alongside the picker: the model is a
 * machine format (`YYYY-MM`), and a text box over it either accepts
 * `2026-9` and writes a value the API cannot read, or rejects it and
 * demands the user know the wire format.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The real <MonthPickerModal> and <FormField> are mounted — only
 *    `<Teleport>` is stubbed. A hand-written picker stub would be a
 *    second implementation of the thing under test.
 * 2. The "emits once" test asserts the COUNT, not merely that something
 *    was emitted. A host `watch(month, reload)` double-firing is the
 *    specific regression being locked out.
 * 3. The label tests assert a real formatted string ("September 2026"),
 *    not just "not empty" — a component rendering the raw `2026-09`, or
 *    "Invalid Date", would fail.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import MonthPickerField from './MonthPickerField.vue';
import idMessages from '@/locales/id.json';
import { YM_PATTERN } from '@/lib/local-date';

const TRIGGER = '[data-month-trigger]';
const MODAL = '[data-testid="month-picker-modal"]';
const CELL = '[data-testid="month-picker-cell"]';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

function mountField(props = {}) {
  return mount(MonthPickerField, {
    props: {
      modelValue: '2026-09',
      label: 'Periode',
      min: '2024-01',
      max: '2026-12',
      ...props,
    },
    global: {
      plugins: [makeI18n()],
      stubs: { teleport: true },
    },
  });
}

describe('MonthPickerField', () => {
  it('renders a button, not a text input — nothing here is typeable', () => {
    const w = mountField();
    expect(w.get(TRIGGER).element.tagName).toBe('BUTTON');
    expect(w.find('input').exists()).toBe(false);
  });

  it('shows the month as a human label derived from the model', () => {
    expect(mountField({ modelValue: '2026-09' }).get(TRIGGER).text()).toBe('September 2026');
    expect(mountField({ modelValue: '2026-01' }).get(TRIGGER).text()).toBe('Januari 2026');
  });

  it('keeps the label in lockstep with the model — they cannot drift', async () => {
    const w = mountField({ modelValue: '2026-09' });
    expect(w.get(TRIGGER).text()).toBe('September 2026');
    await w.setProps({ modelValue: '2026-02' });
    expect(w.get(TRIGGER).text()).toBe('Februari 2026');
  });

  it('renders the label through FormField', () => {
    expect(mountField({ label: 'Periode' }).get('label').text()).toContain('Periode');
  });

  it('is closed until the trigger is clicked', async () => {
    const w = mountField();
    expect(w.find(MODAL).exists()).toBe(false);
    await w.get(TRIGGER).trigger('click');
    expect(w.find(MODAL).exists()).toBe(true);
  });

  it('emits YYYY-MM exactly once when a month is picked', async () => {
    const w = mountField({ modelValue: '2026-09' });
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March

    const emitted = w.emitted('update:modelValue');
    // Exactly one — a host `watch(month, reload)` must not double-fetch.
    expect(emitted).toHaveLength(1);
    expect(emitted[0][0]).toBe('2026-03');
    expect(emitted[0][0]).toMatch(YM_PATTERN);
  });

  it('closes after a pick', async () => {
    const w = mountField();
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('does NOT emit when the already-selected month is re-picked', async () => {
    const w = mountField({ modelValue: '2026-09' });
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[8].trigger('click'); // September — already selected

    // A same-value emit would still trip a host watcher on some shapes;
    // the field swallows it instead.
    expect(w.emitted('update:modelValue')).toBeUndefined();
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('forwards bounds to the picker', async () => {
    const w = mountField({ modelValue: '2026-09', min: '2024-01', max: '2026-09' });
    await w.get(TRIGGER).trigger('click');
    const cells = w.findAll(CELL);
    expect(cells[8].attributes('disabled')).toBeUndefined(); // Sep == max
    expect(cells[9].attributes('disabled')).toBeDefined(); // Oct, past max
  });

  it('cannot be opened while disabled', async () => {
    const w = mountField({ disabled: true });
    expect(w.get(TRIGGER).attributes('disabled')).toBeDefined();
    await w.get(TRIGGER).trigger('click');
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('surfaces a FormField error line', () => {
    const w = mountField({ error: 'Format periode tidak valid' });
    expect(w.text()).toContain('Format periode tidak valid');
  });

  it('announces the current selection to assistive tech', () => {
    const w = mountField({ modelValue: '2026-09' });
    const trigger = w.get(TRIGGER);
    expect(trigger.attributes('aria-label')).toBe('Pilih bulan: September 2026');
    expect(trigger.attributes('aria-haspopup')).toBe('dialog');
    expect(trigger.attributes('aria-expanded')).toBe('false');
  });
});
