/**
 * Gibberish detector for free-text fields (nama sekolah, kota, jabatan,
 * nama lengkap, dll). Tuned to catch obvious keyboard mashing
 * ("asdasd", "qweasdz", "zxczxc") while staying tolerant of
 * legitimate Indonesian short words and abbreviations.
 *
 * NOT a spam classifier — we only block input that has zero chance
 * of being a real proper noun. Borderline cases pass.
 */

/**
 * Why a string was rejected. Mapped to user-facing copy in the shell.
 */
export type GibberishReason =
  | 'repeat_run'        // aaaaa, bbb, !!!
  | 'keyboard_row'      // qwert, asdfg, zxcvb
  | 'consonant_cluster' // 4+ consonants in a row with no vowel
  | 'no_vowel'          // length ≥ 4, no a/i/u/e/o
  | 'too_short'         // length < 2 after trim
  | 'symbols_only';     // every char is non-alpha

export interface GibberishVerdict {
  ok: boolean;
  reason?: GibberishReason;
}

// Common QWERTY row substrings (case-folded). 4+ char windows are
// extracted via sliding-window over each row + reverse.
const KEYBOARD_ROWS = [
  'qwertyuiop',
  'asdfghjkl',
  'zxcvbnm',
  // Common diagonal mashers and number row.
  'qazwsxedc',
  'qweasdzxc',
  '1234567890',
];

/** Pre-compute the 4-, 5-, and 6-char substrings of each row. */
const KEYBOARD_FRAGMENTS: ReadonlySet<string> = (() => {
  const set = new Set<string>();
  for (const row of KEYBOARD_ROWS) {
    for (const r of [row, row.split('').reverse().join('')]) {
      for (let len = 4; len <= Math.min(6, r.length); len++) {
        for (let i = 0; i + len <= r.length; i++) {
          set.add(r.substring(i, i + len));
        }
      }
    }
  }
  return set;
})();

const VOWELS_RE = /[aiueoAIUEO]/;
const ALPHA_RE = /[a-zA-Z]/;

/**
 * Heuristic check. Returns `{ ok: true }` for plausible human text,
 * `{ ok: false, reason }` otherwise.
 *
 * Skips empty input entirely — required-field validation is the
 * caller's job; this only judges shape.
 */
