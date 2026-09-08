/**
 * Money-input engine — the pure, DOM-free half of `<MoneyInput>`.
 *
 * WHAT THIS SOLVES
 * A rupiah field has to show grouped digits WHILE the user types
 * (`12000000` → `12.000.000`) without ever letting those separators leak
 * into the model. Every naive attempt at this breaks in one of four
 * ways, so each is pinned by a test in `money-input.spec.ts`:
 *
 *   1. The caret jumps to the end whenever the text is reformatted, so
 *      you cannot fix a typo in the middle of the number.
 *   2. Backspacing onto a separator appears to do nothing — you delete
 *      the `.`, regrouping puts it straight back, and the field looks
 *      frozen.
 *   3. Clearing the field yields `0` or `NaN` instead of "no value".
 *   4. The separators reach the API because the display string and the
 *      model are the same value.
 *
 * THE CARET RULE
 * Separator positions shift as digits are added or removed, so a caret
 * expressed as a character offset is meaningless across a reformat.
 * What IS stable is the number of DIGITS to the left of the caret: that
 * count is unchanged by regrouping. So every pass counts the digits
 * before the caret in the raw text, reformats, and then walks the new
 * text to the offset that sits just after that many digits.
 *
 * DECIMALS ARE REJECTED, DELIBERATELY
 * Rupiah has no circulating sub-unit and every amount field these inputs
 * feed is an integer server-side (`integer|min:1` and friends). So the
 * scanner keeps digits and nothing else: `.` and `,` are dropped rather
 * than treated as a decimal point, which also means a pasted
 * `"Rp 1.500.000"` normalises to `1500000` instead of becoming `1.5`.
 * Minus signs go the same way — none of these fields accept a negative.
 */
import { formatThousands } from './format';

/**
 * Largest number of digits accepted. 15 keeps the parsed value inside
 * `Number.MAX_SAFE_INTEGER` (9,007,199,254,740,991 — 16 digits), so a
 * pasted wall of digits can never silently lose precision.
 */
export const MONEY_MAX_DIGITS = 15;

export interface MoneyInputState {
  /** Text the input should display. Empty string when there is no value. */
  text: string;
  /**
   * The model value. `null` — never `0`, never `NaN` — when the field is
   * empty, so "cleared" stays distinguishable from "zero".
   */
  value: number | null;
  /** Caret offset within `text`. */
  caret: number;
}

export interface MoneyInputOptions {
  /**
   * Render thousand separators. Pass `false` for a field that shares its
   * markup with a non-money mode (a voucher that can be either a
   * percentage or a rupiah amount): the digits-only behaviour is kept,
   * the grouping is not.
   */
  grouping?: boolean;
  /** Override {@link MONEY_MAX_DIGITS}. */
  maxDigits?: number;
}

function isDigit(char: string | undefined): boolean {
  return char !== undefined && char >= '0' && char <= '9';
}

/** Every digit in `raw`, in order, with everything else discarded. */
export function digitsOnly(raw: unknown): string {
  if (raw === null || raw === undefined) return '';
  return String(raw).replace(/[^0-9]/g, '');
}

/**
 * Offset in `text` immediately after its `n`-th digit (`n` counted from
 * 1). `0` maps to the start; an `n` past the end maps to the end.
 */
export function caretAfterDigits(text: string, n: number): number {
  if (n <= 0) return 0;
  let seen = 0;
  for (let i = 0; i < text.length; i += 1) {
    if (isDigit(text[i])) {
      seen += 1;
      if (seen === n) return i + 1;
    }
  }
  return text.length;
}

/**
 * Re-derive display text, model value and caret from whatever the input
 * element currently holds.
 *
 * `raw` is the post-edit contents of the field (so it may contain any
 * character the user typed or pasted) and `caret` is the offset within
 * it. Both come straight off the DOM element; nothing here touches the
 * DOM itself, which is what makes the behaviour unit-testable.
 */
export function normalizeMoneyInput(
  raw: string,
  caret: number = raw.length,
  options: MoneyInputOptions = {},
): MoneyInputState {
  const grouping = options.grouping !== false;
  const maxDigits = options.maxDigits ?? MONEY_MAX_DIGITS;

  const safeCaret = Math.max(0, Math.min(caret, raw.length));
  const rawDigits = digitsOnly(raw);
  let digitsBefore = digitsOnly(raw.slice(0, safeCaret)).length;

  // Drop leading zeros so `007` reads as `7`, but keep a lone `0` — the
  // user may be part-way through typing and deserves to see the keypress
  // land. Each zero removed from the left of the caret shifts the caret
  // one digit left with it.
  let lead = 0;
  while (lead < rawDigits.length - 1 && rawDigits[lead] === '0') lead += 1;
  let digits = rawDigits.slice(lead);
  digitsBefore = Math.max(0, digitsBefore - lead);

  // Truncate from the right: the leading digits are the ones the user
  // most likely meant, and this keeps the value inside safe-integer range.
  if (digits.length > maxDigits) {
    digits = digits.slice(0, maxDigits);
    digitsBefore = Math.min(digitsBefore, maxDigits);
  }

  if (digits === '') return { text: '', value: null, caret: 0 };

  const text = grouping ? formatThousands(digits) : digits;
  return { text, value: Number(digits), caret: caretAfterDigits(text, digitsBefore) };
}

/**
 * Display text for a model value arriving from OUTSIDE the input —
 * initial render, a server load, a "use my whole balance" shortcut.
 *
 * `null`/`undefined`/`''` render as an empty field. Anything else is
 * truncated to a whole, non-negative rupiah amount, because that is the
 * only shape this input can round-trip.
 */
export function formatMoneyValue(
  value: number | string | null | undefined,
  grouping = true,
): string {
  if (value === null || value === undefined || value === '') return '';
  const n = typeof value === 'number' ? value : Number(digitsOnly(value));
  if (!Number.isFinite(n)) return '';
  const digits = String(Math.trunc(Math.abs(n)));
  return grouping ? formatThousands(digits) : digits;
}

/**
 * Text + caret produced by a Backspace pressed with the caret directly
 * AFTER a separator, e.g. `12.|000` — see failure mode 2 above.
 *
 * Plain Backspace would delete the `.`, regrouping would immediately
 * reinstate it, and the field would look stuck. What the user means is
 * "remove the digit this separator is standing in front of", so that is
 * what gets removed; the separator is re-derived by the regrouping pass.
 * Returns `null` when the default browser behaviour is already correct.
 */
export function backspaceAcrossSeparator(
  text: string,
  caret: number,
): { raw: string; caret: number } | null {
  if (caret < 2 || caret > text.length) return null;
  if (isDigit(text[caret - 1])) return null;
  return { raw: text.slice(0, caret - 2) + text.slice(caret - 1), caret: caret - 2 };
}

/**
 * The Delete-key mirror of {@link backspaceAcrossSeparator}: with the
 * caret directly BEFORE a separator (`12|.000`) the user means "remove
 * the digit on the far side of it", and the caret stays put.
 */
export function deleteAcrossSeparator(
  text: string,
  caret: number,
): { raw: string; caret: number } | null {
  if (caret < 0 || caret > text.length - 2) return null;
  if (isDigit(text[caret])) return null;
  return { raw: text.slice(0, caret) + text.slice(caret + 2), caret };
}
