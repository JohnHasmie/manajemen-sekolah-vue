/**
 * Every message in `id.json` and `en.json` must survive the vue-i18n
 * message compiler.
 *
 * ── The incident ──
 *
 * Four placeholder strings shipped with a bare `@` in them —
 * `"wali@contoh.com"`, `"nama@sekolah.id"`, `"nama@email.com"`,
 * `"tutor@contoh.id"`. In vue-i18n a `@` in a message VALUE is the
 * linked-message operator, so those strings are not text, they are
 * malformed syntax.
 *
 * `src/lib/i18n.ts` hands the raw JSON to `createI18n`, and this repo
 * has no `@intlify/unplugin-vue-i18n`, so every message is compiled
 * lazily IN THE BROWSER on first render. A malformed message therefore
 * fails at RENDER TIME, not at build time, and in a production bundle
 * `@intlify/core-base` re-throws that failure instead of recovering
 * (`core-base.mjs`, `getCompileContext`: it `console.error`s when
 * `NODE_ENV !== 'production'` and `throw`s otherwise).
 *
 * A throw inside render aborts the whole component. Users did not get a
 * field-level error — they got a form that vanished, and a button that
 * looked dead because the modal it opened died mid-render. The console
 * signature was `Object.ee [as nextToken]` + `SyntaxError: 10`;
 * `CompileErrorCodes.INVALID_LINKED_FORMAT` is 10.
 *
 * None of the three CI gates can see this. `vue-tsc` and `vite build`
 * both just inline the JSON, and no spec mounted the affected
 * components. That is exactly why it reached production, and why the
 * guard has to compile the strings itself.
 *
 * ── What is legal after an `@`, and why ──
 *
 * Read off the tokenizer in `@intlify/message-compiler`
 * (`readTokenInLinked`). Once a `@` is consumed the token type is
 * `LinkedAlias`, and from there ONLY these continue:
 *
 *   `@:key`             LinkedDelimiter then a key
 *   `@:{key}`           …the key may be braced (identifier start required)
 *   `@.modifier:key`    LinkedDot, an identifier modifier, then the above
 *   `@.modifier:{key}`
 *
 * A space or newline straight after `@` is rejected before the switch is
 * even reached, so `"foo @ bar"` is malformed too. Anything else falls
 * to the `default:` arm, which raises INVALID_LINKED_FORMAT (10).
 *
 * ── The literal escape, and the trap it sets ──
 *
 * The repo already uses the correct escape in three places:
 * `auth.emailPlaceholder` is `anda{'@'}sekolah.id`, and both
 * `registerDemo` social placeholders are `{'@'}username`.
 *
 * That escape CONTAINS an `@`. A naive rule — "flag any `@` not followed
 * by `:` or `.`" — flags the escape itself, i.e. it goes red on the very
 * fix this guard exists to protect, and on all three strings that were
 * already correct. A guard that fires on correct code is worse than no
 * guard: the next person deletes it.
 *
 * The escape is safe because `{` routes into `readTokenInPlaceholder`,
 * `isLiteralStart` sees the `'`, and `readLiteral` then swallows every
 * character except an unescaped `'` or a newline (`isLiteral`). The `@`
 * is emitted as an ordinary Literal token and `readTokenInLinked` is
 * never entered at all.
 *
 * This file sidesteps the whole problem by not writing a rule. It runs
 * the SAME compiler the browser runs, so the accepted set is correct by
 * construction rather than by a regex someone has to keep in sync.
 *
 * ── What this does NOT catch ──
 *
 * Only things the compiler reports as ERRORS. vue-i18n has two failure
 * modes that emit nothing at all and would pass here:
 *
 *   - an unterminated `{` silently truncates the message;
 *   - a `|` silently splits it into plural branches.
 *
 * Neither occurs in either file today. It also does not catch a
 * *well-formed* link to a key that does not exist (`"@:no.such.key"`
 * compiles fine and renders empty) — that is a different defect class
 * and deserves its own guard if it ever bites.
 */
