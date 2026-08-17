import { describe, expect, it } from 'vitest';
import {
  cellMatchesFilters,
  countMatches,
  hasHighlightFilter,
  type HighlightableCell,
} from '@/components/feature/schedule-timetable-filter';

const budi = { id: 'guru-budi' };
const sari = { id: 'guru-sari' };
const mtk = { id: 'mapel-mtk' };
const ipa = { id: 'mapel-ipa' };

const cell = (
  teacher = budi,
  subject = mtk,
  extra: Partial<HighlightableCell> = {},
): HighlightableCell => ({ teacher, subject, ...extra });

describe('hasHighlightFilter', () => {
  it('reads an unset chip row as no filter', () => {
    expect(hasHighlightFilter({})).toBe(false);
    expect(hasHighlightFilter({ hourNumber: '' })).toBe(false);
  });

  it('treats JP 0 as a real hour chip, not as absent', () => {
    // '' is the empty sentinel the hub uses; 0 is a legitimate hour
    // number in a school that indexes from zero. A truthiness check
    // here would silently drop that school's hour filter.
    expect(hasHighlightFilter({ hourNumber: 0 })).toBe(true);
  });
});

describe('cellMatchesFilters', () => {
  it('never matches an empty slot', () => {
    // Free periods have nothing to highlight — and a grid where empty
    // cells lit up would read as "Pak Budi teaches nothing here".
    expect(cellMatchesFilters(undefined, 'senin', 1, { teacherId: budi.id })).toBe(
      false,
    );
  });

  it('matches on teacher', () => {
    expect(cellMatchesFilters(cell(budi), 'senin', 1, { teacherId: budi.id })).toBe(
      true,
    );
    expect(cellMatchesFilters(cell(sari), 'senin', 1, { teacherId: budi.id })).toBe(
      false,
    );
  });

  it('requires every active chip, not any of them', () => {
    // The list view's `filteredRows` ANDs its chips. If the grid ORed
    // them, "Pak Budi" + "Selasa" would tell two different stories
    // depending on which view toggle the admin happened to be on.
    const f = { teacherId: budi.id, dayId: 'selasa' };
    expect(cellMatchesFilters(cell(budi), 'selasa', 1, f)).toBe(true);
    expect(cellMatchesFilters(cell(budi), 'senin', 1, f)).toBe(false);
    expect(cellMatchesFilters(cell(sari), 'selasa', 1, f)).toBe(false);
  });

  it('matches on subject and hour', () => {
    expect(
      cellMatchesFilters(cell(budi, ipa), 'senin', 3, {
        subjectId: ipa.id,
        hourNumber: 3,
      }),
    ).toBe(true);
    expect(
      cellMatchesFilters(cell(budi, ipa), 'senin', 4, { hourNumber: 3 }),
    ).toBe(false);
  });
});

describe('countMatches', () => {
  const days = ['senin', 'selasa'];
  const hours = [1, 2, 3];

  /** Grid: Budi teaches MTK Senin JP1 and Selasa JP2; Sari IPA Senin JP2. */
  const grid: Record<string, HighlightableCell> = {
    'senin:1': cell(budi, mtk),
    'senin:2': cell(sari, ipa),
    'selasa:2': cell(budi, mtk),
  };
  const cellAt = (d: string, h: number) => grid[`${d}:${h}`];

  it('counts nothing when no chip is set', () => {
    // The banner only appears under an active filter; a stray count
    // would make it claim the whole week is "matching".
    expect(countMatches(days, hours, cellAt, {})).toBe(0);
  });

  it('counts every matching slot across the week', () => {
    expect(countMatches(days, hours, cellAt, { teacherId: budi.id })).toBe(2);
  });

  it('reports zero when a filtered teacher never appears in this class', () => {
    // The case the banner exists for: the grid still shows a full week,
    // so without a stated 0 the admin reads it as unfiltered.
    expect(countMatches(days, hours, cellAt, { teacherId: 'guru-lain' })).toBe(0);
  });

  it('counts a multi-hour block once, on its anchor', () => {
    // Penjas running JP1–JP3 is ONE session. Counting the covered hours
    // separately would tell the admin the teacher has three sessions
    // that morning — the same double-count the list view collapses.
    const blocked: Record<string, HighlightableCell> = {
      'senin:1': cell(budi, mtk, { is_block: true, is_block_anchor: true }),
      'senin:2': cell(budi, mtk, { is_block: true, is_block_anchor: false }),
      'senin:3': cell(budi, mtk, { is_block: true, is_block_anchor: false }),
    };
    expect(
      countMatches(
        ['senin'],
        [1, 2, 3],
        (d, h) => blocked[`${d}:${h}`],
        { teacherId: budi.id },
      ),
    ).toBe(1);
  });
});
