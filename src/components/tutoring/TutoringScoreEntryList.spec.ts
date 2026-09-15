/**
 * TutoringScoreEntryList — the edit affordance on the tutor input-skor
 * screen.
 *
 * ── What this file replaced ─────────────────────────────────────────
 *
 * Four `it`s that imported the SFC only to assert it was truthy and
 * otherwise declared typed object literals and asserted on their own
 * fields. Nothing mounted, so it would have stayed green through any
 * change to the template — including deleting it. These tests render
 * the component and read the DOM.
 *
 * ── The clock is pinned, and so is the zone ─────────────────────────
 *
 * `vi.setSystemTime` fixes "now"; `vitest.config.ts` fixes TZ to
 * Asia/Jakarta. Both matter: the fixture's `marked_at` carries a
 * `+07:00` offset, so a component that formatted it through
 * `toISOString()` would render "07.30" where a local-time render says
 * "14.30". The UTC form is asserted against explicitly rather than left
 * to chance — a bare `toContain('2026')` would pass either way.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import ScoreEntryList from './TutoringScoreEntryList.vue';

const ID = JSON.parse(
  readFileSync(join(process.cwd(), 'src', 'locales', 'id.json'), 'utf8'),
);

/** 09 Sep 2026, 14:30 WIB. In UTC the same instant is 07:30. */
const MARKED_AT = '2026-09-09T14:30:00+07:00';
const LOCAL_RENDER = '9 Sep 2026, 14.30';
const UTC_RENDER = '9 Sep 2026, 07.30';

/** Scored on the server: has a mark AND the stamp that says when. */
const SCORED = {
  enrollment_id: 'en-scored',
  student_id: 'st-1',
  student_name: 'Nadia Putri',
  student_number: '2026-001',
  score: 80,
  notes: null,
  marked_at: MARKED_AT,
};

/** Never scored: no mark, and therefore no stamp. */
const UNSCORED = {
  enrollment_id: 'en-blank',
  student_id: 'st-2',
  student_name: 'Salsa Lestari',
  student_number: '2026-002',
  score: null,
  notes: null,
  marked_at: null,
};

function mountList(rows = [SCORED, UNSCORED], props = {}) {
  return mount(ScoreEntryList, {
    props: {
      assessmentId: 'as-1',
      rows: rows.map((r) => ({ ...r })),
      maxScore: 100,
      kkm: 75,
      ...props,
    },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: ID },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
    },
  });
}

const at = (w, id) => w.find(`[data-testid="${id}"]`);
const saveBtn = (w) => w.find('[data-testid="score-save"]');
const isDisabled = (w) => saveBtn(w).attributes('disabled') !== undefined;

/** Type into a row's box the way a tutor would. */
async function type(w, enrollmentId, value) {
  const box = at(w, `score-input-${enrollmentId}`);
  box.element.value = value;
  await box.trigger('input');
}

beforeAll(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-09-15T09:00:00+07:00'));
});
afterAll(() => {
  vi.useRealTimers();
});
beforeEach(() => {
  vi.clearAllMocks();
});

describe('TutoringScoreEntryList — scored marker', () => {
  it('marks a row that already has a score, and says when it was last changed', () => {
    const w = mountList();
    expect(at(w, 'score-marked-en-scored').exists()).toBe(true);
    expect(at(w, 'score-badge-en-scored').text()).toBe(
      ID.tutoring2.scoreEntry.scoredBadge,
    );
    expect(at(w, 'score-time-en-scored').text()).toContain(LOCAL_RENDER);
  });

  it('renders the stamp in LOCAL time, not UTC', () => {
    // The whole point of the field. `marked_at` is `+07:00`; a
    // `toISOString()` render would print the 07.30 instant instead.
    const w = mountList();
    const shown = at(w, 'score-time-en-scored').text();
    expect(shown).toContain(LOCAL_RENDER);
    expect(shown).not.toContain(UTC_RENDER);
  });

  it('marks neither on a row nobody has scored', () => {
    const w = mountList();
    expect(at(w, 'score-marked-en-blank').exists()).toBe(false);
    expect(at(w, 'score-badge-en-blank').exists()).toBe(false);
    expect(at(w, 'score-time-en-blank').exists()).toBe(false);
  });

  it('does not claim "sudah dinilai" the moment a tutor starts typing', async () => {
    // The badge reports SERVER state. Keying it off the live input
    // would make an unsaved keystroke look like a stored mark.
    const w = mountList();
    await type(w, 'en-blank', '65');
    expect(at(w, 'score-marked-en-blank').exists()).toBe(false);
  });

  it('keeps the previous stamp visible while an edit is pending', async () => {
    // "Terakhir diubah" stays true until the save lands — the warning
    // ring is what says the box is ahead of the server.
    const w = mountList();
    await type(w, 'en-scored', '95');
    expect(at(w, 'score-time-en-scored').text()).toContain(LOCAL_RENDER);
  });

  it('omits the time but keeps the badge when the server sent no stamp', () => {
    // Nullable in the schema. A scored row with no stamp still gets the
    // badge; it just cannot say when.
    const w = mountList([{ ...SCORED, marked_at: null }]);
    expect(at(w, 'score-badge-en-scored').exists()).toBe(true);
    expect(at(w, 'score-time-en-scored').exists()).toBe(false);
  });
});

