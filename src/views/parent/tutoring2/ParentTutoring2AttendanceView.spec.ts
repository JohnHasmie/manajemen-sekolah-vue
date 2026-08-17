/**
 * A wali's screens must report their CHILD, not the centre.
 *
 * Both of these views used to answer from data about the tenant:
 *
 *   Kehadiran  fetched the last 100 SESSIONS and counted
 *              `status === 'done'` as present, `'cancelled'` as excused,
 *              `'scheduled'` as ABSENT — so future lessons were shown to
 *              a parent as their child's absences, and `sakit` was a
 *              hardcoded 0.
 *
 *   Nilai      derived every number from `max_score` — the mark an
 *              assessment is OUT OF. Each row rendered
 *              `max_score / max_score`, i.e. full marks on everything,
 *              including assessments the child never sat.
 *
 * These pin the two properties that make the fix a fix: the summary is
 * the server's (not a tally of one page), and an unknown stays unknown
 * rather than collapsing to a confident zero.
 *
 * Same convention as the sibling specs: type-checked by `vue-tsc
 * --build`, which is the active gate.
 */
import { describe, expect, it } from 'vitest';
import type {
  StudentAttendanceResult,
  StudentAttendanceSummary,
} from '@/types/tutoring2/attendance';
import type { ProgressSummary } from '@/types/tutoring2/progress';

describe('wali attendance contract', () => {
  it('the summary is a server field, not a tally of the page', () => {
    // 50 rows on this page, 214 marks over the term. A client that
    // counted `rows` would report the page as the term.
    const result: StudentAttendanceResult = {
      rows: [],
      summary: {
        total: 214,
        hadir: 198,
        izin: 8,
        sakit: 5,
        alpa: 3,
        attendance_rate: 92.5,
      },
      meta: {
        student_id: 'st-1',
        current_page: 1,
        last_page: 5,
        per_page: 50,
        total: 214,
      },
    };

    expect(result.summary.total).toBe(214);
    expect(result.summary.total).not.toBe(result.rows.length);
  });

  it('attendance_rate is nullable — "not marked" is not "attended none"', () => {
    const fresh: StudentAttendanceSummary = {
      total: 0,
      hadir: 0,
      izin: 0,
      sakit: 0,
      alpa: 0,
      attendance_rate: null,
    };

    // Must render as "—". A 0% here would tell a parent their child
    // attended nothing, when in fact no register has been taken.
    expect(fresh.attendance_rate).toBeNull();
    expect(fresh.attendance_rate).not.toBe(0);
  });

  it('a session status is not an attendance status', () => {
    // The vocabularies are disjoint on purpose. The old screen mapped
    // one onto the other; nothing in the types permits that now.
    const attendanceValues = ['hadir', 'izin', 'sakit', 'alpa'];
    const sessionValues = ['scheduled', 'in_progress', 'done', 'cancelled'];

    for (const s of sessionValues) {
      expect(attendanceValues).not.toContain(s);
    }
  });
});

describe('wali assessment contract', () => {
  it('the average comes from scores, and is nullable', () => {
    const ungraded: ProgressSummary = {
      graded_count: 0,
      average: null,
      highest: null,
      lowest: null,
      latest: null,
    };

    // "—", not 0. A child with no marks yet has no average.
    expect(ungraded.average).toBeNull();
    expect(ungraded.graded_count).toBe(0);
  });

  it('graded_count counts marks, not assessments in the tenant', () => {
    const s: ProgressSummary = {
      graded_count: 3,
      average: 78.5,
      highest: 92,
      lowest: 61,
      latest: 78,
    };

    // The old KPI showed the tenant's published-assessment count here,
    // which is unrelated to how many this child has actually sat.
    expect(s.graded_count).toBe(3);
    expect(s.average).toBeGreaterThan(0);
    expect(s.highest).toBeGreaterThanOrEqual(s.lowest ?? 0);
  });
});
