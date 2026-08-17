/**
 * Filter predicates for the per-class timetable grid.
 *
 * The schedule hub renders one chip row above BOTH views, but the grid
 * used to ignore it completely: an admin who picked "Guru: Pak Budi"
 * and switched to Timetable got an unchanged week for whichever class
 * localStorage happened to remember, chips still lit.
 *
 * `class` is honoured by selecting the grid outright — `/matrix` is
 * per-class anyway. The rest cannot narrow a week grid by removal: a
 * missing slot in a timetable reads as a free period, and the reader
 * has no way to tell that apart from "hidden by a chip". So they
 * highlight instead — matching cells stay bright, the others go quiet,
 * and a banner states the count so zero matches is an explicit answer.
 *
 * Extracted from the SFC so the predicate is testable on its own.
 */

/** The chips a per-class grid can only express as emphasis. */
export interface TimetableHighlightFilters {
  teacherId?: string;
  subjectId?: string;
  dayId?: string;
  /** '' (and undefined) mean "no hour chip", not "hour zero". */
  hourNumber?: number | '';
}

/** The slice of a matrix cell the predicate reads. */
export interface HighlightableCell {
  teacher: { id: string };
  subject: { id: string };
  is_block?: boolean;
  is_block_anchor?: boolean;
}

/** True when at least one highlight-only chip is set. */
export function hasHighlightFilter(f: TimetableHighlightFilters): boolean {
  return (
    Boolean(f.teacherId) ||
    Boolean(f.subjectId) ||
    Boolean(f.dayId) ||
    (f.hourNumber !== '' && f.hourNumber !== undefined)
  );
}

/**
 * Does this filled cell satisfy EVERY active chip?
 *
 * Chips are conjunctive, matching the list view's `filteredRows`: the
 * two views must agree on what "Pak Budi on Tuesday" means, or the
 * same filter tells two different stories depending on the toggle.
 *
 * An empty slot (`undefined`) never matches — nothing to highlight.
 */
export function cellMatchesFilters(
  cell: HighlightableCell | undefined,
  dayId: string,
  hourNumber: number,
  f: TimetableHighlightFilters,
): boolean {
  if (!cell) return false;
  if (f.teacherId && cell.teacher.id !== f.teacherId) return false;
  if (f.subjectId && cell.subject.id !== f.subjectId) return false;
  if (f.dayId && dayId !== f.dayId) return false;
  if (f.hourNumber !== '' && f.hourNumber !== undefined && hourNumber !== f.hourNumber) {
    return false;
  }
  return true;
}

/**
 * How many slots in the loaded week satisfy the chips.
 *
 * A multi-hour block counts ONCE, on its anchor — the covered hours are
 * the same session, and counting them separately would tell an admin
 * that a teacher has four sessions on Friday when they have one that
 * runs four periods.
 */
export function countMatches(
  dayIds: string[],
  hourNumbers: number[],
  cellAt: (dayId: string, hourNumber: number) => HighlightableCell | undefined,
  f: TimetableHighlightFilters,
): number {
  if (!hasHighlightFilter(f)) return 0;
  let n = 0;
  for (const dayId of dayIds) {
    for (const hourNumber of hourNumbers) {
      const cell = cellAt(dayId, hourNumber);
      if (cell?.is_block && cell.is_block_anchor === false) continue;
      if (cellMatchesFilters(cell, dayId, hourNumber, f)) n++;
    }
  }
  return n;
}