import { describe, expect, it } from 'vitest';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { baseCompile } from '@intlify/message-compiler';

const LOCALE_FILES = ['id', 'en'] as const;

/**
 * `@intlify/message-compiler` is a TRANSITIVE dependency (vue-i18n →
 * @intlify/core-base → here), deliberately not added to package.json.
 *
 * Declaring it would let its version drift away from the one vue-i18n
 * actually uses, and then this guard would be validating the strings
 * against a compiler the app never runs — green here, broken in the
 * browser. Leaving it undeclared means npm can only ever hoist the one
 * copy that core-base itself resolves. `compilerVersionsAgree` below
 * turns that assumption into an assertion.
 */
function packageVersion(name: string): string {
  const require = createRequire(import.meta.url);
  return JSON.parse(
    readFileSync(require.resolve(`${name}/package.json`), 'utf8'),
  ).version as string;
}

/** Flattened `["a.b.c", "value"]` pairs for every string leaf. */
function leaves(node: unknown, path: string[] = []): [string, string][] {
  if (typeof node === 'string') return [[path.join('.'), node]];
  if (Array.isArray(node)) {
    return node.flatMap((child, i) => leaves(child, [...path, String(i)]));
  }
  if (node !== null && typeof node === 'object') {
    return Object.entries(node as Record<string, unknown>).flatMap(([k, v]) =>
      leaves(v, [...path, k]),
    );
  }
  return [];
}

function readLocale(locale: string): [string, string][] {
  const file = join(process.cwd(), 'src', 'locales', `${locale}.json`);
  return leaves(JSON.parse(readFileSync(file, 'utf8')));
}

/**
 * Compile one message the way the browser does and return the error
 * codes raised. Empty array === the message is safe to render.
 *
 * `onError` is NOT optional here. The tokenizer's `emitError` is guarded
 * by `if (onError)`, so a call without one silently swallows every
 * error and reports success for a message that will crash in
 * production. `jit: true` + `location: true` mirror what
 * `@intlify/core-base`'s `compile()` passes in a dev/test build.
 */
function compileErrorCodes(message: string): number[] {
  const codes: number[] = [];
  baseCompile(message, {
    jit: true,
    location: true,
    onError: (err) => {
      codes.push(err.code);
    },
  });
  return codes;
}

