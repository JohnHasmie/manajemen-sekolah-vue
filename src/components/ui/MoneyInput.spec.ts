/**
 * Contract spec for <MoneyInput>.
 *
 * `money-input.spec.ts` pins the arithmetic; this file pins the wiring
 * that the arithmetic is useless without — that the DOM element really
 * ends up holding the grouped text, that the caret is really written
 * back, that the value really leaves as a number, and that a parent
 * writing to the model mid-keystroke cannot yank the field out from
 * under the user.
 */
import { describe, expect, it } from 'vitest';
import { mount, type VueWrapper } from '@vue/test-utils';
import MoneyInput from './MoneyInput.vue';

function mountMoney(props: Record<string, unknown> = {}) {
  const wrapper = mount(MoneyInput, {
    props,
    attachTo: document.body,
  });
  const el = wrapper.find('input').element as HTMLInputElement;
  return { wrapper, el };
}

/** Simulate a keystroke/paste: the browser mutates the field, then fires `input`. */
async function typeInto(
  wrapper: VueWrapper,
  el: HTMLInputElement,
  raw: string,
  caret = raw.length,
) {
  el.value = raw;
  el.setSelectionRange(caret, caret);
  await wrapper.find('input').trigger('input');
}

function lastEmitted(wrapper: VueWrapper): number | null | undefined {
  const events = wrapper.emitted('update:modelValue');
  if (!events) return undefined;
  return events[events.length - 1][0] as number | null;
}

describe('MoneyInput — element contract', () => {
  it('renders a text input with a numeric keypad hint', () => {
    const { el } = mountMoney();
    // `type="number"` cannot hold "12.000.000" at all, so the separators
    // are only legal on a text input.
    expect(el.type).toBe('text');
    expect(el.getAttribute('inputmode')).toBe('numeric');
  });

  it('passes the caller chrome through to the input', () => {
    const { el } = mountMoney({ class: 'dcform-in', placeholder: '0', id: 'dc-min' });
    expect(el.className).toContain('dcform-in');
    expect(el.placeholder).toBe('0');
    expect(el.id).toBe('dc-min');
  });

  it('renders an incoming model value grouped', () => {
    const { el } = mountMoney({ modelValue: 12000000 });
    expect(el.value).toBe('12.000.000');
  });

  it('renders an empty field for a null model', () => {
    const { el } = mountMoney({ modelValue: null });
    expect(el.value).toBe('');
  });
});

describe('MoneyInput — typing digits progressively', () => {
  it('grows 1 → 12.000.000 in the field while emitting plain numbers', async () => {
    const { wrapper, el } = mountMoney({ modelValue: null });
    const seen: Array<number | null | undefined> = [];

    for (const raw of ['1', '12', '120', '1200', '12000', '120000', '1200000', '12000000']) {
      await typeInto(wrapper, el, raw);
      seen.push(lastEmitted(wrapper));
    }

    expect(el.value).toBe('12.000.000');
    expect(seen).toEqual([1, 12, 120, 1200, 12000, 120000, 1200000, 12000000]);
  });

  it('keeps the caret at the end while appending', async () => {
    const { wrapper, el } = mountMoney();
    await typeInto(wrapper, el, '12000');
    expect(el.value).toBe('12.000');
    expect(el.selectionStart).toBe(el.value.length);
  });
});

describe('MoneyInput — editing mid-string', () => {
  it('does not jump the caret to the end', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000 });
    expect(el.value).toBe('12.000');

    // Caret at "12.0|00", user types 9 → the browser leaves "12.09|00".
    await typeInto(wrapper, el, '12.0900', 5);

    expect(el.value).toBe('120.900');
    expect(el.selectionStart).toBe(5);
    expect(el.value.slice(0, el.selectionStart!)).toBe('120.9');
    expect(lastEmitted(wrapper)).toBe(120900);
  });

  it('holds the caret when a new separator is pushed in to its left', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 999000 });
    // "999|.000" + an 8 → "9998.000" with the caret at 4.
    await typeInto(wrapper, el, '9998.000', 4);

    expect(el.value).toBe('9.998.000');
    // Four digits still sit left of the caret.
    expect(el.value.slice(0, el.selectionStart!).replace(/\D/g, '')).toBe('9998');
  });

  it('rejects a stray non-digit and restores the field text', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 1000 });
    // Typing "." into "1.|000" would leave "1..000" in the DOM; the
    // normalised text is identical to before, so the element has to be
    // rewritten imperatively or the junk stays visible.
    await typeInto(wrapper, el, '1..000', 3);

    expect(el.value).toBe('1.000');
    expect(lastEmitted(wrapper)).toBe(1000);
  });
});

