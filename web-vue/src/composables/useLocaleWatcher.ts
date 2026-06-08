/**
 * useLocaleWatcher — re-run a loader whenever the user switches the app
 * language via the authenticated picker (ProfileMenu toggle, ProfileView
 * buttons → `usePreferencesStore().setLocale`).
 *
 * Why this exists:
 *   vue-i18n chrome (labels, nav, buttons) re-renders the instant the
 *   locale flips. But many strings come back from the BACKEND already
 *   localised — the dashboard priority-inbox ("Perlu Perhatian" /
 *   "Needs Attention") labels & subtitles in particular. Those only
 *   change language on the next request the server localises, so the
 *   mounted view must re-fetch them. This watcher is that hook.
 *
 * Usage (same shape as useAcademicYearWatcher):
 *   import { useLocaleWatcher } from '@/composables/useLocaleWatcher';
 *   useLocaleWatcher(() => load());
 *
 * Ordering guarantee: the prefs store only bumps `localeChangeToken`
 * AFTER awaiting the PATCH that persists `preferred_language`, so by
 * the time this loader fires the server will read the new saved pref
 * (it prefers the saved pref over the Accept-Language header) and hand
 * back data in the freshly-chosen language.
 *
 * Skips the initial value so the loader isn't double-fired on first
 * mount (the parent calls it itself in onMounted).
 */
import { watch } from 'vue';
import { usePreferencesStore } from '@/stores/preferences';

export function useLocaleWatcher(loader: () => unknown | Promise<unknown>) {
  const prefs = usePreferencesStore();
  watch(
    () => prefs.localeChangeToken,
    (token, prev) => {
      if (prev === undefined || token === prev) return;
      loader();
    },
  );
}
