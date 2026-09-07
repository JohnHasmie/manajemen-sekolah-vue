/**
 * "Kembali" must be able to reach an auto-filled question.
 *
 * Reported 2026-09-07: "Setelah memilih jenjang, kemudian kembali lagi
 * untuk menyesuaikan jenjang, pemilihan jenjang tdk tampil."
 *
 * Cause: `back()` walked the list with the same `skipIf` filter that
 * `next()` uses. Picking a school from the NPSN registry on Q1 fills
 * npsn + education_level + city, which turns those questions' `skipIf`
 * true — so Kembali stepped straight over them and the jenjang could
 * never be corrected. Skipping is about not ASKING twice; it must not
 * decide where the user may return to.
 *
 * SCOPE, stated honestly: the navigation lives inside the SFC, so this
 * does not mount the component. What it does lock is the part that made
 * the bug possible and would make it possible again —
 *   (a) that these skipIf predicates really do go true on a registry-hit
 *       payload (so a skipIf-filtered walk WOULD skip them), and
 *   (b) that no skipIf is structural, i.e. skipping is only ever "already
 *       answered", so ignoring it when going back is safe.
 * The SFC change itself still needs a click-through to confirm.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect } from 'vitest';
import { questionsFor } from './questions';

/** A payload as it looks right after picking an NPSN registry hit on Q1. */
const registryHitPayload = () => ({
  tenant_type: 'school',
  school: {
    name: 'SD Negeri Contoh',
    npsn: '20219999',
    education_level: 'ELEMENTARY',
    city: 'Bandung',
  },
  subjects: { names: [] },
  classes: { pattern: 'small' },
  tutoring: {},
});

/** Same user, but they typed the school by hand — no registry hit. */
const manualPayload = () => ({
  tenant_type: 'school',
  school: { name: 'SD Negeri Contoh', npsn: '', education_level: '', city: '' },
  subjects: { names: [] },
  classes: { pattern: 'small' },
  tutoring: {},
});

const school = () => questionsFor('school');

describe('back-navigation must not be gated by skipIf', () => {
  it('the jenjang question really is skipIf-true after a registry hit', () => {
    // If this ever goes false the bug cannot recur — and this test would
    // be quietly testing nothing, so assert the precondition explicitly.
    const q = school().find((x) => x.key === 'school.education_level');
    expect(q, 'school.education_level question missing').toBeTruthy();
    expect(q.skipIf?.(registryHitPayload())).toBe(true);
  });

  it('and is NOT skipped when the user typed the school by hand', () => {
    const q = school().find((x) => x.key === 'school.education_level');
    expect(q.skipIf?.(manualPayload())).toBeFalsy();
  });

  it('a skipIf-filtered backward walk would step OVER it — the old behaviour', () => {
    const qs = school();
    const p = registryHitPayload();
    const jenjang = qs.findIndex((x) => x.key === 'school.education_level');
    // Reproduce the old back(): walk backwards honouring skipIf.
    let i = jenjang;
    while (i >= 0 && qs[i].skipIf?.(p)) i -= 1;
    expect(i).not.toBe(jenjang); // it skipped past the question
  });

  it('a plain step-back lands ON it, which is what the fix does', () => {
    const qs = school();
    const jenjang = qs.findIndex((x) => x.key === 'school.education_level');
    expect(qs[(jenjang + 1) - 1].key).toBe('school.education_level');
  });

  it('no skipIf is structural — every one is an "already answered" test', () => {
    // The school/tutoring split is done by questionsFor() returning two
    // separate lists, so a backward step can never land on a question
    // from the other path. That is what makes ignoring skipIf safe; if
    // someone adds a path-gating skipIf, this test should make them stop
    // and reconsider back().
    const blank = manualPayload();
    for (const q of school()) {
      if (!q.skipIf) continue;
      expect(
        q.skipIf(blank),
        `"${q.key}" is skipped even on an EMPTY payload — that is structural, `
          + 'not "already answered", and back() would step over it forever',
      ).toBeFalsy();
    }
  });

  it('the tutoring list is genuinely a different list, not a filtered one', () => {
    const schoolKeys = school().map((q) => q.key);
    const tutoringKeys = questionsFor('tutoring').map((q) => q.key);
    expect(tutoringKeys).not.toEqual(schoolKeys);
    expect(schoolKeys).toContain('school.education_level');
    expect(tutoringKeys).not.toContain('school.education_level');
  });
});