describe('TutoringScoreEntryList — Save is gated on a real change', () => {
  it('is disabled on load', () => {
    const w = mountList();
    expect(isDisabled(w)).toBe(true);
    expect(at(w, 'score-clean-label').text()).toBe(
      ID.tutoring2.scoreEntry.noChanges,
    );
  });

  it('enables once a value actually differs from the loaded one', async () => {
    const w = mountList();
    await type(w, 'en-scored', '95');
    expect(isDisabled(w)).toBe(false);
    expect(at(w, 'score-dirty-label').text()).toContain('1');
  });

  it('stays disabled when the same value is retyped over itself', async () => {
    // 80 over a saved 80 is not a change, however many input events it
    // took to produce.
    const w = mountList();
    await type(w, 'en-scored', '80');
    expect(isDisabled(w)).toBe(true);
  });

  it('disables again when an edit is taken back to the original', async () => {
    const w = mountList();
    await type(w, 'en-scored', '81');
    expect(isDisabled(w)).toBe(false);
    await type(w, 'en-scored', '80');
    expect(isDisabled(w)).toBe(true);
    expect(at(w, 'score-clean-label').exists()).toBe(true);
  });

  it('counts clearing a saved score as a change, and restoring it as none', async () => {
    const w = mountList();
    await type(w, 'en-scored', '');
    expect(isDisabled(w)).toBe(false);
    await type(w, 'en-scored', '80');
    expect(isDisabled(w)).toBe(true);
  });

  it('ignores an out-of-range keystroke entirely', async () => {
    const w = mountList();
    await type(w, 'en-scored', '140');
    expect(isDisabled(w)).toBe(true);
  });

  it('is disabled while a save is in flight even with pending edits', async () => {
    const w = mountList();
    await type(w, 'en-scored', '95');
    await w.setProps({ saving: true });
    expect(isDisabled(w)).toBe(true);
  });

  it('emits ONLY the changed rows', async () => {
    const w = mountList();
    await type(w, 'en-blank', '70');
    await saveBtn(w).trigger('click');
    const emitted = w.emitted('saveDirty');
    expect(emitted).toHaveLength(1);
    const sent = emitted[0][0];
    expect(sent.map((r) => r.enrollment_id)).toEqual(['en-blank']);
    expect(sent[0].score).toBe(70);
  });

  it('emits nothing when there is nothing to save', async () => {
    const w = mountList();
    await saveBtn(w).trigger('click');
    expect(w.emitted('saveDirty')).toBeUndefined();
  });

  it('re-baselines on the reloaded rows, so a saved edit is no longer pending', async () => {
    // What the parent does after a successful POST: hand over the
    // server's rows. The draft resets and Save goes quiet again.
    const w = mountList();
    await type(w, 'en-scored', '95');
    expect(isDisabled(w)).toBe(false);
    await w.setProps({
      rows: [
        { ...SCORED, score: 95, marked_at: '2026-09-15T09:00:00+07:00' },
        { ...UNSCORED },
      ],
    });
    expect(isDisabled(w)).toBe(true);
    expect(at(w, 'score-time-en-scored').text()).toContain('15 Sep 2026, 09.00');
  });
});

describe('TutoringScoreEntryList — editing stays unrestricted', () => {
  it('leaves an already-scored input editable — no lock, no Edit button', () => {
    const w = mountList();
    expect(at(w, 'score-input-en-scored').attributes('disabled')).toBeUndefined();
    expect(at(w, 'score-input-en-scored').attributes('readonly')).toBeUndefined();
  });
});
