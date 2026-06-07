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
 */
import { defineStore } from 'pinia';
import { setLocale, currentLocale, type AppLocale } from '@/lib/i18n';
import { SettingsService } from '@/services/settings.service';

interface PreferencesState {
  locale: AppLocale;
}

export const usePreferencesStore = defineStore('preferences', {
  state: (): PreferencesState => ({
    locale: currentLocale(),
  }),

  actions: {
    /**
     * User-initiated locale switch (e.g. picker tap). Updates the
     * local i18n immediately, then fires a fire-and-forget PATCH so
     * the choice follows the user to other devices. Use
     * [hydrateFromUser] for server-supplied values to avoid the echo
     * PATCH.
     */
    setLocale(locale: AppLocale) {
      this.locale = locale;
      setLocale(locale);
      // Cross-device persistence — failures swallowed inside the
      // service so the picker UX is unaffected by transient backend
      // hiccups.
      void SettingsService.updatePreferredLanguage(locale);
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

    toggleLocale() {
      this.setLocale(this.locale === 'id' ? 'en' : 'id');
    },
  },
});
