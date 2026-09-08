/**
 * Contract spec for the money-input engine.
 *
 * Every case here is one of the ways a "just add dots as they type"
 * field goes wrong in production: the caret snapping to the end after
 * each keystroke, a Backspace that appears to do nothing, a pasted
 * `Rp 1.500.000` landing as `1.5`, a cleared field posting `0`, and
 * separators reaching the API. The engine is deliberately DOM-free so
 * all of that is assertable without mounting anything.
 *
 * `|` in the case names marks the caret.
 */
import { describe, expect, it } from 'vitest';
import {
  MONEY_MAX_DIGITS,
  backspaceAcrossSeparator,
  caretAfterDigits,
  deleteAcrossSeparator,
  digitsOnly,
  formatMoneyValue,
  normalizeMoneyInput,
} from './money-input';

describe('digitsOnly', () => {
  it('keeps digits and drops everything else', () => {
    expect(digitsOnly('Rp 12.000.000,-')).toBe('12000000');
    expect(digitsOnly('')).toBe('');
    expect(digitsOnly(null)).toBe('');
    expect(digitsOnly(undefined)).toBe('');
  });
});

describe('normalizeMoneyInput — typing digits progressively', () => {
  // The exact sequence from the request: 12000000 must become 12.000.000.
  const steps: Array<[string, string, number]> = [
    ['1', '1', 1],
    ['12', '12', 12],
    ['120', '120', 120],
    ['1200', '1.200', 1200],
    ['12000', '12.000', 12000],
    ['120000', '120.000', 120000],
    ['1200000', '1.200.000', 1200000],
    ['12000000', '12.000.000', 12000000],
  ];

  it.each(steps)('typing %s renders %s and models %i', (typed, text, value) => {
    const state = normalizeMoneyInput(typed);
    expect(state.text).toBe(text);
    expect(state.value).toBe(value);
  });

  it('leaves the caret at the end while appending', () => {
    // After typing the 8th digit the browser hands us "12.00000|0"
    // (7 separators-worth of old text plus the new char); the caret must
    // land after the 8th digit of the regrouped "12.000.000".
    const state = normalizeMoneyInput('12.0000000', 10);
    expect(state.text).toBe('120.000.000');
    expect(state.caret).toBe(state.text.length);
  });

  it('emits a clean integer, never a separated string', () => {
    const state = normalizeMoneyInput('12.000.000');
    expect(state.value).toBe(12000000);
    expect(typeof state.value).toBe('number');
  });
});

describe('normalizeMoneyInput — caret while editing mid-string', () => {
  it('keeps the caret against the digit just typed, not at the end', () => {
    // "12.0|00" with a 9 typed at the caret => raw "12.09|00".
    const state = normalizeMoneyInput('12.0900', 5);
    expect(state.text).toBe('120.900');
    // Four digits sit left of the caret (1,2,0,9) — offset 5 in "120.900".
    expect(state.caret).toBe(5);
    expect(state.text.slice(0, state.caret)).toBe('120.9');
  });

  it('keeps the caret at the front when typing at position 0', () => {
    // "|1.000" with a 2 typed => raw "21.000", caret 1.
    const state = normalizeMoneyInput('21.000', 1);
    expect(state.text).toBe('21.000');
    expect(state.caret).toBe(1);
  });

  it('re-anchors the caret when a new separator is inserted to its left', () => {
    // "999|.000" grows to four leading digits, pushing a separator in.
    const state = normalizeMoneyInput('9998.000', 4);
    expect(state.text).toBe('9.998.000');
    // Still four digits to the left — now offset 5, past the new dot.
    expect(digitsOnly(state.text.slice(0, state.caret)).length).toBe(4);
  });

  it('never returns a caret outside the text', () => {
    const state = normalizeMoneyInput('12000', 9999);
    expect(state.caret).toBeLessThanOrEqual(state.text.length);
    expect(state.caret).toBeGreaterThanOrEqual(0);
  });
});

describe('normalizeMoneyInput — deleting', () => {
  it('regroups after a digit is removed', () => {
    // "1.200|.000" backspaced => raw "1.20.000".
    const state = normalizeMoneyInput('1.20.000', 5);
    expect(state.text).toBe('120.000');
    expect(state.value).toBe(120000);
    expect(digitsOnly(state.text.slice(0, state.caret)).length).toBe(3);
  });

  it('drops to an ungrouped number once under four digits', () => {
    const state = normalizeMoneyInput('.200', 4);
    expect(state.text).toBe('200');
    expect(state.value).toBe(200);
  });
});

describe('normalizeMoneyInput — clearing', () => {
  it('models null (not 0, not NaN) for an emptied field', () => {
    const state = normalizeMoneyInput('');
    expect(state.value).toBeNull();
    expect(state.text).toBe('');
    expect(state.caret).toBe(0);
  });

  it('models null when only separators survive a delete', () => {
    expect(normalizeMoneyInput('...').value).toBeNull();
    expect(normalizeMoneyInput('...').text).toBe('');
  });

  it('never yields NaN for junk input', () => {
    const state = normalizeMoneyInput('abc');
    expect(state.value).toBeNull();
    expect(Number.isNaN(state.value as unknown as number)).toBe(false);
  });
});

