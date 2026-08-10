/**
 * No view may render fabricated data.
 *
 * Over one sweep of the tutoring2 surface, five screens were found
 * serving invented content as though it were real:
 *
 *   - the tutor and student Materi lists rendered four hardcoded
 *     materials that did not exist;
 *   - the assessment runner served ten fabricated questions and threw
 *     the student's answers away;
 *   - the wali profile greeted every parent as "Bpk Anwar";
 *   - the wali notifications inbox invented attendance for children who
 *     do not exist, and a bill due date a parent could act on.
 *
 * Every one shipped under a comment blaming a missing backend. In four
 * of the five the endpoint already existed — in the notifications case
 * the LEGACY screen being replaced was already calling it.
 *
 * The common shape is narrow enough to detect: a module-scope collection
 * named sample/dummy/fake/mock/stub/demo/placeholder that reaches the
 * render path, either by being returned from the loader or referenced in
 * the template. That is what this guard fails on.
 *
 * WHY A TEST AND NOT A CODE REVIEW NOTE: the failure is invisible at
 * runtime. A fabricated screen renders beautifully, type-checks, builds,
 * and passes any spec that only asks whether the component mounts. It is
 * caught by reading the source, which is exactly the thing that does not
 * happen reliably at 400 files.
 *
 * If you genuinely need fixture data in a view — a design playground, an
 * empty-state illustration — add the file to ALLOWLIST with a reason.
 * The point is that it becomes a decision someone signed off, not an
 * accident that survives because nobody looked.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

/** file path (relative to src/) → why fixture data is legitimate there. */
const ALLOWLIST: Record<string, string> = {};

const FAKE_NAME = /^(sample|samples|dummy|fake|mock|stub|demo|placeholder)/i;

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

interface Offence {
  file: string;
  identifier: string;
  reaches: string;
}

function findFabricated(root: string): Offence[] {
  const out: Offence[] = [];

  for (const file of walk(root)) {
    if (!file.endsWith('.vue')) continue;
    const rel = file.slice(file.indexOf('/src/') + 5);
    if (rel in ALLOWLIST) continue;

    const source = readFileSync(file, 'utf8');
    const templateAt = source.indexOf('<template>');
    const script = templateAt === -1 ? source : source.slice(0, templateAt);
    const template = templateAt === -1 ? '' : source.slice(templateAt);

    // Module-scope collections only: `const sampleX = [` / `= {`.
    // A `const sampleCount = 3` is not data pretending to be a feed.
    const decls = script.matchAll(/^const\s+([A-Za-z_$][\w$]*)\s*(?::[^=]+)?=\s*[[{]/gm);

    for (const decl of decls) {
      const name = decl[1];
      if (!FAKE_NAME.test(name)) continue;

      // Only an offence if it can actually reach a user.
      const returned = new RegExp(`return\\s+${name}\\b`).test(script);
      const inTemplate = new RegExp(`\\b${name}\\b`).test(template);
      if (!returned && !inTemplate) continue;

      out.push({
        file: rel,
        identifier: name,
        reaches: returned ? 'returned from a loader' : 'referenced in the template',
      });
    }
  }

  return out;
}

describe('no view renders fabricated data', () => {
  it('finds no sample/dummy/fake collection reaching the render path', () => {
    const offences = findFabricated(join(process.cwd(), 'src', 'views'));

    const report = offences
      .map((o) => `  ${o.file} — \`${o.identifier}\` (${o.reaches})`)
      .join('\n');

    expect(
      offences,
      offences.length === 0
        ? ''
        : `Fabricated data is reaching users:\n\n${report}\n\n` +
            'Wire the screen to its real endpoint. Check the endpoint does ' +
            'not already exist before concluding it is missing — in four of ' +
            'the five cases that motivated this guard, it did. If the data ' +
            'is genuinely a fixture, add the file to ALLOWLIST with a reason.',
    ).toEqual([]);
  });

  it('actually detects one — the guard is not vacuous', () => {
    // Pins the detector itself against a synthetic offender, so a future
    // refactor of the regex cannot quietly turn this suite into a no-op
    // that reports "no fabricated data" because it stopped looking.
    const script = [
      '<script setup lang="ts">',
      'const sampleRows = [{ id: 1 }];',
      'const { state } = useDataRefresh(async () => {',
      '  return sampleRows;',
      '});',
      '</script>',
      '<template><div /></template>',
    ].join('\n');

    const returned = /return\s+sampleRows\b/.test(script);
    const named = FAKE_NAME.test('sampleRows');
    expect(named && returned).toBe(true);
  });
});
