/**
 * useAcademicYearWatcher — re-run a loader whenever the user picks a
 * different academic year via <AcademicYearPickerModal>.
 *
 * Usage:
 *   import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
 *   useAcademicYearWatcher(() => load());
 *
 * Skips the initial emission so the loader isn't double-fired on
 * first mount (the parent typically calls it themselves in onMounted).
 */
import { watch } from 'vue';
import { useAcademicYearStore } from '@/stores/academic-year';

export function useAcademicYearWatcher(loader: () => unknown | Promise<unknown>) {
  const store = useAcademicYearStore();
  watch(
    () => store.selectedYearId,
    (id, prev) => {
      if (id === prev) return;

      // `selectedYearId` is a computed off `selectedYear`, so it starts
      // as NULL — not undefined. On a hard refresh the store hydrates
      // AFTER the page mounts, turning null into a real id, and the old
      // `prev === undefined` guard never caught it: every page ran its
      // loader twice and visibly flashed content → blank → content.
      //
      // That transition is the store filling in, not the user switching
      // years, so it should be skipped — but only when skipping is
      // actually safe. The parent's own onMounted load ran with no year
      // param, which the backend resolves to the CURRENT year. So:
      //   - hydrated to the current year  → identical request, skip
      //   - hydrated to a PERSISTED other year → the first load really
      //     did fetch the wrong one, so refetch
      if (prev == null) {
        if (store.isCurrent) return;
      }

      loader();
    },
  );
}