export function detectGibberish(input: string): GibberishVerdict {
  const trimmed = (input ?? '').trim();
  if (trimmed.length === 0) return { ok: true };
  if (trimmed.length < 2) return { ok: false, reason: 'too_short' };

  // Strip spaces & punctuation for the alpha-shape checks. Names
  // routinely include "."/"," ("Cahaya Prestasi Bimbel, Cab. 1").
  const compact = trimmed.replace(/[\s.,'/\-()&]+/g, '');
  if (compact.length === 0) return { ok: false, reason: 'symbols_only' };

  // Rule 1: 4+ same character in a row anywhere = mashing.
  // "aaaa", "wwww", "----" all match. Real names rarely have it.
  if (/(.)\1{3,}/.test(compact)) {
    return { ok: false, reason: 'repeat_run' };
  }

  // Rule 1b: same 3- or 4-char substring repeated back-to-back =
  // mashing. Catches "asdasd", "qweqwe", "abcabcabc". Real words
  // don't repeat trigrams adjacent to themselves.
  const compactLower = compact.toLowerCase();
  if (/(.{3,4})\1/.test(compactLower)) {
    return { ok: false, reason: 'repeat_run' };
  }

  // Rule 2: any 4-char substring matches a known QWERTY fragment.
  // Catches "qwer", "asdf", "zxcv", "qweasd", "asdzxc", etc.
  if (compactLower.length >= 4) {
    for (let i = 0; i + 4 <= compactLower.length; i++) {
      const win = compactLower.substring(i, i + 4);
      if (KEYBOARD_FRAGMENTS.has(win)) {
        return { ok: false, reason: 'keyboard_row' };
      }
    }
  }

  // Word-level checks. Indonesian school names mix acronyms (SMP,
  // PGRI, MTs) with real words ("Negeri 1 Bandung"). Applying
  // consonant/vowel rules to the whole string fires on those
  // acronyms. Split on whitespace + separators and only flag a
  // single WORD when it shows mashing shape.
  const words = trimmed
    .toLowerCase()
    .split(/[\s.,'/\-()&_]+/)
    .filter((w) => w.length >= 4);

  for (const word of words) {
    const alpha = word.replace(/[^a-z]/g, '');
    if (alpha.length < 4) continue;

    // Rule 3: 6+ consonants in a row inside one word. Tightened
    // from 5+ because acronyms like "SMKPGRI" (now lowercased) are
    // legitimate and clock in at 6 consonants once joined. Real
    // single words rarely string 6 consonants without a vowel —
    // "qwrtypsdf" matches, "bcdfgh" matches.
    if (/[bcdfghjklmnpqrstvwxyz]{6,}/.test(alpha)) {
      return { ok: false, reason: 'consonant_cluster' };
    }

    // Rule 4: a 4+ char word with ZERO vowels is mashing.
    // "qwrt" → fail; "bng" (3 chars) → skip.
    if (alpha.length >= 4 && !/[aiueo]/.test(alpha)) {
      return { ok: false, reason: 'no_vowel' };
    }
  }

  // Rule 5: no alpha at all in something that should be a name/word.
  // Catches "12345" / "??????" passed as nama sekolah.
  if (!ALPHA_RE.test(compact)) {
    return { ok: false, reason: 'symbols_only' };
  }

  return { ok: true };
}

const REASON_COPY: Record<GibberishReason, string> = {
  repeat_run: 'Sepertinya ada ketikan berulang. Coba isi nama yang sebenarnya.',
  keyboard_row: 'Sepertinya ketikan keyboard acak. Mohon isi data yang valid.',
  consonant_cluster: 'Susunan huruf tidak alami. Pastikan ketikan benar.',
  no_vowel: 'Tidak ada vokal. Pastikan ketikan benar.',
  too_short: 'Terlalu pendek. Minimal 2 karakter.',
  symbols_only: 'Mohon isi dengan huruf — angka/simbol saja tidak cukup.',
};

export function gibberishMessage(verdict: GibberishVerdict): string | null {
  if (verdict.ok || !verdict.reason) return null;
  return REASON_COPY[verdict.reason] ?? 'Mohon periksa ulang isian.';
}

/**
 * Sanity-check for the WhatsApp / phone field. Beyond the simple
 * regex on the validator: a real Indonesian phone has at least 9
 * digits after stripping `+` / spaces / dashes, and can't be a
 * single digit repeated (e.g. "111111111").
 */
export interface PhoneVerdict {
  ok: boolean;
  reason?: 'too_short' | 'all_same' | 'sequential';
}

export function detectBadPhone(input: string): PhoneVerdict {
  const digits = (input ?? '').replace(/\D/g, '');
  if (digits.length === 0) return { ok: true };
  if (digits.length < 9) return { ok: false, reason: 'too_short' };
  // All same digit ("0000000000", "1111111111").
  if (/^(\d)\1+$/.test(digits)) return { ok: false, reason: 'all_same' };
  // Strictly ascending / descending consecutive digits — `1234567890`,
  // `9876543210`, `0123456789`. Check pairwise so any length matches
  // (substring approach missed "1234567890" because '0' wraps).
  if (digits.length >= 8) {
    let asc = true;
    let desc = true;
    for (let i = 1; i < digits.length; i++) {
      const prev = +digits[i - 1];
      const cur = +digits[i];
      if (cur !== (prev + 1) % 10) asc = false;
      if (cur !== (prev + 9) % 10) desc = false;
      if (!asc && !desc) break;
    }
    if (asc || desc) return { ok: false, reason: 'sequential' };
  }
  return { ok: true };
}

export function phoneMessage(verdict: PhoneVerdict): string | null {
  if (verdict.ok || !verdict.reason) return null;
  switch (verdict.reason) {
    case 'too_short':
      return 'Nomor terlalu pendek. Minimal 9 digit.';
    case 'all_same':
      return 'Nomor sepertinya tidak valid (semua digit sama).';
    case 'sequential':
      return 'Nomor sepertinya berurutan otomatis (12345…). Mohon nomor yang benar.';
  }
  return null;
}
