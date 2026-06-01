/**
 * useParentAttendance — shared full-academic-year attendance cache
 * for the parent kehadiran screens (list + calendar).
 *
 * Both screens fetch by `(studentId, academicYearId)`; navigating
 * between them should never trigger a second round-trip. The Map
 * lives at module scope so it persists across mount/unmount.
 *
 * Cache invalidation:
 *   - clearChild(studentId) — bust every AY for one child
 *   - clearAll() — used when AY changes (drops everything)
 *
 * The composable does NOT subscribe to AY changes; callers should
 * use `useAcademicYearWatcher` and call `clearAll()` themselves so
 * they decide whether the next fetch is eager or lazy.
 */
import { ParentService } from '@/services/parent.service';
import type { ParentAttendanceEntry } from '@/types/parent';

type Key = string; // `${studentId}::${academicYearId ?? ''}`

const cache = new Map<Key, ParentAttendanceEntry[]>();
const inflight = new Map<Key, Promise<ParentAttendanceEntry[]>>();

function makeKey(studentId: string, ayId: string | null | undefined): Key {
  return `${studentId}::${ayId ?? ''}`;
}

export function useParentAttendance() {
  async function fetchYear(
    studentId: string,
    ayId: string | null | undefined,
    opts: { force?: boolean } = {},
  ): Promise<ParentAttendanceEntry[]> {
    const key = makeKey(studentId, ayId);
    if (!opts.force) {
      const hit = cache.get(key);
      if (hit) return hit;
      const flight = inflight.get(key);
      if (flight) return flight;
    }
    const p = ParentService.attendanceYear(studentId, {
      academic_year_id: ayId ?? undefined,
    }).then((rows) => {
      cache.set(key, rows);
      inflight.delete(key);
      return rows;
    }).catch((e) => {
      inflight.delete(key);
      throw e;
    });
    inflight.set(key, p);
    return p;
  }

  function patch(
    studentId: string,
    ayId: string | null | undefined,
    next: ParentAttendanceEntry[],
  ): void {
    cache.set(makeKey(studentId, ayId), next);
  }

  function get(
    studentId: string,
    ayId: string | null | undefined,
  ): ParentAttendanceEntry[] | undefined {
    return cache.get(makeKey(studentId, ayId));
  }

  function clearChild(studentId: string): void {
    for (const k of Array.from(cache.keys())) {
      if (k.startsWith(`${studentId}::`)) cache.delete(k);
    }
  }

  function clearAll(): void {
    cache.clear();
    inflight.clear();
  }

  return { fetchYear, get, patch, clearChild, clearAll };
}
