import { i18n } from '@/lib/i18n';

/**
 * Translate a backend `day.name` string (lowercase English canonical:
 * `"monday"`…`"sunday"`) into the user's current locale — `"Senin"` in
 * Indonesian, `"Monday"` in English.
 *
 * Tolerant of anything the backend has ever emitted: Title Case
 * (`"Monday"`), Bahasa (`"Senin"`), stray whitespace, empty/null. Unknown
 * strings fall through unchanged so we degrade to the raw value rather
 * than a blank cell.
 *
 * Reads i18n via `i18n.global.t` so this stays usable outside `setup()`
 * blocks (helpers, service layer, computed maps in `.ts` files).
 */
const DAY_KEYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as const;

const NORMALIZE: Record<string, (typeof DAY_KEYS)[number]> = {
  monday: 'monday', mon: 'monday', senin: 'monday',
  tuesday: 'tuesday', tue: 'tuesday', selasa: 'tuesday',
  wednesday: 'wednesday', wed: 'wednesday', rabu: 'wednesday',
  thursday: 'thursday', thu: 'thursday', kamis: 'thursday',
  friday: 'friday', fri: 'friday', jumat: 'friday', "jum'at": 'friday',
  saturday: 'saturday', sat: 'saturday', sabtu: 'saturday',
  sunday: 'sunday', sun: 'sunday', minggu: 'sunday', ahad: 'sunday',
};

export function formatDayName(raw: string | null | undefined): string {
  if (!raw) return '';
  const key = NORMALIZE[raw.trim().toLowerCase()];
  if (!key) return raw;
  return i18n.global.t(`common.${key}`);
}
