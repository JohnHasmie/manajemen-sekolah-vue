/**
 * useQuickAction - detects whether the current route was opened via a
 * dashboard "Aksi Cepat" tile.
 *
 * Convention: dashboard quick-action buttons pass `?from=quick-action`
 * (plus any class_id / subject_id pre-fills). Pages can call
 * `fromQuickAction()` on mount — if true, preserve any pre-filled
 * context. If false, reset filters to their defaults so the page is a
 * clean entry every other time.
 *
 * Mirrors Flutter's dashboard-to-screen filter-preservation pattern.
 */
import { computed } from 'vue';
import { useRoute } from 'vue-router';

export function useQuickAction() {
  const route = useRoute();

  const fromQuickAction = computed(() => route.query.from === 'quick-action');

  /** Pre-fill helpers — return query value if present, else null. */
  function queryString(key: string): string | null {
    const v = route.query[key];
    if (typeof v === 'string' && v.length > 0) return v;
    return null;
  }

  return {
    fromQuickAction,
    queryString,
  };
}
