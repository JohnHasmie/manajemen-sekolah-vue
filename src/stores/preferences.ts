/**
 * Preferences store — UI-only settings (language, theme).
 * Mirrors Flutter's `LanguageProvider` from `lib/utils/language_utils.dart`.
 *
 * Language persistence has two layers:
 *
 * 1. **Local (synchronous)** — `setLocale()` from `@/lib/i18n` writes to
 *    localStorage and flips `i18n.global.locale.value`. This is what the
 *    UI rebuild reacts to. Survives reload on THIS browser.
 *
 * 2. **Remote (best-effort)** — `SettingsService.updatePreferredLanguage`
 *    PATCHes `/api/profile/language` so `users.preferred_language` reflects
 *    the choice. Survives logout / device switch / new browser. The
 *    backend's `SetLocaleFromHeader` middleware then reads it on every
 *    subsequent request to localise backend-rendered strings.
 *
 * On startup, `hydrateFromUser()` reads the value the server sent down in
 * the login payload and applies it WITHOUT echoing it back, avoiding an
 * immediate redundant PATCH on every cold start.
 *
 * ## Re-fetching backend-localised data after a switch
 *
 * vue-i18n chrome (labels, buttons, nav) flips instantly the moment
 * `setLocale()` runs. But a lot of strings are rendered SERVER-SIDE —
 * the dashboard priority-inbox ("Perlu Perhatian" / "Needs Attention")
 * labels/subtitles, validator messages, etc. — and those only change
 * language on the NEXT request the backend localises. So after a
 * user-initiated switch we must re-fetch that data, otherwise it stays
 * in the old language until a manual page reload.
 *
 * The store can't reach into every mounted view, so instead it exposes
 * a monotonic `localeChangeToken`. Views observe it via
 * `useLocaleWatcher(() => load())` (the same shape as
 * `useAcademicYearWatcher`) and re-run their loader when it ticks.
 *
 * Ordering matters: the backend's locale precedence is (1) the saved
 * `preferred_language`, then (2) the `Accept-Language` header. If we
 * bumped the token (→ re-fetch) before the PATCH committed, the
 * re-fetch could race ahead of the DB write and the server would still
 * read the OLD saved pref, handing back stale-language data. So
 * `setLocale` AWAITS the PATCH before ticking the token. The PATCH
 * itself never throws (errors are swallowed in the service), so even a
 * 5xx still lets us flip the locale and trigger the refresh — the
 * Accept-Language header alone is then enough for the server to honour
 * the new language on the re-fetch.
 */
import { defineStore } from 'pinia';
import { setLocale, currentLocale, type AppLocale } from '@/lib/i18n';
import { SettingsService } from '@/services/settings.service';

interface PreferencesState {
  locale: AppLocale;
  /**
   * Monotonic counter bumped after every user-initiated locale switch
   * (once the backend PATCH has been awaited). Views watch this to
   * re-fetch server-localised data. NOT bumped by `hydrateFromUser`,
   * since a hydrate happens at mount before those views have data to
   * stale — and bumping it would double-fire their initial load.
   */
  localeChangeToken: number;
}

export const usePreferencesStore = defineStore('preferences', {
  state: (): PreferencesState => ({
    locale: currentLocale(),
    localeChangeToken: 0,
  }),

  actions: {
    /**
     * User-initiated locale switch (e.g. picker tap). Flips the local
     * i18n immediately (chrome re-renders at once), AWAITS the
     * cross-device PATCH so the saved `preferred_language` is committed
     * before any re-fetch reads it, then bumps `localeChangeToken` so
     * mounted views re-fetch their server-localised data.
     *
     * Resilient by design: `updatePreferredLanguage` swallows its own
     * errors, so this never throws to the UI; the token still ticks on
     * a failed PATCH so the re-fetch (carrying the new Accept-Language
     * header) still happens. Use [hydrateFromUser] for server-supplied
     * values to avoid the echo PATCH + spurious re-fetch.
     */
    async setLocale(locale: AppLocale) {
      const changed = this.locale !== locale;
      this.locale = locale;
      setLocale(locale);
      // Cross-device persistence — failures swallowed inside the
      // service so the picker UX is unaffected by transient backend
      // hiccups. Awaited so the saved pref is committed before the
      // re-fetch below (server prefers saved pref over the header).
      await SettingsService.updatePreferredLanguage(locale);
      // Signal mounted views to re-fetch backend-localised data. Only
      // tick on an actual change so a no-op pick doesn't churn loaders.
      if (changed) this.localeChangeToken += 1;
    },

    /**
     * Apply a locale that ALREADY came from the server (e.g.
     * `user.preferred_language` in the login response). Skips the
     * PATCH so we don't immediately echo the value back as our own
     * "update". No-op when the value is null/undefined/unsupported or
     * already active, so callers can pipe payloads straight in.
     */
    hydrateFromUser(code: string | null | undefined) {
      if (!code) return;
      if (code !== 'id' && code !== 'en') return;
      if (this.locale === code) return;
      this.locale = code;
      setLocale(code);
    },

    async toggleLocale() {
      await this.setLocale(this.locale === 'id' ? 'en' : 'id');
    },
  },
});
