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
      if (prev === undefined || id === prev) return;
      loader();
    },
  );
}
