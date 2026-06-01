/**
 * Preferences store — UI-only settings (language, theme).
 * Mirrors Flutter's `LanguageProvider` from `lib/utils/language_utils.dart`.
 */
import { defineStore } from 'pinia';
import { setLocale, currentLocale, type AppLocale } from '@/lib/i18n';

interface PreferencesState {
  locale: AppLocale;
}

export const usePreferencesStore = defineStore('preferences', {
  state: (): PreferencesState => ({
    locale: currentLocale(),
  }),

  actions: {
    setLocale(locale: AppLocale) {
      this.locale = locale;
      setLocale(locale);
    },

    toggleLocale() {
      this.setLocale(this.locale === 'id' ? 'en' : 'id');
    },
  },
});
