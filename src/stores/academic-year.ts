/**
 * useAcademicYearStore — global academic-year selection state.
 * Web port of Flutter's `AcademicYearProvider` (Riverpod). One source
 * of truth for which academic year is "selected" across all role
 * dashboards and feature pages.
 *
 * Selection priority on first `fetchAll()` (matches Flutter):
 *   1. Previously-picked id from localStorage (if it still exists)
 *   2. Backend's `/academic-year/active` payload
 *   3. Date-based match (Indonesian school year: month ≥ July → "Y/Y+1",
 *      otherwise "Y-1/Y")
 *   4. First year in the list
 *
 * Anything in the app that needs the current id calls `selectedYearId`;
 * lazy services call `currentAcademicYearId()` (helper at the bottom)
 * so they don't have to import the store directly.
 */
import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import { AcademicYearService } from '@/services/academic-year.service';
import {
  semesterLabel as semLabel,
  type AcademicYear,
} from '@/types/academic-year';

const LS_KEY = 'kamiledu.academicYearId';

function loadPersistedId(): string | null {
  try {
    return localStorage.getItem(LS_KEY) || null;
  } catch {
    return null;
  }
}

function persistId(id: string | null) {
  try {
    if (id) localStorage.setItem(LS_KEY, id);
    else localStorage.removeItem(LS_KEY);
  } catch {
    // ignore — private mode, etc.
  }
}

/** Indonesian school-year heuristic — month ≥ July → "Y/Y+1". */
function dateBasedYearString(now = new Date()): string {
  const y = now.getFullYear();
  return now.getMonth() + 1 >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`;
}

export const useAcademicYearStore = defineStore('academicYear', () => {
  // ── State ──
  const years = ref<AcademicYear[]>([]);
  const activeYear = ref<AcademicYear | null>(null);
  const selectedYear = ref<AcademicYear | null>(null);
  const isLoading = ref(false);
  const lastLoadedAt = ref<number | null>(null);

  // ── Getters ──
  const selectedYearId = computed<string | null>(
    () => selectedYear.value?.id ?? null,
  );

  /** True when the picked year is non-current — UI should lock edits. */
  const isReadOnly = computed<boolean>(
    () => selectedYear.value?.status === 'inactive' || selectedYear.value?.status === 'archived',
  );

  /** True when the picked year is also the backend's current year. */
  const isCurrent = computed<boolean>(
    () => selectedYear.value?.current === true,
  );

  /** "Sem. Ganjil" / "Sem. Genap" / null. */
  const semesterLabel = computed<string | null>(() =>
    semLabel(selectedYear.value?.semester ?? null),
  );

  /** Human-readable year label, "—" when unloaded. */
  const yearLabel = computed<string>(
    () => selectedYear.value?.year || '—',
  );

  // ── Actions ──
  async function fetchAll(opts: { force?: boolean } = {}): Promise<void> {
    // Cache for 10 minutes unless force=true.
    if (
      !opts.force &&
      lastLoadedAt.value &&
      Date.now() - lastLoadedAt.value < 10 * 60_000 &&
      years.value.length > 0
    ) {
      return;
    }
    isLoading.value = true;
    try {
      const [list, active] = await Promise.all([
        AcademicYearService.list(),
        AcademicYearService.getActive(),
      ]);
      years.value = list;
      activeYear.value = active;
      lastLoadedAt.value = Date.now();

      if (!selectedYear.value) {
        // ── Priority resolution ──
        const persistedId = loadPersistedId();
        const persistedHit = persistedId
          ? list.find((y) => y.id === persistedId)
          : undefined;
        if (persistedHit) {
          selectedYear.value = persistedHit;
        } else if (active) {
          selectedYear.value = active;
        } else {
          const target = dateBasedYearString();
          const byDate = list.find((y) => y.year === target);
          selectedYear.value = byDate ?? list[0] ?? null;
        }
        persistId(selectedYear.value?.id ?? null);
      } else {
        // Re-resolve the cached selection against the fresh list so
        // year objects don't go stale (status / current flags may have
        // changed server-side).
        const refreshed = list.find((y) => y.id === selectedYear.value!.id);
        if (refreshed) selectedYear.value = refreshed;
      }
    } finally {
      isLoading.value = false;
    }
  }

  /** Update the selected year by id; persists + triggers reactivity. */
  function setSelected(id: string): void {
    const hit = years.value.find((y) => y.id === id);
    if (!hit) return;
    selectedYear.value = hit;
    persistId(hit.id);
  }

  /** Lighter refresh — re-pulls only `/academic-year/active`. */
  async function refreshActive(): Promise<void> {
    try {
      activeYear.value = await AcademicYearService.getActive();
    } catch {
      // silent — best-effort
    }
  }

  /** Reset (used on logout). */
  function reset() {
    years.value = [];
    activeYear.value = null;
    selectedYear.value = null;
    lastLoadedAt.value = null;
    persistId(null);
  }

  return {
    // state
    years,
    activeYear,
    selectedYear,
    isLoading,
    // getters
    selectedYearId,
    isReadOnly,
    isCurrent,
    semesterLabel,
    yearLabel,
    // actions
    fetchAll,
    setSelected,
    refreshActive,
    reset,
  };
});

/**
 * Service-friendly helper. Services don't need a Vue setup context —
 * they just want the current id (or undefined) for a param. Pulls
 * directly off the pinia singleton.
 */
export function currentAcademicYearId(): string | undefined {
  // Lazy import to avoid circular issues with services importing this
  // file before pinia is initialised.
  try {
    return useAcademicYearStore().selectedYearId ?? undefined;
  } catch {
    return undefined;
  }
}