describe('locale messages compile', () => {
  it.each([...LOCALE_FILES])('%s.json — every message survives the compiler', (locale) => {
    const offences = readLocale(locale)
      .map(([key, value]) => ({ key, value, codes: compileErrorCodes(value) }))
      .filter((o) => o.codes.length > 0);

    const report = offences
      .map((o) => `  ${o.key}\n    ${JSON.stringify(o.value)}  (codes ${o.codes.join(', ')})`)
      .join('\n');

    expect(
      offences.map((o) => o.key),
      offences.length === 0
        ? ''
        : `${locale}.json holds ${offences.length} message(s) that will THROW ` +
            `while rendering in a production build:\n\n${report}\n\n` +
            "Code 10 is a bare '@'. vue-i18n reads it as the linked-message " +
            "operator; write it as {'@'} — the visible text is unchanged. " +
            'Copy `auth.emailPlaceholder`, which already does this. Do NOT ' +
            'delete the key and do NOT reword the placeholder: the user sees ' +
            'the same string either way, this only changes how it is parsed. ' +
            'Fix the SAME key in the other locale file too — the two must ' +
            'stay at exact parity.',
    ).toEqual([]);
  });

  it('actually detects one — the guard is not vacuous', () => {
    // Pins the detector against the exact defect that motivated this
    // file, so a future refactor cannot quietly turn the sweep above
    // into a no-op that reports "all clear" because it stopped looking.
    // In particular: dropping `onError` from compileErrorCodes makes
    // every case below return [] and this test is what notices.
    for (const broken of [
      'wali@contoh.com', // the shipped defect
      'nama@sekolah.id',
      'a@b',
      '@', // trailing operator, nothing after it
      'foo @ bar', // space after @ — rejected before the switch
      'foo @: bar', // delimiter with no key
      '@.mod', // modifier with no delimiter/key
    ]) {
      expect(compileErrorCodes(broken), `expected ${JSON.stringify(broken)} to fail`).not.toEqual(
        [],
      );
    }
    // …and specifically as INVALID_LINKED_FORMAT, the code in the crash
    // report users hit ("SyntaxError: 10").
    expect(compileErrorCodes('wali@contoh.com')).toContain(10);
  });

  it('does NOT flag the escape or any legal linked syntax — the guard is not a false alarm', () => {
    // The other half, and the more dangerous one. `{'@'}` contains an
    // `@`, so a hand-rolled "no bare @" rule condemns the fix itself and
    // every string in this repo that was already correct. If this test
    // ever goes red, the guard has started rejecting valid messages and
    // must be fixed, NOT deleted.
    for (const legal of [
      "wali{'@'}contoh.com", // the fix
      "anda{'@'}sekolah.id", // shipped in auth.emailPlaceholder
      "{'@'}username Instagram", // shipped in registerDemo
      "{ '@' }", // spaces inside the placeholder are allowed
      "{'wali@contoh.com'}", // the whole string as one literal
      '@:auth.title', // plain link
      '@:{someKey}', // braced link key
      '@.lower:auth.title', // modifier + link
      '@.upper:{someKey}',
      "Lihat @:auth.title, kirim ke {'@'}admin", // both in one message
    ]) {
      expect(compileErrorCodes(legal), `expected ${JSON.stringify(legal)} to compile`).toEqual([]);
    }
  });

  it.each([...LOCALE_FILES])(
    '%s.json — the three strings that were already escaped stay clean',
    (locale) => {
      // Named explicitly rather than left to the sweep, because these are
      // exactly the strings a careless guard would condemn. They predate
      // the bug and are the pattern the fix copied.
      const byKey = new Map(readLocale(locale));
      for (const key of [
        'auth.emailPlaceholder',
        'registerDemo.requesterSocialInstagramPlaceholder',
        'registerDemo.requesterSocialThreadsPlaceholder',
      ]) {
        const value = byKey.get(key);
        expect(value, `${locale}.json is missing ${key}`).toBeDefined();
        expect(value, `${locale}: ${key} lost its {'@'} escape`).toContain("{'@'}");
        expect(compileErrorCodes(value!), `${locale}: ${key}`).toEqual([]);
      }
    },
  );

  it('id.json and en.json stay at exact key parity', () => {
    // Free to assert here and nothing else in the repo does it. The fix
    // that motivated this file touched four keys in BOTH files; a fifth
    // touched in only one would be invisible until a user switched
    // language.
    const [id, en] = LOCALE_FILES.map((l) => new Set(readLocale(l).map(([k]) => k)));
    const onlyId = [...id].filter((k) => !en.has(k));
    const onlyEn = [...en].filter((k) => !id.has(k));

    expect(onlyId, `keys present in id.json but missing from en.json:\n  ${onlyId.join('\n  ')}`)
      .toEqual([]);
    expect(onlyEn, `keys present in en.json but missing from id.json:\n  ${onlyEn.join('\n  ')}`)
      .toEqual([]);
  });

  it('compiles against the SAME compiler version vue-i18n runs', () => {
    // See packageVersion above. If npm ever hoists a message-compiler
    // that differs from the one @intlify/core-base resolves, this file
    // would be validating the locale data against a compiler the app
    // never loads. Fail loudly instead of passing dishonestly.
    expect(packageVersion('@intlify/message-compiler')).toBe(
      packageVersion('@intlify/core-base'),
    );
  });
});
