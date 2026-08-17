/**
 * Vitest spec for AdminTutoring2LeaderboardView (WEB-14).
 *
 * Part 1 pins the row/podium contract (pure logic, no mount).
 *
 * Part 2 pins the FILTER TOOLBAR, which shipped half-dead:
 *
 *   • the scope chip CYCLED — `@click="pickNextScope()"` advanced one
 *     entry per click through the group/program list by modulo. Fine at
 *     3 groups; at 30 there is no way to reach the one you want.
 *   • the Penilaian chip was INERT — `@click="assessmentId = ''"` only
 *     ever reset to the default, no list of assessments was loaded
 *     anywhere in the file, so nothing could ever SET it. Its value
 *     rendered `truncateId(assessmentId)` — a raw uuid fragment for a
 *     state that was unreachable.
 *
 * Every test below fails against that old template:
 *
 *   1. opens a picker      — clicking a chip must OPEN an option list
 *                            instead of mutating the filter itself.
 *   2. lists ALL options   — not just "the next one".
 *   3. titles, not UUIDs   — the Penilaian chip must read a NAME.
 *   4. apply re-queries    — picking must reach the leaderboard query.
 *   5. scoped assessments  — the Penilaian list must be narrowed to the
 *                            selected group/program, and re-fetched when
 *                            that scope changes.
 *   6. empty ⇒ disabled    — a list that came back empty must disable
 *                            its own chip, not leave a dead control.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body and would escape the wrapper);
 * the option rows clicked here are the ones an admin clicks.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import type { DefineComponent } from 'vue';
import AdminTutoring2LeaderboardView from './AdminTutoring2LeaderboardView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listPrograms: vi.fn(),
    listAssessments: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/leaderboard', () => ({
  TutoringLeaderboardService: {
    getGroup: vi.fn(),
    getProgram: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

describe('AdminTutoring2LeaderboardView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2LeaderboardView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts LeaderboardRow rows keyed by enrollment_id (greenfield anchor)', () => {
    // Load-bearing: rows FK to bimbel_enrollments, NOT student_classes.
    const row: LeaderboardRow = {
      enrollment_id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
      student_id: '019f8090-4d6a-71ab-bf01-c98a6ac73294',
      student_name: 'Anaya Putri',
      student_number: 'BM-2026-001',
      avg_score: 92.5,
      assessments_taken: 4,
      rank: 1,
    };
    expect(row.enrollment_id).toMatch(/^[0-9a-f-]+$/);
    expect(row.rank).toBe(1);
  });

  it('partitions rank 1..3 into podium and 4..N into the tail table', () => {
    const rows: LeaderboardRow[] = Array.from({ length: 6 }, (_, i) => ({
      enrollment_id: `e${i + 1}`,
      student_id: `s${i + 1}`,
      student_name: `Siswa ${i + 1}`,
      student_number: null,
      avg_score: 100 - i * 5,
      assessments_taken: 3,
      rank: i + 1,
    }));
    const podium = rows.filter((r) => r.rank <= 3);
    const tail = rows.filter((r) => r.rank > 3);
    expect(podium.map((r) => r.rank)).toEqual([1, 2, 3]);
    expect(tail.map((r) => r.rank)).toEqual([4, 5, 6]);
  });

  it('streak column stays hidden when no row carries a positive streak', () => {
    const noStreakRows: LeaderboardRow[] = [
      {
        enrollment_id: 'e1',
        student_id: 's1',
        student_name: 'A',
        avg_score: 90,
        assessments_taken: 2,
        rank: 1,
      },
      {
        enrollment_id: 'e2',
        student_id: 's2',
        student_name: 'B',
        avg_score: 80,
        assessments_taken: 2,
        rank: 2,
        streak_days: 0,
      },
    ];
    const anyStreak = noStreakRows.some(
      (r) => typeof r.streak_days === 'number' && r.streak_days! > 0,
    );
    expect(anyStreak).toBe(false);

    const withStreak: LeaderboardRow[] = [
      { ...noStreakRows[0], streak_days: 5 },
    ];
    const anyStreak2 = withStreak.some(
      (r) => typeof r.streak_days === 'number' && r.streak_days! > 0,
    );
    expect(anyStreak2).toBe(true);
  });
});

// ─── Filter toolbar ────────────────────────────────────────────────

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-1', name: 'UTBK Sore B', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-3', program_id: 'pr-2', name: 'SMP Reguler', kind: 'group', capacity: 20, status: 'active' },
];
const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Reguler SMP', grade_level: '8', status: 'active' },
];

/** Every published assessment on program pr-1 — one program-wide, one
 *  per group. The group tab must keep the first two and drop the third. */
