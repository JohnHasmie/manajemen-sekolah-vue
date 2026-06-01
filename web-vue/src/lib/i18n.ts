/**
 * i18n bootstrap — Bahasa Indonesia (default) + English.
 *
 * Mirrors `lib/utils/language_utils.dart` from the Flutter app: a single
 * source for translations, with id as the default. The active locale is
 * persisted via the preferences store.
 */
import { createI18n } from 'vue-i18n';
import { storage, StorageKeys } from './storage';
import id from '@/locales/id.json';
import en from '@/locales/en.json';

export type AppLocale = 'id' | 'en';

const SUPPORTED: AppLocale[] = ['id', 'en'];

function detectInitial(): AppLocale {
  const saved = storage.get<AppLocale>(StorageKeys.language);
  if (saved && SUPPORTED.includes(saved)) return saved;
  return 'id';
}

export const i18n = createI18n({
  legacy: false,
  locale: detectInitial(),
  fallbackLocale: 'id',
  messages: { id, en },
  // Allow {name} interpolation by default.
  silentTranslationWarn: true,
  silentFallbackWarn: true,
});

/** Set the active locale and persist the choice. */
export function setLocale(locale: AppLocale) {
  i18n.global.locale.value = locale;
  storage.set(StorageKeys.language, locale);
  if (typeof document !== 'undefined') {
    document.documentElement.lang = locale;
  }
}

export function currentLocale(): AppLocale {
  return i18n.global.locale.value as AppLocale;
}
