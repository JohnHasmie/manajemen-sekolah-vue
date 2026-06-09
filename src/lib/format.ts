/**
 * Format helpers — locale-aware via the active vue-i18n locale.
 *
 * Mirrors `lib/utils/currency_formatter.dart` + `lib/utils/date_utils.dart`
 * from the Flutter app. The Intl formatters resolve their BCP-47 tag at
 * call time from the i18n singleton, so calling code doesn't need to
 * thread the locale through — switching language refreshes every
 * formatted string on the next render.
 */
import { i18n } from './i18n';

// Currency stays as IDR formatted with Indonesian grouping. Switching to
// English changes the grouping/decimal style but NOT the currency code —
// the school's amounts stay in rupiah either way.
const RUPIAH_ID = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});
const RUPIAH_EN = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'IDR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

const NUMBER_ID = new Intl.NumberFormat('id-ID');
const NUMBER_EN = new Intl.NumberFormat('en-US');

// Cache per-locale formatters so we don't allocate on every call.
const dateLongCache: Record<string, Intl.DateTimeFormat> = {};
const dateShortCache: Record<string, Intl.DateTimeFormat> = {};
const dateTimeCache: Record<string, Intl.DateTimeFormat> = {};
const timeOnlyCache: Record<string, Intl.DateTimeFormat> = {};

function activeBcp47(): string {
  // `i18n.global.locale` is a Ref when legacy is false (our setup), a
  // plain string otherwise. Handle both shapes defensively.
  const raw = i18n.global.locale as unknown as { value?: string } | string;
  const code = typeof raw === 'string' ? raw : raw?.value ?? 'id';
  return code === 'en' ? 'en-US' : 'id-ID';
}

function dateLong(): Intl.DateTimeFormat {
  const tag = activeBcp47();
  if (!dateLongCache[tag]) {
    dateLongCache[tag] = new Intl.DateTimeFormat(tag, {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  }
  return dateLongCache[tag];
}

function dateShort(): Intl.DateTimeFormat {
  const tag = activeBcp47();
  if (!dateShortCache[tag]) {
    dateShortCache[tag] = new Intl.DateTimeFormat(tag, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }
  return dateShortCache[tag];
}

function dateTime(): Intl.DateTimeFormat {
  const tag = activeBcp47();
  if (!dateTimeCache[tag]) {
    dateTimeCache[tag] = new Intl.DateTimeFormat(tag, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
  return dateTimeCache[tag];
}

function timeOnly(): Intl.DateTimeFormat {
  const tag = activeBcp47();
  if (!timeOnlyCache[tag]) {
    timeOnlyCache[tag] = new Intl.DateTimeFormat(tag, {
      hour: '2-digit',
      minute: '2-digit',
    });
  }
  return timeOnlyCache[tag];
}

function rupiah(): Intl.NumberFormat {
  return activeBcp47() === 'en-US' ? RUPIAH_EN : RUPIAH_ID;
}

function number(): Intl.NumberFormat {
  return activeBcp47() === 'en-US' ? NUMBER_EN : NUMBER_ID;
}

export function formatRupiah(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') return 'Rp 0';
  const n = typeof value === 'string' ? Number(value) : value;
  if (Number.isNaN(n)) return 'Rp 0';
  return rupiah().format(n);
}

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined) return '0';
  return number().format(value);
}

/**
 * Strip everything but digits from a money input, returning the raw
 * integer (no separators). `"500.000"` → `500000`, `""` → `0`. This is
 * what gets submitted to the API.
 */
export function parseDigits(value: string | number | null | undefined): number {
  if (value === null || value === undefined) return 0;
  const digits = String(value).replace(/\D/g, '');
  return digits ? Number(digits) : 0;
}

/**
 * Group a money input with Indonesian thousand separators as the user
 * types, WITHOUT the "Rp" prefix (unlike `formatRupiah`). `"500000"` →
 * `"500.000"`. Non-digit chars are ignored; empty input stays empty so
 * the field can be cleared.
 */
export function formatThousands(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return '';
  const digits = String(value).replace(/\D/g, '');
  if (!digits) return '';
  return NUMBER.format(Number(digits));
}

export function formatDateLong(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return dateLong().format(d);
}

export function formatDateShort(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return dateShort().format(d);
}

export function formatDateTime(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return dateTime().format(d);
}

export function formatTime(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return timeOnly().format(d);
}

/** Relative time: "2 hr ago" / "2 jam lalu", "yesterday" / "kemarin", etc. */
export function formatRelative(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';

  const diffMs = Date.now() - d.getTime();
  const min = Math.round(diffMs / 60_000);
  const hr = Math.round(diffMs / 3_600_000);
  const day = Math.round(diffMs / 86_400_000);

  // Pull strings from the i18n singleton — reusing the parent activity
  // keys (already present in both locales) keeps the wording consistent.
  const t = i18n.global.t.bind(i18n.global);
  if (Math.abs(min) < 1) return t('parent.activity.timeJustNow');
  if (Math.abs(min) < 60) return t('parent.activity.timeMinutesAgo', { n: min });
  if (Math.abs(hr) < 24) return t('parent.activity.timeHoursAgo', { n: hr });
  if (day === 1) return t('parent.activity.timeYesterday');
  if (day < 7) return t('parent.activity.timeDaysAgo', { n: day });
  return formatDateShort(d);
}

/**
 * Local (device-calendar) date as `YYYY-MM-DD`.
 *
 * Use this — NOT `new Date().toISOString().slice(0, 10)` — whenever the
 * string is a calendar date that will be STORED/submitted (e.g. an
 * attendance/presensi date). `toISOString()` formats in UTC, so for WIB
 * users (Asia/Jakarta, UTC+7) any time between 00:00 and 06:59 local
 * resolves to *yesterday*, landing the record on the wrong day. The
 * `getFullYear/getMonth/getDate` getters read local time, so the date
 * always matches the calendar the user actually sees. Mirrors the
 * `todayIso()` helpers in the teacher attendance views and the Flutter
 * fix !197.
 */
export function localISODate(value: Date = new Date()): string {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