const ASSESSMENTS = [
  { id: 'as-1', program_id: 'pr-1', learning_group_id: null, title: 'Tryout Nasional 1', kind: 'tryout', kind_label: 'Try-out', assessment_date: '2026-08-01', max_score: 100, published_at: '2026-08-02' },
  { id: 'as-2', program_id: 'pr-1', learning_group_id: 'gr-1', title: 'Latihan Pagi A', kind: 'latihan', kind_label: 'Latihan', assessment_date: '2026-08-05', max_score: 100, published_at: '2026-08-06' },
  { id: 'as-3', program_id: 'pr-1', learning_group_id: 'gr-2', title: 'Latihan Sore B', kind: 'latihan', kind_label: 'Latihan', assessment_date: '2026-08-07', max_score: 100, published_at: '2026-08-08' },
];

const ROWS = [
  { enrollment_id: 'en-1', student_id: 'st-1', student_name: 'Anaya Putri', student_number: 'BM-001', avg_score: 92.5, assessments_taken: 4, rank: 1 },
  { enrollment_id: 'en-2', student_id: 'st-2', student_name: 'Budi Santoso', student_number: 'BM-002', avg_score: 81, assessments_taken: 4, rank: 2 },
];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: {
            all: 'Semua',
            group: 'Kelompok',
            program: 'Program',
            filterNoOptions: 'Belum ada pilihan untuk filter ini',
            notAvailable: 'Belum tersedia',
          },
          admin: {
            leaderboard: {
              assessmentLabel: 'Penilaian',
              tabLabel: 'Tampilan',
              tabGroup: 'Per Kelompok',
              tabProgram: 'Per Program',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2LeaderboardView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        // Mirrors the real chip's contract: renders `value`, honours
        // `disabled`, emits `click`. Keeping `value` in the DOM is what
        // lets the "titles, not UUIDs" assertions read the chip.
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active', 'disabled'],
          emits: ['click'],
          template:
            '<button data-testid="chip" :disabled="disabled" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async" :data-status="state?.status"><slot /></div>',
        },
        // FilterFacetPickerModal is NOT stubbed — only the Modal shell it
        // renders into, because Modal teleports to body.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Chips render in template order: tab, scope, assessment. */
const CHIP = { tab: 0, scope: 1, assessment: 2 };

function chips(w) {
  return w.findAll('[data-testid="chip"]');
}
function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}
function lastCallOf(fn) {
  const { calls } = fn.mock;
  return calls[calls.length - 1];
}
/** The `{ assessment_id, limit }` query the board was last asked for. */
function lastBoardQuery(fn = TutoringLeaderboardService.getGroup) {
  return lastCallOf(fn)[1];
}

