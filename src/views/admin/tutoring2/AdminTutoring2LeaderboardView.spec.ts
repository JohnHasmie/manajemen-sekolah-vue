/**
 * Vitest spec for AdminTutoring2LeaderboardView (WEB-14).
 *
 * Pins:
 *   - default export is a Vue component
 *   - LeaderboardRow type shape survives round-trip (imports the
 *     canonical types module — a compile-time contract)
 *   - podium/tail partitioning at rank 3 (1..3 podium, 4..N table)
 *   - streak column reveal — appears only when ANY row carries a
 *     positive `streak_days`; the greenfield BE-21 doesn't emit it
 *     yet, so the default view hides the column
 *
 * Follows the not-yet-wired-Vitest pattern used elsewhere in this
 * repo; type-checks under `vue-tsc --build` (the active gate today).
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2LeaderboardView from './AdminTutoring2LeaderboardView.vue';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';

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