describe('normalizeMoneyInput — pasting', () => {
  it('accepts a pasted already-formatted rupiah string', () => {
    const state = normalizeMoneyInput('Rp 1.500.000', 12);
    expect(state.text).toBe('1.500.000');
    expect(state.value).toBe(1500000);
  });

  it('accepts a pasted bare number', () => {
    expect(normalizeMoneyInput('12000000').value).toBe(12000000);
  });

  it('accepts a pasted English-grouped string', () => {
    // A value copied out of a spreadsheet set to en-US.
    expect(normalizeMoneyInput('12,000,000').value).toBe(12000000);
  });

  it('strips a decimal tail rather than reading it as a fraction', () => {
    // Rupiah carries no sub-unit here; "1.500.000,50" must not become 1.5.
    const state = normalizeMoneyInput('1500000.50');
    expect(state.value).toBe(150000050);
    expect(state.text).toBe('150.000.050');
  });

  it('strips a leading minus — none of these fields take a negative', () => {
    expect(normalizeMoneyInput('-5000').value).toBe(5000);
  });

  it('truncates a paste past the safe-integer digit cap', () => {
    const state = normalizeMoneyInput('9'.repeat(40));
    expect(digitsOnly(state.text)).toHaveLength(MONEY_MAX_DIGITS);
    expect(Number.isSafeInteger(state.value as number)).toBe(true);
  });
});

describe('normalizeMoneyInput — select-all and retype', () => {
  it('replaces the whole value in one pass', () => {
    // Select-all then type "7": the browser hands us just "7".
    const state = normalizeMoneyInput('7', 1);
    expect(state.text).toBe('7');
    expect(state.value).toBe(7);
    expect(state.caret).toBe(1);
  });
});

describe('normalizeMoneyInput — leading zeros', () => {
  it('keeps a lone zero so the keypress is visible', () => {
    const state = normalizeMoneyInput('0');
    expect(state.text).toBe('0');
    expect(state.value).toBe(0);
  });

  it('drops leading zeros once a real digit arrives', () => {
    const state = normalizeMoneyInput('007');
    expect(state.text).toBe('7');
    expect(state.value).toBe(7);
  });

  it('shifts the caret left by each zero it removed', () => {
    // "00|7" — two digits left of the caret, both about to disappear.
    const state = normalizeMoneyInput('007', 2);
    expect(state.text).toBe('7');
    expect(state.caret).toBe(0);
  });
});

describe('normalizeMoneyInput — grouping disabled', () => {
  it('stays digits-only for a percentage-mode field', () => {
    const state = normalizeMoneyInput('100', 3, { grouping: false });
    expect(state.text).toBe('100');
    expect(state.value).toBe(100);
  });

  it('does not group a four-digit value', () => {
    expect(normalizeMoneyInput('1200', 4, { grouping: false }).text).toBe('1200');
  });
});

describe('caretAfterDigits', () => {
  it('maps a digit count to an offset past any separators', () => {
    expect(caretAfterDigits('12.000.000', 0)).toBe(0);
    expect(caretAfterDigits('12.000.000', 2)).toBe(2);
    expect(caretAfterDigits('12.000.000', 3)).toBe(4);
    expect(caretAfterDigits('12.000.000', 8)).toBe(10);
  });

  it('clamps a count past the end to the end', () => {
    expect(caretAfterDigits('1.000', 99)).toBe(5);
  });
});

describe('backspaceAcrossSeparator', () => {
  it('removes the digit in front of the separator, not the separator', () => {
    // "12.|000" — Backspace should delete the 2, leaving 1.000.
    const edit = backspaceAcrossSeparator('12.000', 3);
    expect(edit).not.toBeNull();
    const state = normalizeMoneyInput(edit!.raw, edit!.caret);
    expect(state.text).toBe('1.000');
    expect(state.caret).toBe(1);
  });

  it('defers to the browser when the caret follows a digit', () => {
    expect(backspaceAcrossSeparator('12.000', 2)).toBeNull();
  });

  it('defers to the browser at the start of the field', () => {
    expect(backspaceAcrossSeparator('12.000', 0)).toBeNull();
    expect(backspaceAcrossSeparator('12.000', 1)).toBeNull();
  });
});

describe('deleteAcrossSeparator', () => {
  it('removes the digit beyond the separator and holds the caret', () => {
    // "12|.000" — Delete should remove the first 0, leaving 1.200.
    const edit = deleteAcrossSeparator('12.000', 2);
    expect(edit).not.toBeNull();
    const state = normalizeMoneyInput(edit!.raw, edit!.caret);
    expect(state.text).toBe('1.200');
    expect(digitsOnly(state.text.slice(0, state.caret)).length).toBe(2);
  });

  it('defers to the browser when the next char is a digit', () => {
    expect(deleteAcrossSeparator('12.000', 0)).toBeNull();
  });

  it('defers to the browser at the end of the field', () => {
    expect(deleteAcrossSeparator('12.000', 6)).toBeNull();
  });
});

describe('formatMoneyValue', () => {
  it('renders an externally supplied amount', () => {
    expect(formatMoneyValue(12000000)).toBe('12.000.000');
    expect(formatMoneyValue(500)).toBe('500');
  });

  it('renders an empty field for a null/undefined/empty model', () => {
    expect(formatMoneyValue(null)).toBe('');
    expect(formatMoneyValue(undefined)).toBe('');
    expect(formatMoneyValue('')).toBe('');
  });

  it('renders a zero model as "0"', () => {
    expect(formatMoneyValue(0)).toBe('0');
  });

  it('truncates a fractional model rather than showing a comma tail', () => {
    expect(formatMoneyValue(1500.75)).toBe('1.500');
  });

  it('drops the sign on a negative model', () => {
    expect(formatMoneyValue(-2500)).toBe('2.500');
  });

  it('skips grouping when asked', () => {
    expect(formatMoneyValue(12000000, false)).toBe('12000000');
  });

  it('returns an empty string for a non-finite model', () => {
    expect(formatMoneyValue(Number.NaN)).toBe('');
    expect(formatMoneyValue(Number.POSITIVE_INFINITY)).toBe('');
  });
});