describe('AdminTutoring2LeaderboardView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items: ASSESSMENTS });
    (TutoringLeaderboardService.getGroup as any).mockResolvedValue({ items: ROWS });
    (TutoringLeaderboardService.getProgram as any).mockResolvedValue({ items: ROWS });
  });

  it('loads the scope lists and the scoped assessment list on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listGroups).toHaveBeenCalled();
    expect(TutoringBimbelService.listPrograms).toHaveBeenCalled();
    // The Penilaian chip had NO option list at all before this change.
    expect(TutoringBimbelService.listAssessments).toHaveBeenCalled();
  });

  it('chips read names and the Penilaian chip defaults to "Semua"', async () => {
    const w = await mountView();
    const c = chips(w);

    expect(c).toHaveLength(3);
    expect(c[CHIP.scope].text()).toBe('UTBK Pagi A');
    expect(c[CHIP.assessment].text()).toBe('Semua');
    expect(c[CHIP.scope].attributes('disabled')).toBeUndefined();
    expect(c[CHIP.assessment].attributes('disabled')).toBeUndefined();
  });

  it('the scope chip OPENS a picker of every group instead of cycling', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    const before = (TutoringLeaderboardService.getGroup as any).mock.calls.length;
    await chips(w)[CHIP.scope].trigger('click');
    await flushPromises();

    // The regression: the old handler advanced groupId by one and
    // re-queried the board. A picker must open and change NOTHING yet.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    expect((TutoringLeaderboardService.getGroup as any).mock.calls.length).toBe(before);

    const labels = optionRows(w).map((b) => b.text());
    expect(labels.join(' ')).toContain('UTBK Pagi A');
    expect(labels.join(' ')).toContain('UTBK Sore B');
    expect(labels.join(' ')).toContain('SMP Reguler');
  });

  it('the scope picker offers no "Semua" row — a scope is required', async () => {
    const w = await mountView();
    await chips(w)[CHIP.scope].trigger('click');

    // One row per group and nothing else: without a group/program there
    // is no board at all, so the reset row that the Penilaian picker has
    // would only ever blank the page.
    const labels = optionRows(w).map((b) => b.text());
    expect(labels).toHaveLength(GROUPS.length);
    expect(labels).not.toContain('Semua');
  });

  it('picking a group from the picker queries THAT group and shows its name', async () => {
    const w = await mountView();
    await chips(w)[CHIP.scope].trigger('click');
    // Rows are the three groups in order — no reset row on this picker.
    await optionRows(w)[1].trigger('click');
    await flushPromises();

    expect(lastCallOf(TutoringLeaderboardService.getGroup as any)[0]).toBe('gr-2');
    expect(chips(w)[CHIP.scope].text()).toBe('UTBK Sore B');
  });

  it('the Penilaian chip opens a picker of assessment TITLES, never uuids', async () => {
    const w = await mountView();
    await chips(w)[CHIP.assessment].trigger('click');

    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua'); // all-published reset
    expect(labels.join(' ')).toContain('Tryout Nasional 1');
    expect(labels.join(' ')).toContain('Latihan Pagi A');
    expect(labels.join(' ')).not.toContain('as-1');
  });

  it('picking an assessment narrows the board by assessment_id', async () => {
    const w = await mountView();
    await chips(w)[CHIP.assessment].trigger('click');
    // Row 0 is the "Semua" reset; row 1 is the first assessment.
    await optionRows(w)[1].trigger('click');
    await flushPromises();

    expect(lastBoardQuery().assessment_id).toBe('as-1');
    // The chip must read the TITLE — the old template printed a uuid
    // fragment here for a state nothing could even reach.
    const chip = chips(w)[CHIP.assessment];
    expect(chip.text()).toBe('Tryout Nasional 1');
    expect(chip.text()).not.toContain('as-1');
  });

  it('the "Semua" row restores the all-published default', async () => {
    const w = await mountView();

    await chips(w)[CHIP.assessment].trigger('click');
    await optionRows(w)[1].trigger('click');
    await flushPromises();
    expect(lastBoardQuery().assessment_id).toBe('as-1');

    await chips(w)[CHIP.assessment].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    // '' must reach the service as *absent*, not as an empty string.
    expect(lastBoardQuery().assessment_id).toBeUndefined();
    expect(chips(w)[CHIP.assessment].text()).toBe('Semua');
  });

  it('scopes the assessment list to the selected group, not the whole tenant', async () => {
    const w = await mountView();

    // Asked for the GROUP'S PROGRAM: a program-wide assessment is scored
    // for this group's students too, so filtering on learning_group_id
    // alone would silently drop it.
    expect(lastCallOf(TutoringBimbelService.listAssessments as any)[0]).toMatchObject({
      published: true,
      program_id: 'pr-1',
    });

    await chips(w)[CHIP.assessment].trigger('click');
    const labels = optionRows(w).map((b) => b.text()).join(' ');
    expect(labels).toContain('Tryout Nasional 1'); // program-wide → kept
    expect(labels).toContain('Latihan Pagi A'); // this group → kept
    expect(labels).not.toContain('Latihan Sore B'); // sibling group → dropped
  });

  it('the program tab scopes assessments by program and keeps sibling rows', async () => {
    const w = await mountView();
    await chips(w)[CHIP.tab].trigger('click'); // → Per Program
    await flushPromises();

    expect(lastCallOf(TutoringBimbelService.listAssessments as any)[0]).toMatchObject({
      published: true,
      program_id: 'pr-1',
    });
    expect(TutoringLeaderboardService.getProgram).toHaveBeenCalled();

    // Per program there is no group to narrow against, so every
    // published assessment on the program is a legitimate pick.
    await chips(w)[CHIP.assessment].trigger('click');
    expect(optionRows(w).map((b) => b.text()).join(' ')).toContain('Latihan Sore B');
  });

  it('changing scope re-fetches the assessments and drops the stale pick', async () => {
    const w = await mountView();

    await chips(w)[CHIP.assessment].trigger('click');
    await optionRows(w)[2].trigger('click'); // "Latihan Pagi A" (gr-1 only)
    await flushPromises();
    expect(lastBoardQuery().assessment_id).toBe('as-2');

    const before = (TutoringBimbelService.listAssessments as any).mock.calls.length;
    await chips(w)[CHIP.scope].trigger('click');
    await optionRows(w)[1].trigger('click'); // → gr-2
    await flushPromises();

    // An assessment belongs to ONE scope; carried over it would filter
    // the new board down to nothing under an active-looking chip.
    expect(lastBoardQuery().assessment_id).toBeUndefined();
    expect(chips(w)[CHIP.assessment].text()).toBe('Semua');
    expect((TutoringBimbelService.listAssessments as any).mock.calls.length)
      .toBeGreaterThan(before);
  });

  it('an empty assessment list disables the Penilaian chip only', async () => {
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const c = chips(w);

    expect(c[CHIP.assessment].attributes('disabled')).toBeDefined();
    // The scope chip must stay usable — one empty list must not take the
    // whole toolbar down with it.
    expect(c[CHIP.scope].attributes('disabled')).toBeUndefined();
  });

  it('a failing assessments endpoint disables its chip without breaking the board', async () => {
    (TutoringBimbelService.listAssessments as any).mockRejectedValue(new Error('403'));

    const w = await mountView();

    expect(chips(w)[CHIP.assessment].attributes('disabled')).toBeDefined();
    expect(chips(w)[CHIP.scope].text()).toBe('UTBK Pagi A');
    expect(w.find('[data-testid="async"]').attributes('data-status')).not.toBe('error');
  });

  it('a failing program list does not blank the group chip or error the page', async () => {
    // Pre-fix this ran through Promise.all inside the loader, so one
    // rejected scope endpoint threw the whole view into its error state
    // and neither chip had any options.
    (TutoringBimbelService.listPrograms as any).mockRejectedValue(new Error('403'));

    const w = await mountView();

    expect(chips(w)[CHIP.scope].text()).toBe('UTBK Pagi A');
    expect(chips(w)[CHIP.scope].attributes('disabled')).toBeUndefined();
    expect(w.find('[data-testid="async"]').attributes('data-status')).not.toBe('error');
  });
});