describe('MoneyInput — deleting', () => {
  it('regroups after an ordinary backspace', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 1200000 });
    // "1.200|.000" backspaced → "1.20.000" with the caret at 4.
    await typeInto(wrapper, el, '1.20.000', 4);

    expect(el.value).toBe('120.000');
    expect(lastEmitted(wrapper)).toBe(120000);
  });

  it('backspacing onto a separator removes the digit before it', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000 });
    const input = wrapper.find('input');
    // Caret at "12.|000" — a plain Backspace would delete the dot,
    // regrouping would put it straight back, and nothing would change.
    el.setSelectionRange(3, 3);
    await input.trigger('keydown', { key: 'Backspace' });

    expect(el.value).toBe('1.000');
    expect(lastEmitted(wrapper)).toBe(1000);
    expect(el.selectionStart).toBe(1);
  });

  it('deleting onto a separator removes the digit after it', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000 });
    const input = wrapper.find('input');
    // Caret at "12|.000" — Delete should eat the first zero.
    el.setSelectionRange(2, 2);
    await input.trigger('keydown', { key: 'Delete' });

    expect(el.value).toBe('1.200');
    expect(lastEmitted(wrapper)).toBe(1200);
  });

  it('leaves an ordinary backspace to the browser', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000 });
    const input = wrapper.find('input');
    el.setSelectionRange(2, 2); // "12|.000" — caret follows a digit
    await input.trigger('keydown', { key: 'Backspace' });

    // Untouched: the browser will perform the delete and fire `input`.
    expect(el.value).toBe('12.000');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it('leaves a range-selection delete to the browser', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000 });
    const input = wrapper.find('input');
    el.setSelectionRange(0, 3);
    await input.trigger('keydown', { key: 'Backspace' });

    expect(el.value).toBe('12.000');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });
});

describe('MoneyInput — clearing', () => {
  it('emits null and shows an empty field, not 0 or NaN', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000000 });
    await typeInto(wrapper, el, '', 0);

    expect(el.value).toBe('');
    expect(lastEmitted(wrapper)).toBeNull();
  });

  it('emits null when only separators are left behind', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000000 });
    await typeInto(wrapper, el, '..', 2);

    expect(el.value).toBe('');
    expect(lastEmitted(wrapper)).toBeNull();
  });
});

describe('MoneyInput — pasting', () => {
  it('normalises a pasted "Rp 1.500.000"', async () => {
    const { wrapper, el } = mountMoney();
    await typeInto(wrapper, el, 'Rp 1.500.000');

    expect(el.value).toBe('1.500.000');
    expect(lastEmitted(wrapper)).toBe(1500000);
  });

  it('normalises a pasted bare number', async () => {
    const { wrapper, el } = mountMoney();
    await typeInto(wrapper, el, '12000000');

    expect(el.value).toBe('12.000.000');
    expect(lastEmitted(wrapper)).toBe(12000000);
  });
});

describe('MoneyInput — select-all then retype', () => {
  it('replaces the whole amount', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 12000000 });
    await typeInto(wrapper, el, '7', 1);

    expect(el.value).toBe('7');
    expect(el.selectionStart).toBe(1);
    expect(lastEmitted(wrapper)).toBe(7);
  });
});

describe('MoneyInput — model sync', () => {
  it('re-renders when the model changes while the field is unfocused', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 1000 });
    await wrapper.setProps({ modelValue: 2500000 });

    expect(el.value).toBe('2.500.000');
  });

  it('ignores a model write-back while the user is typing', async () => {
    const { wrapper, el } = mountMoney({ modelValue: null });
    await wrapper.find('input').trigger('focus');
    await typeInto(wrapper, el, '1500', 4);
    expect(el.value).toBe('1.500');

    // A parent that normalises what it receives (a `?? 0` adapter, a
    // clamp) must not be able to reformat the field mid-keystroke.
    await wrapper.setProps({ modelValue: 1500 });
    expect(el.value).toBe('1.500');
    expect(el.selectionStart).toBe(5);
  });

  it('re-canonicalises from the model on blur', async () => {
    const { wrapper, el } = mountMoney({ modelValue: null });
    const input = wrapper.find('input');
    await input.trigger('focus');
    await typeInto(wrapper, el, '0', 1);
    expect(el.value).toBe('0');

    // The parent mapped that 0 back to "no value"; blur re-syncs.
    await wrapper.setProps({ modelValue: null });
    await input.trigger('blur');
    expect(el.value).toBe('');
  });
});

describe('MoneyInput — grouping disabled', () => {
  it('stays digits-only for a percentage-mode field', async () => {
    const { wrapper, el } = mountMoney({ modelValue: null, grouping: false });
    await typeInto(wrapper, el, '100');

    expect(el.value).toBe('100');
    expect(lastEmitted(wrapper)).toBe(100);
  });

  it('regroups when the field flips back to rupiah mode', async () => {
    const { wrapper, el } = mountMoney({ modelValue: 50000, grouping: false });
    expect(el.value).toBe('50000');

    await wrapper.setProps({ grouping: true });
    expect(el.value).toBe('50.000');
  });
});
