/**
 * No caller may hand-copy FormField's control chrome into its own
 * default slot.
 *
 * FormField exists to own ONE copy of the labeled-control unit: the
 * `block text-sm font-medium text-slate-700 mb-1` label, the
 * `w-full rounded-xl border border-slate-300 …` control, the
 * `text-xs text-status-danger mt-1` error line. Its own file says so —
 * "any tweak to the input look had to be made in dozens of places" is
 * the problem it was extracted to end.
 *
 * The escape hatch it offers (the default slot, for autocompletes,
 * toggles, chip grids) is legitimate and stays. What is NOT legitimate
 * is reaching for that hatch and then pasting FormField's OWN control
 * class string onto the control you supply: the label and error chrome
 * come from the component while the input chrome is a copy that has to
 * be found and edited by hand. Three date fields had done exactly
 * that, each carrying a byte-identical copy of `CONTROL_BASE`, purely
 * because `type` had no `'date'` member at the time. It does now, so
 * all three collapse to `<FormField type="date">`.
 *
 * WHY A TEST: the failure mode is silence. A hand-copied control looks
 * right, type-checks, and renders pixel-identically — right up until
 * someone changes CONTROL_BASE and three fields quietly keep the old
 * look. Nothing at runtime ever reports that.
 *
 * ── WHAT THIS DOES NOT CATCH, DELIBERATELY ──
 *
 * It matches the EXACT `CONTROL_BASE` string, so a near-copy walks
 * straight past it. Two live ones do, and both are correct as they
 * stand: MonthPickerField's trigger button and the leads sheet's
 * student-picker trigger are `<button>`s opening a modal, not inputs —
 * they borrow the look on purpose and FormField cannot express either.
 * Widening this to a fuzzy match would flag both and the guard would
 * be switched off, which is worse than a narrow rule that is always
 * right. Treat a green run as "nobody pasted the chrome verbatim",
 * never as "no duplication exists".
 *
 * Also out of scope by construction: files that do not use FormField
 * at all. Four of them (HelpRequestModal, TeacherMaterialView,
 * TeacherAnnouncementView, TeacherGradeMatrixView) carry 12 copies of
 * this same class string between them in fully hand-rolled forms. That
 * is a real cleanup, but it is a migration onto FormField rather than
 * a misuse OF it, so failing it here would block unrelated work.
 */
import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const SRC = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/**
 * Read the constant out of FormField itself rather than restating it.
 * A guard holding its own copy of the string it polices would be the
 * very duplication it exists to forbid — and would go quietly vacuous
 * the day CONTROL_BASE is edited.
 */
function controlBase(): string {
  const src = readFileSync(join(SRC, 'components/ui/FormField.vue'), 'utf8');
  const m = src.match(/const CONTROL_BASE\s*=\s*\n?\s*'([^']+)'/);
  if (!m) {
    throw new Error(
      'CONTROL_BASE not found in FormField.vue — this guard has gone blind; fix the matcher.',
    );
  }
  return m[1];
}

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

interface Offence {
  file: string;
  line: number;
}

/**
 * Every `<FormField …> … </FormField>` body, minus named `<template #…>`
 * slots (a rich `#label` is not a control and is a supported use), that
 * contains the CONTROL_BASE string verbatim.
 */
function findChromeCopies(): Offence[] {
  const base = controlBase();
  const out: Offence[] = [];

  for (const file of walk(SRC)) {
    if (!file.endsWith('.vue')) continue;
    const src = readFileSync(file, 'utf8');
    if (!src.includes('<FormField')) continue;

    for (const m of src.matchAll(/<FormField\b/g)) {
      const openStart = m.index as number;
      const openEnd = src.indexOf('>', openStart);
      if (openEnd === -1) continue;
      if (src[openEnd - 1] === '/') continue; // self-closing: no slot
      const close = src.indexOf('</FormField>', openEnd);
      if (close === -1) continue;

      const body = src.slice(openEnd + 1, close);
      const defaultSlot = body.replace(
        /<template\s+#[^>]*>[\s\S]*?<\/template>/g,
        '',
      );
      if (defaultSlot.includes(base)) {
        out.push({
          file: relative(SRC, file),
          line: src.slice(0, openStart).split('\n').length,
        });
      }
    }
  }
  return out;
}

describe('FormField control chrome is not hand-copied by callers', () => {
  it('finds the CONTROL_BASE constant it polices', () => {
    // Anti-vacuity: if the matcher above ever stops finding the
    // constant it throws, and every other assertion here would be
    // comparing against nothing.
    expect(controlBase()).toContain('rounded-xl');
    expect(controlBase()).toContain('focus:border-brand');
  });

  it('no FormField default slot pastes FormField’s own control classes', () => {
    const offences = findChromeCopies();
    expect(
      offences,
      offences
        .map(
          (o) =>
            `${o.file}:${o.line} — supplies its own control but copies ` +
            'FormField’s CONTROL_BASE. If FormField can express this ' +
            'control (type="date" among them), use the prop; if it ' +
            'genuinely cannot, give the control its own classes.',
        )
        .join('\n'),
    ).toEqual([]);
  });

  it('still scans a meaningful number of FormField hosts', () => {
    // Guards against the walk silently matching nothing — an empty
    // sweep would make the assertion above pass forever.
    const hosts = walk(SRC).filter(
      (f) => f.endsWith('.vue') && readFileSync(f, 'utf8').includes('<FormField'),
    );
    expect(hosts.length).toBeGreaterThan(10);
  });
});
