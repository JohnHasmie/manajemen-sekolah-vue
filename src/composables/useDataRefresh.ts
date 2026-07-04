/**
 * useDataRefresh — the canonical data-load lifecycle for admin/list views.
 *
 * Wraps the boilerplate repeated across ~23 admin views:
 *
 *   const isLoading = ref(true);
 *   const error = ref<string | null>(null);
 *   async function load() {
 *     isLoading.value = true; error.value = null;
 *     try { data.value = await service.fetch(); }
 *     catch (e) { error.value = (e as Error).message; }
 *     finally { isLoading.value = false; }
 *   }
 *   onMounted(load);
 *   useAcademicYearWatcher(() => load());
 *   useLocaleWatcher(() => load());
 *
 * Usage — the loader returns the payload; the composable owns the
 * `AsyncState<T>` state-machine that <AsyncView> consumes directly:
 *
 *   const { state, reload } = useDataRefresh(
 *     () => ReportCardService.getAdminPipeline(),
 *   );
 *   // template: <AsyncView :state="state" @retry="reload" />
 *
 * Empty detection: the returned data is considered empty (status
 * 'empty') when it is `null`/`undefined` or an empty array. Views whose
 * empty condition depends on *filtered* data (e.g. a computed that hides
 * rows) should NOT read `state` directly — instead use `useDataRefresh`
 * only for the load/watch/error mechanics and derive their own template
 * `AsyncState` from `state.value.data`. See `keepPrevious` note below.
 *
 * `keepPrevious` (default true): while a reload is in flight the previous
 * `data` is retained so the list doesn't flash the spinner on academic-
 * year / locale switches — matching the hand-rolled
 * `if (isLoading && items.length === 0) return { status: 'loading' }`
 * guard the views used.
 *
 * Options mirror the two watcher composables this replaces; all default
 * to true so the common case is a one-liner:
 *   - watchAcademicYear — re-run on <AcademicYearPickerModal> change
 *   - watchLocale       — re-run on app-language switch (backend-localised
 *                         strings only refresh on the next request)
 *   - immediate         — run once on mount
 *
 * NOTE: only ~6 representative views are migrated in Wave 3b to prove the
 * primitive. The remaining ~17 admin views (finance, students, subjects,
 * schedule, attendance report, etc.) hand-roll the same trio and can
 * migrate incrementally — no big-bang sweep required.
 */
import { onMounted, ref, type Ref } from 'vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useLocaleWatcher } from '@/composables/useLocaleWatcher';

export interface UseDataRefreshOptions {
  /** Re-run the loader when the selected academic year changes. Default true. */
  watchAcademicYear?: boolean;
  /** Re-run the loader when the app locale changes. Default true. */
  watchLocale?: boolean;
  /** Run the loader once on mount. Default true. */
  immediate?: boolean;
}

export interface UseDataRefreshReturn<T> {
  /** The AsyncState the view feeds straight into <AsyncView :state>. */
  state: Ref<AsyncState<T>>;
  /** Re-run the loader (also the <AsyncView @retry> handler). */
  reload: () => Promise<void>;
}

function isEmpty(data: unknown): boolean {
  if (data === null || data === undefined) return true;
  if (Array.isArray(data)) return data.length === 0;
  return false;
}

export function useDataRefresh<T>(
  loader: () => Promise<T>,
  opts: UseDataRefreshOptions = {},
): UseDataRefreshReturn<T> {
  const {
    watchAcademicYear = true,
    watchLocale = true,
    immediate = true,
  } = opts;

  const state = ref<AsyncState<T>>({ status: 'loading' }) as Ref<
    AsyncState<T>
  >;

  async function reload(): Promise<void> {
    // Keep the previous data visible while refetching so an academic-year
    // or locale switch doesn't flash the spinner over already-rendered
    // content — mirrors the hand-rolled `isLoading && items.length === 0`
    // guard the views used.
    const previous = state.value.status === 'content' ? state.value.data : undefined;
    if (previous === undefined) {
      state.value = { status: 'loading' };
    }
    try {
      const data = await loader();
      state.value = isEmpty(data)
        ? { status: 'empty', data }
        : { status: 'content', data };
    } catch (e) {
      state.value = { status: 'error', error: (e as Error).message };
    }
  }

  if (immediate) {
    onMounted(reload);
  }
  if (watchAcademicYear) {
    useAcademicYearWatcher(() => reload());
  }
  if (watchLocale) {
    useLocaleWatcher(() => reload());
  }

  return { state, reload };
}
