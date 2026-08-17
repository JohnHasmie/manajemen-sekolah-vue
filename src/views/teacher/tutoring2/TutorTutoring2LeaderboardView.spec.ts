/**
 * Vitest spec for TutorTutoring2LeaderboardView.
 *
 * Part 1 pins the row/podium contract (pure logic, no mount) — the same
 * anchors the admin twin's spec pins, because both views render the SAME
 * LeaderboardRow shape.
 *
 * Part 2 pins the scope chip, which shipped as a CYCLER:
 * `@click="pickNextScope()"` advanced one entry per click through the
 * kelompok/program list by modulo. Tolerable for a tutor with 3
 * kelompok; for a tutor with 30 the 27th needs 27 clicks, and every one
 * of them re-fires the leaderboard endpoint on the way past.
 *
 * These mount-based tests all fail against the pre-fix template:
 *
 *   1. opens a picker      — clicking the chip must OPEN an option list
 *                            instead of mutating the filter itself.
 *   2. lists ALL options   — not just "the next one".
 *   3. apply re-queries    — picking must reach the leaderboard query.
 *   4. no "Semua" row      — a scope is required; without one there is
 *                            no board to show.
 *   5. program tab         — the picker follows the active tab.
 *   6. empty ⇒ disabled    — an empty list must disable its own chip
 *                            rather than leave a dead control.
 *   7. one dead endpoint   — the old `Promise.all` inside the loader let
 *                            a single rejected scope endpoint throw the
 *                            WHOLE page into its error state.
 *
 * The real <FilterFacetPickerModal> is mounted; only its <Modal> shell is
 * stubbed, because Modal teleports to body and would escape the wrapper.
 * The option rows clicked below are the ones a tutor clicks.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import type { DefineComponent } from 'vue';
import TutorTutoring2LeaderboardView from './TutorTutoring2LeaderboardView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listPrograms: vi.fn(),
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

describe('TutorTutoring2LeaderboardView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent =
      TutorTutoring2LeaderboardView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts LeaderboardRow rows keyed by enrollment_id (greenfield anchor)', () => {
    // Load-bearing: v2 rows FK to bimbel_enrollments, NOT student_classes.
    // v1's tutor leaderboard keyed by student_id.
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
    expect(rows.filter((r) => r.rank <= 3).map((r) => r.rank)).toEqual([1, 2, 3]);
    expect(rows.filter((r) => r.rank > 3).map((r) => r.rank)).toEqual([4, 5, 6]);
  });
});

// ─── Scope filter chip ─────────────────────────────────────────────

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-1', name: 'UTBK Sore B', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-3', program_id: 'pr-2', name: 'SMP Reguler', kind: 'group', capacity: 20, status: 'active' },
];
const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Reguler SMP', grade_level: '8', status: 'active' },
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
          tutor: {
            leaderboard: {
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
  const w = mount(TutorTutoring2LeaderboardView, {
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
        // lets the assertions read what the chip says.
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

/** Chips render in template order: tab, scope. */
const CHIP = { tab: 0, scope: 1 };

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

describe('TutorTutoring2LeaderboardView scope chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringLeaderboardService.getGroup as any).mockResolvedValue({ items: ROWS });
    (TutoringLeaderboardService.getProgram as any).mockResolvedValue({ items: ROWS });
  });

  it('loads both scope lists on mount and names the auto-picked kelompok', async () => {
    const w = await mountView();

    expect(TutoringBimbelService.listGroups).toHaveBeenCalled();
    expect(TutoringBimbelService.listPrograms).toHaveBeenCalled();

    const c = chips(w);
    expect(c).toHaveLength(2);
    expect(c[CHIP.scope].text()).toBe('UTBK Pagi A');
    expect(c[CHIP.scope].attributes('disabled')).toBeUndefined();
  });

  it('the scope chip OPENS a picker of every kelompok instead of cycling', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    const before = (TutoringLeaderboardService.getGroup as any).mock.calls.length;
    await chips(w)[CHIP.scope].trigger('click');
    await flushPromises();

    // The regression: the old handler advanced groupId by one and
    // re-queried the board on the way. A picker must open and change
    // NOTHING yet.
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

    // One row per kelompok and nothing else: without a kelompok/program
    // there is no board at all, so a reset row would only blank the page.
    const labels = optionRows(w).map((b) => b.text());
    expect(labels).toHaveLength(GROUPS.length);
    expect(labels).not.toContain('Semua');
  });

  it('reaches a NON-ADJACENT kelompok in one pick, not one click per entry', async () => {
    const w = await mountView();
    await chips(w)[CHIP.scope].trigger('click');
    // Row index 2 = 'SMP Reguler'. The cycler could only ever reach the
    // NEXT entry per click; the picker jumps straight there.
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastCallOf(TutoringLeaderboardService.getGroup as any)[0]).toBe('gr-3');
    expect(chips(w)[CHIP.scope].text()).toBe('SMP Reguler');
    // And it closed itself on apply.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);
  });

  it('the program tab swaps the picker to programs and queries the program board', async () => {
    const w = await mountView();
    await chips(w)[CHIP.tab].trigger('click'); // → Per Program
    await flushPromises();

    expect(TutoringLeaderboardService.getProgram).toHaveBeenCalled();
    expect(chips(w)[CHIP.scope].text()).toBe('Intensif UTBK');

    await chips(w)[CHIP.scope].trigger('click');
    const labels = optionRows(w).map((b) => b.text());
    expect(labels).toHaveLength(PROGRAMS.length);
    expect(labels.join(' ')).toContain('Reguler SMP');
    expect(labels.join(' ')).not.toContain('UTBK Pagi A'); // that's a kelompok

    await optionRows(w)[1].trigger('click');
    await flushPromises();
    expect(lastCallOf(TutoringLeaderboardService.getProgram as any)[0]).toBe('pr-2');
  });

  it('an empty kelompok list disables the scope chip instead of leaving it dead', async () => {
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: [] });

    const w = await mountView();

    // Pre-fix this chip stayed enabled and `pickNextScope()` silently
    // returned — a control that looks live and does nothing.
    expect(chips(w)[CHIP.scope].attributes('disabled')).toBeDefined();
    expect(w.find('[data-testid="async"]').attributes('data-status')).not.toBe('error');
  });

  it('a failing program list does not blank the kelompok chip or error the page', async () => {
    // Pre-fix this ran through `Promise.all` inside the loader, so one
    // rejected scope endpoint threw the whole view into its error state
    // and neither tab had any options.
    (TutoringBimbelService.listPrograms as any).mockRejectedValue(new Error('403'));

    const w = await mountView();

    expect(chips(w)[CHIP.scope].text()).toBe('UTBK Pagi A');
    expect(chips(w)[CHIP.scope].attributes('disabled')).toBeUndefined();
    expect(w.find('[data-testid="async"]').attributes('data-status')).not.toBe('error');
  });
});
